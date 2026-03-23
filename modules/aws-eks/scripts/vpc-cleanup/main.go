// Copyright (c) IBM Corporation
// SPDX-License-Identifier: Apache-2.0

// vpc-cleanup deletes AWS resources orphaned inside a VPC by Kubernetes
// (load balancers, ENIs) that are not tracked by Terraform and would otherwise
// block VPC/subnet/IGW deletion during `terraform destroy`.
//
// Usage:
//
//	vpc-cleanup --vpc-id <vpc-id> --region <region> [--profile <profile>]
//	vpc-cleanup --vpc-id <vpc-id> --region <region> --access-key-id <id> --secret-access-key <secret>
//
// AWS credentials are resolved in this priority order:
//  1. --access-key-id / --secret-access-key flags (static credentials)
//  2. --profile flag (named profile from ~/.aws/credentials)
//  3. Standard SDK credential chain: environment variables → shared credentials file → IAM instance profile
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	ec2types "github.com/aws/aws-sdk-go-v2/service/ec2/types"
	"github.com/aws/aws-sdk-go-v2/service/elasticloadbalancing"
	"github.com/aws/aws-sdk-go-v2/service/elasticloadbalancingv2"
	elbv2types "github.com/aws/aws-sdk-go-v2/service/elasticloadbalancingv2/types"
)

func main() {
	vpcID := flag.String("vpc-id", "", "VPC ID to clean up (required)")
	region := flag.String("region", "", "AWS region (required)")
	profile := flag.String("profile", "", "AWS named profile (aws_profile from terraform.tfvars)")
	accessKeyID := flag.String("access-key-id", "", "AWS access key ID (aws_access_key_id from terraform.tfvars)")
	secretAccessKey := flag.String("secret-access-key", "", "AWS secret access key (aws_secret_access_key from terraform.tfvars)")
	flag.Parse()

	if *vpcID == "" || *region == "" {
		flag.Usage()
		os.Exit(1)
	}

	var cfgOpts []func(*config.LoadOptions) error
	cfgOpts = append(cfgOpts, config.WithRegion(*region))

	switch {
	case *accessKeyID != "" && *secretAccessKey != "":
		// Explicit static credentials take highest priority.
		cfgOpts = append(cfgOpts, config.WithCredentialsProvider(
			credentials.NewStaticCredentialsProvider(*accessKeyID, *secretAccessKey, ""),
		))
	case *profile != "":
		// Named profile takes second priority.
		cfgOpts = append(cfgOpts, config.WithSharedConfigProfile(*profile))
	default:
		// Fall back to the standard SDK credential chain.
		// If AWS_PROFILE is empty, unset it so the SDK does not try profile "".
		if os.Getenv("AWS_PROFILE") == "" {
			os.Unsetenv("AWS_PROFILE")
		}
	}

	cfg, err := config.LoadDefaultConfig(context.TODO(), cfgOpts...)
	if err != nil {
		log.Fatalf("ERROR: failed to load AWS config: %v", err)
	}

	ctx := context.Background()
	fmt.Printf("=== Cleaning up orphaned AWS resources in VPC %s (region: %s) ===\n", *vpcID, *region)

	var errs []error
	if err := cleanupELBv2(ctx, cfg, *vpcID); err != nil {
		errs = append(errs, fmt.Errorf("ELBv2 cleanup: %w", err))
	}
	if err := cleanupClassicELB(ctx, cfg, *vpcID); err != nil {
		errs = append(errs, fmt.Errorf("Classic ELB cleanup: %w", err))
	}
	if err := cleanupNATGateways(ctx, cfg, *vpcID); err != nil {
		errs = append(errs, fmt.Errorf("NAT Gateway cleanup: %w", err))
	}
	if err := cleanupENIs(ctx, cfg, *vpcID); err != nil {
		errs = append(errs, fmt.Errorf("ENI cleanup: %w", err))
	}
	if err := cleanupSecurityGroups(ctx, cfg, *vpcID); err != nil {
		errs = append(errs, fmt.Errorf("Security group cleanup: %w", err))
	}

	if len(errs) > 0 {
		for _, e := range errs {
			log.Printf("ERROR: %v", e)
		}
		fmt.Fprintln(os.Stderr, "=== VPC cleanup finished with errors — see above ===")
		os.Exit(1)
	}

	fmt.Println("=== VPC cleanup complete ===")
}

