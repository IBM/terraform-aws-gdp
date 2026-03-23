// Copyright (c) IBM Corporation
// SPDX-License-Identifier: Apache-2.0

# AWS EKS Cluster Terraform Configuration

This Terraform configuration creates an AWS EKS (Elastic Kubernetes Service) cluster based on the specifications defined in the YAML configuration files.

## Overview

This configuration provisions:
- **EKS Cluster** (Kubernetes v1.33)
- **VPC** with public and private subnets across 3 availability zones
- **EKS Managed Node Group** with m5.4xlarge instances
- **EBS CSI Driver** for block storage (ReadWriteOnce)
- **EFS CSI Driver** for shared storage (ReadWriteMany)
- **EFS File System** for persistent shared storage
- **Storage Classes** for both EBS and EFS
- **IAM Roles** with OIDC provider for service accounts
- **Security Groups** for node SSH access and EFS mounting

## Prerequisites

1. **AWS CLI** installed and configured with appropriate credentials
2. **Terraform** >= 1.0 installed
3. **kubectl** installed for cluster management
4. **AWS Account** with permissions to create EKS, VPC, IAM, and related resources
5. **EC2 Key Pair** created in AWS (for SSH access to nodes)

## Configuration Files

- [`main.tf`](main.tf) - Main Terraform configuration with all resources
- [`variables.tf`](variables.tf) - Variable definitions with defaults
- [`outputs.tf`](outputs.tf) - Output values after deployment
- [`terraform.tfvars.example`](terraform.tfvars.example) - Example variable values
- [`cluster-gm.yaml`](cluster-gm.yaml) - Original eksctl configuration (reference)
- [`storage-classes.yaml`](storage-classes.yaml) - Storage class definitions (reference)

## Quick Start

### 1. Configure Variables

Copy the example tfvars file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and update the following critical values:

```hcl
# REQUIRED: Set your SSH key name (must exist in AWS)
ssh_key_name = "your-ec2-key-name"

# RECOMMENDED: Restrict SSH access to your IP
ssh_allowed_cidr_blocks = ["YOUR.IP.ADDRESS/32"]

# Optional: Customize other values as needed
cluster_name = "edge-eks-gm"
aws_region   = "us-east-2"
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review the Plan

```bash
terraform plan
```

### 4. Deploy the Cluster

```bash
terraform apply
```

This will take approximately 15-20 minutes to complete.

### 5. Configure kubectl

After deployment, configure kubectl to access your cluster:

```bash
aws eks update-kubeconfig --region us-east-2 --name edge-eks-gm
```

Or use the output command:

```bash
terraform output -raw configure_kubectl | bash
```

### 6. Verify the Cluster

```bash
# Check cluster info
kubectl cluster-info

# Check nodes
kubectl get nodes

# Check storage classes
kubectl get storageclass

# Verify CSI drivers
kubectl get pods -n kube-system | grep csi
```

## Storage Classes

Two storage classes are automatically created:

### EBS Storage Class (`ebs-sc`)
- **Provisioner**: `ebs.csi.aws.com`
- **Type**: gp3 (General Purpose SSD)
- **Access Mode**: ReadWriteOnce (RWO)
- **Use Case**: Single-node persistent volumes
- **Volume Expansion**: Enabled

Example PVC:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ebs-claim
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ebs-sc
  resources:
    requests:
      storage: 10Gi
```

### EFS Storage Class (`efs-sc`)
- **Provisioner**: `efs.csi.aws.com`
- **Access Mode**: ReadWriteMany (RWX)
- **Use Case**: Multi-node shared persistent volumes
- **Volume Expansion**: Enabled (elastic by nature)

Example PVC:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: efs-claim
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-sc
  resources:
    requests:
      storage: 5Gi
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Region                          │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    VPC (10.0.0.0/16)                  │  │
│  │                                                       │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐│  │
│  │  │   Public     │  │   Public     │  │   Public     ││  │
│  │  │   Subnet     │  │   Subnet     │  │   Subnet     ││  │
│  │  │   (AZ-1)     │  │   (AZ-2)     │  │   (AZ-3)     ││  │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘│  │
│  │         │                 │                 │        │  │
│  │    ┌────┴─────────────────┴─────────────────┴────┐   │  │
│  │    │          Internet Gateway / NAT          │   │  │
│  │    └────┬─────────────────┬─────────────────┬────┘   │  │
│  │         │                 │                 │        │  │
│  │  ┌──────┴───────┐  ┌──────┴───────┐  ┌──────┴───────┐│  │
│  │  │   Private    │  │   Private    │  │   Private    ││  │
│  │  │   Subnet     │  │   Subnet     │  │   Subnet     ││  │
│  │  │   (AZ-1)     │  │   (AZ-2)     │  │   (AZ-3)     ││  │
│  │  │              │  │              │  │              ││  │
│  │  │  ┌────────┐  │  │  ┌────────┐  │  │  ┌────────┐  ││  │
│  │  │  │EKS Node│  │  │  │EKS Node│  │  │  │        │  ││  │
│  │  │  │m5.4xl  │  │  │  │m5.4xl  │  │  │  │        │  ││  │
│  │  │  └────────┘  │  │  └────────┘  │  │  └────────┘  ││  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘│  │
│  │                                                       │  │
│  │  ┌─────────────────────────────────────────────────┐ │  │
│  │  │         EKS Control Plane (Managed)             │ │  │
│  │  └─────────────────────────────────────────────────┘ │  │
│  │                                                       │  │
│  │  ┌─────────────────────────────────────────────────┐ │  │
│  │  │    EFS File System (Multi-AZ, Shared Storage)   │ │  │
│  │  └─────────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Customization

### Modify Node Group Size

Edit `terraform.tfvars`:

```hcl
node_group_min_size     = 2
node_group_max_size     = 6
node_group_desired_size = 3
```

### Change Node Group Name

```hcl
node_group_name = "my-custom-node-group"
```

### Change Instance Type

```hcl
node_instance_type = "m5.2xlarge"
```

### Adjust Node Volume Size

```hcl
node_volume_size = 1000  # GB
```

### Disable EFS Creation

If you don't need shared storage:

```hcl
create_efs = false
```

## Outputs

After deployment, Terraform provides useful outputs:

```bash
# Get cluster endpoint
terraform output cluster_endpoint

# Get EFS ID
terraform output efs_id

# Get kubectl configuration command
terraform output configure_kubectl

# Get all outputs
terraform output
```


## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will permanently delete the cluster and all associated resources, including any data stored in EFS.

## Troubleshooting

### Issue: Terraform fails with authentication error

**Solution**: Ensure AWS CLI is configured:
```bash
aws configure
aws sts get-caller-identity
```

### Issue: Node group fails to create

**Solution**: Check that the SSH key name exists in your AWS region:
```bash
aws ec2 describe-key-pairs --region us-east-2
```

### Issue: Storage class not appearing

**Solution**: Verify CSI drivers are running:
```bash
kubectl get pods -n kube-system | grep csi
kubectl describe addon aws-ebs-csi-driver -n kube-system
kubectl describe addon aws-efs-csi-driver -n kube-system
```

### Issue: Cannot connect to cluster

**Solution**: Update kubeconfig:
```bash
aws eks update-kubeconfig --region us-east-2 --name edge-eks-gm
```
## Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [EBS CSI Driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver)
- [EFS CSI Driver](https://github.com/kubernetes-sigs/aws-efs-csi-driver)
- [Terraform AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
