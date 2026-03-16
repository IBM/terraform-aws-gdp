output "cluster_id" {
  description = "The ID of the EKS cluster"
  value       = var.deploy_eks ? module.eks[0].cluster_id : data.aws_eks_cluster.existing[0].id
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  # Derived from the computed cluster_arn (not the input variable) so that this
  # output is (known after apply) on first apply.  The parent module uses this
  # value in data "aws_eks_cluster", which Terraform reads at plan time when the
  # value is known.  By tying it to cluster_arn, Terraform defers the data source
  # read until after the cluster is created, preventing "couldn't find resource".
  value       = var.deploy_eks ? element(split("/", module.eks[0].cluster_arn), 1) : var.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = var.deploy_eks ? module.eks[0].cluster_endpoint : data.aws_eks_cluster.existing[0].endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = var.deploy_eks ? module.eks[0].cluster_security_group_id : null
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = var.deploy_eks ? module.eks[0].cluster_iam_role_arn : null
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = var.deploy_eks ? module.eks[0].cluster_certificate_authority_data : data.aws_eks_cluster.existing[0].certificate_authority[0].data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = var.deploy_eks ? module.eks[0].cluster_oidc_issuer_url : null
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  value       = var.deploy_eks ? module.eks[0].oidc_provider_arn : null
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = var.deploy_eks ? module.vpc[0].vpc_id : null
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = var.deploy_eks ? module.vpc[0].private_subnets : []
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = var.deploy_eks ? module.vpc[0].public_subnets : []
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = var.deploy_eks ? module.eks[0].node_security_group_id : null
}

output "node_group_id" {
  description = "EKS node group ID"
  value       = var.deploy_eks ? module.eks[0].eks_managed_node_groups[var.node_group_name].node_group_id : null
}

output "node_group_arn" {
  description = "Amazon Resource Name (ARN) of the EKS Node Group"
  value       = var.deploy_eks ? module.eks[0].eks_managed_node_groups[var.node_group_name].node_group_arn : null
}

output "node_group_status" {
  description = "Status of the EKS node group"
  value       = var.deploy_eks ? module.eks[0].eks_managed_node_groups[var.node_group_name].node_group_status : null
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of IAM role for EBS CSI driver"
  value       = var.deploy_eks ? module.ebs_csi_irsa_role[0].iam_role_arn : null
}

output "efs_csi_driver_role_arn" {
  description = "ARN of IAM role for EFS CSI driver"
  value       = var.deploy_eks ? module.efs_csi_irsa_role[0].iam_role_arn : null
}

output "efs_id" {
  description = "The ID of the EFS file system"
  value       = var.deploy_eks && var.create_efs ? aws_efs_file_system.eks_efs[0].id : null
}

output "efs_dns_name" {
  description = "The DNS name of the EFS file system"
  value       = var.deploy_eks && var.create_efs ? aws_efs_file_system.eks_efs[0].dns_name : null
}

output "configure_kubectl" {
  description = "Path to the generated kubeconfig file"
  value       = var.deploy_eks ? local_file.kubeconfig[0].filename : null
}

output "kubeconfig" {
  description = "Generated kubeconfig content"
  sensitive   = true
  value       = var.deploy_eks ? local.kubeconfig_content : null
}

output "ebs_storage_class_name" {
  description = "Name of the EBS storage class"
  value       = var.deploy_eks ? "ebs-sc" : null
}

output "efs_storage_class_name" {
  description = "Name of the EFS storage class"
  value       = var.deploy_eks && var.create_efs ? "efs-sc" : null
}