// cleanupELBv2 deletes all ALB/NLB load balancers in the VPC and waits until
// they are fully removed before returning.
func cleanupELBv2(ctx context.Context, cfg aws.Config, vpcID string) error {
	client := elasticloadbalancingv2.NewFromConfig(cfg)

	lbARNs, err := listELBv2InVPC(ctx, client, vpcID)
	if err != nil {
		return err
	}
	if len(lbARNs) == 0 {
		fmt.Println("  [ELBv2] No ALB/NLB load balancers found.")
		return nil
	}

	for _, arn := range lbARNs {
		fmt.Printf("  [ELBv2] Deleting: %s\n", arn)
		_, err := client.DeleteLoadBalancer(ctx, &elasticloadbalancingv2.DeleteLoadBalancerInput{
			LoadBalancerArn: aws.String(arn),
		})
		if err != nil {
			// Log but continue — partial deletions are still progress.
			log.Printf("  [ELBv2] WARNING: failed to delete %s: %v", arn, err)
		}
	}

	// Poll until all LBs in the VPC are gone (max ~4 minutes).
	fmt.Println("  [ELBv2] Waiting for load balancers to finish deleting...")
	const maxAttempts = 24
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		time.Sleep(10 * time.Second)
		remaining, err := listELBv2InVPC(ctx, client, vpcID)
		if err != nil {
			log.Printf("  [ELBv2] WARNING: poll error: %v", err)
			continue
		}
		if len(remaining) == 0 {
			fmt.Println("  [ELBv2] All load balancers deleted.")
			return nil
		}
		fmt.Printf("  [ELBv2] Still waiting for %d load balancer(s)... (%d/%d)\n",
			len(remaining), attempt, maxAttempts)
	}
	return fmt.Errorf("timed out waiting for ALB/NLB load balancers in VPC %s to be deleted", vpcID)
}

func listELBv2InVPC(ctx context.Context, client *elasticloadbalancingv2.Client, vpcID string) ([]string, error) {
	var arns []string
	paginator := elasticloadbalancingv2.NewDescribeLoadBalancersPaginator(client,
		&elasticloadbalancingv2.DescribeLoadBalancersInput{})
	for paginator.HasMorePages() {
		page, err := paginator.NextPage(ctx)
		if err != nil {
			// If the LB is already gone, the API may return a "not found" error — treat as success.
			var notFound *elbv2types.LoadBalancerNotFoundException
			if errors.As(err, &notFound) {
				return nil, nil
			}
			return nil, fmt.Errorf("describe ELBv2: %w", err)
		}
		for _, lb := range page.LoadBalancers {
			if aws.ToString(lb.VpcId) == vpcID {
				arns = append(arns, aws.ToString(lb.LoadBalancerArn))
			}
		}
	}
	return arns, nil
}

// cleanupClassicELB deletes all Classic (ELBv1) load balancers in the VPC.
func cleanupClassicELB(ctx context.Context, cfg aws.Config, vpcID string) error {
	client := elasticloadbalancing.NewFromConfig(cfg)

	var names []string
	paginator := elasticloadbalancing.NewDescribeLoadBalancersPaginator(client,
		&elasticloadbalancing.DescribeLoadBalancersInput{})
	for paginator.HasMorePages() {
		page, err := paginator.NextPage(ctx)
		if err != nil {
			return fmt.Errorf("describe Classic ELB: %w", err)
		}
		for _, lb := range page.LoadBalancerDescriptions {
			if aws.ToString(lb.VPCId) == vpcID {
				names = append(names, aws.ToString(lb.LoadBalancerName))
			}
		}
	}

	if len(names) == 0 {
		fmt.Println("  [ELBv1] No Classic load balancers found.")
		return nil
	}

	for _, name := range names {
		fmt.Printf("  [ELBv1] Deleting: %s\n", name)
		_, err := client.DeleteLoadBalancer(ctx, &elasticloadbalancing.DeleteLoadBalancerInput{
			LoadBalancerName: aws.String(name),
		})
		if err != nil {
			log.Printf("  [ELBv1] WARNING: failed to delete %s: %v", name, err)
		}
	}

	// Classic ELBs delete quickly; a short pause is sufficient.
	fmt.Println("  [ELBv1] Waiting 15s for Classic ELBs to finish deleting...")
	time.Sleep(15 * time.Second)
	return nil
}

// cleanupNATGateways deletes all non-deleted NAT Gateways in the VPC, waits for
// them to fully delete, then releases their associated Elastic IPs.
func cleanupNATGateways(ctx context.Context, cfg aws.Config, vpcID string) error {
	client := ec2.NewFromConfig(cfg)

	out, err := client.DescribeNatGateways(ctx, &ec2.DescribeNatGatewaysInput{
		Filter: []ec2types.Filter{
			{Name: aws.String("vpc-id"), Values: []string{vpcID}},
		},
	})
	if err != nil {
		return fmt.Errorf("describe NAT gateways: %w", err)
	}

	var gwIDs []string
	var eipAllocIDs []string
	for _, gw := range out.NatGateways {
		if gw.State == ec2types.NatGatewayStateDeleted || gw.State == ec2types.NatGatewayStateFailed {
			continue
		}
		gwIDs = append(gwIDs, aws.ToString(gw.NatGatewayId))
		for _, addr := range gw.NatGatewayAddresses {
			if addr.AllocationId != nil {
				eipAllocIDs = append(eipAllocIDs, aws.ToString(addr.AllocationId))
			}
		}
	}

	if len(gwIDs) == 0 {
		fmt.Println("  [NAT] No NAT Gateways found.")
		return nil
	}

	for _, id := range gwIDs {
		fmt.Printf("  [NAT] Deleting NAT Gateway: %s\n", id)
		if _, err := client.DeleteNatGateway(ctx, &ec2.DeleteNatGatewayInput{
			NatGatewayId: aws.String(id),
		}); err != nil {
			log.Printf("  [NAT] WARNING: failed to delete %s: %v", id, err)
		}
	}

	// Poll until all reach 'deleted' state (max ~5 minutes).
	fmt.Println("  [NAT] Waiting for NAT Gateways to finish deleting...")
	const maxAttempts = 30
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		time.Sleep(10 * time.Second)
		poll, err := client.DescribeNatGateways(ctx, &ec2.DescribeNatGatewaysInput{
			NatGatewayIds: gwIDs,
		})
		if err != nil {
			log.Printf("  [NAT] WARNING: poll error: %v", err)
			continue
		}
		allDone := true
		for _, gw := range poll.NatGateways {
			if gw.State != ec2types.NatGatewayStateDeleted && gw.State != ec2types.NatGatewayStateFailed {
				allDone = false
				break
			}
		}
		if allDone {
			fmt.Println("  [NAT] All NAT Gateways deleted.")
			break
		}
		fmt.Printf("  [NAT] Still waiting... (%d/%d)\n", attempt, maxAttempts)
		if attempt == maxAttempts {
			return fmt.Errorf("timed out waiting for NAT Gateways in VPC %s to be deleted", vpcID)
		}
	}

	// Release the EIPs that were attached to the NAT Gateways.
	for _, allocID := range eipAllocIDs {
		fmt.Printf("  [NAT] Releasing EIP: %s\n", allocID)
		if _, err := client.ReleaseAddress(ctx, &ec2.ReleaseAddressInput{
			AllocationId: aws.String(allocID),
		}); err != nil {
			log.Printf("  [NAT] WARNING: failed to release EIP %s: %v", allocID, err)
		}
	}
	return nil
}

// cleanupSecurityGroups deletes all non-default security groups in the VPC.
// It first revokes all rules (to break cross-references between groups) then
// deletes them. The default security group cannot be deleted by AWS design.
func cleanupSecurityGroups(ctx context.Context, cfg aws.Config, vpcID string) error {
	client := ec2.NewFromConfig(cfg)

	out, err := client.DescribeSecurityGroups(ctx, &ec2.DescribeSecurityGroupsInput{
		Filters: []ec2types.Filter{
			{Name: aws.String("vpc-id"), Values: []string{vpcID}},
		},
	})
	if err != nil {
		return fmt.Errorf("describe security groups: %w", err)
	}

	var groups []ec2types.SecurityGroup
	for _, sg := range out.SecurityGroups {
		if aws.ToString(sg.GroupName) == "default" {
			continue
		}
		groups = append(groups, sg)
	}

	if len(groups) == 0 {
		fmt.Println("  [SG] No non-default security groups found.")
		return nil
	}

	// First pass: revoke all ingress/egress rules to clear cross-references.
	for _, sg := range groups {
		sgID := aws.ToString(sg.GroupId)
		if len(sg.IpPermissions) > 0 {
			if _, err := client.RevokeSecurityGroupIngress(ctx, &ec2.RevokeSecurityGroupIngressInput{
				GroupId:       aws.String(sgID),
				IpPermissions: sg.IpPermissions,
			}); err != nil {
				log.Printf("  [SG] WARNING: failed to revoke ingress for %s: %v", sgID, err)
			}
		}
		if len(sg.IpPermissionsEgress) > 0 {
			if _, err := client.RevokeSecurityGroupEgress(ctx, &ec2.RevokeSecurityGroupEgressInput{
				GroupId:       aws.String(sgID),
				IpPermissions: sg.IpPermissionsEgress,
			}); err != nil {
				log.Printf("  [SG] WARNING: failed to revoke egress for %s: %v", sgID, err)
			}
		}
	}

	// Second pass: delete the groups.
	var deleteErrs []error
	for _, sg := range groups {
		sgID := aws.ToString(sg.GroupId)
		fmt.Printf("  [SG] Deleting security group: %s (%s)\n", sgID, aws.ToString(sg.GroupName))
		if _, err := client.DeleteSecurityGroup(ctx, &ec2.DeleteSecurityGroupInput{
			GroupId: aws.String(sgID),
		}); err != nil {
			log.Printf("  [SG] WARNING: failed to delete %s: %v", sgID, err)
			deleteErrs = append(deleteErrs, err)
		}
	}

	if len(deleteErrs) > 0 {
		return fmt.Errorf("%d security group(s) could not be deleted", len(deleteErrs))
	}
	return nil
}

// cleanupENIs deletes orphaned ENIs (status=available, not attached to anything)
// in the VPC. These are typically left behind by deleted load balancers.
func cleanupENIs(ctx context.Context, cfg aws.Config, vpcID string) error {
	client := ec2.NewFromConfig(cfg)

	out, err := client.DescribeNetworkInterfaces(ctx, &ec2.DescribeNetworkInterfacesInput{
		Filters: []ec2types.Filter{
			{Name: aws.String("vpc-id"), Values: []string{vpcID}},
			{Name: aws.String("status"), Values: []string{"available"}},
		},
	})
	if err != nil {
		return fmt.Errorf("describe ENIs: %w", err)
	}

	if len(out.NetworkInterfaces) == 0 {
		fmt.Println("  [ENI] No orphaned ENIs found.")
		return nil
	}

	var deleteErrs []error
	for _, eni := range out.NetworkInterfaces {
		eniID := aws.ToString(eni.NetworkInterfaceId)
		fmt.Printf("  [ENI] Deleting orphaned ENI: %s\n", eniID)
		_, err := client.DeleteNetworkInterface(ctx, &ec2.DeleteNetworkInterfaceInput{
			NetworkInterfaceId: aws.String(eniID),
		})
		if err != nil {
			log.Printf("  [ENI] WARNING: failed to delete %s: %v", eniID, err)
			deleteErrs = append(deleteErrs, err)
		}
	}

	if len(deleteErrs) > 0 {
		return fmt.Errorf("%d ENI(s) could not be deleted", len(deleteErrs))
	}
	return nil
}
