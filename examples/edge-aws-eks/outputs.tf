# Copyright (c) IBM Corporation
# SPDX-License-Identifier: Apache-2.0

# Complete AWS EKS Deployment Outputs - Unified Provider Edition

# ============================================================================
# EKS Cluster Outputs (if deployed)
# ============================================================================

output "cluster_id" {
  description = "The ID of the EKS cluster"
  value       = var.deploy_eks ? module.aws_eks.cluster_id : null
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = var.deploy_eks ? module.aws_eks.cluster_name : var.external_eks_cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = var.deploy_eks ? module.aws_eks.cluster_endpoint : null
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = var.deploy_eks ? module.aws_eks.cluster_security_group_id : null
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = var.deploy_eks ? module.aws_eks.cluster_iam_role_arn : null
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = var.deploy_eks ? module.aws_eks.cluster_certificate_authority_data : null
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = var.deploy_eks ? module.aws_eks.cluster_oidc_issuer_url : null
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  value       = var.deploy_eks ? module.aws_eks.oidc_provider_arn : null
}

# ============================================================================
# Network Outputs (if deployed)
# ============================================================================

output "vpc_id" {
  description = "The ID of the VPC"
  value       = var.deploy_eks ? module.aws_eks.vpc_id : null
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = var.deploy_eks ? module.aws_eks.private_subnets : null
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = var.deploy_eks ? module.aws_eks.public_subnets : null
}

# ============================================================================
# Node Group Outputs (if deployed)
# ============================================================================

output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = var.deploy_eks ? module.aws_eks.node_security_group_id : null
}

output "node_group_id" {
  description = "EKS node group ID"
  value       = var.deploy_eks ? module.aws_eks.node_group_id : null
}

output "node_group_arn" {
  description = "Amazon Resource Name (ARN) of the EKS Node Group"
  value       = var.deploy_eks ? module.aws_eks.node_group_arn : null
}

output "node_group_status" {
  description = "Status of the EKS node group"
  value       = var.deploy_eks ? module.aws_eks.node_group_status : null
}

# ============================================================================
# Storage Outputs (if deployed)
# ============================================================================

output "ebs_csi_driver_role_arn" {
  description = "ARN of IAM role for EBS CSI driver"
  value       = var.deploy_eks ? module.aws_eks.ebs_csi_driver_role_arn : null
}

output "efs_csi_driver_role_arn" {
  description = "ARN of IAM role for EFS CSI driver"
  value       = var.deploy_eks ? module.aws_eks.efs_csi_driver_role_arn : null
}

output "efs_id" {
  description = "The ID of the EFS file system"
  value       = var.deploy_eks ? module.aws_eks.efs_id : null
}

output "efs_dns_name" {
  description = "The DNS name of the EFS file system"
  value       = var.deploy_eks ? module.aws_eks.efs_dns_name : null
}

output "ebs_storage_class_name" {
  description = "Name of the EBS storage class"
  value       = var.deploy_eks ? module.aws_eks.ebs_storage_class_name : null
}

output "efs_storage_class_name" {
  description = "Name of the EFS storage class"
  value       = var.deploy_eks ? module.aws_eks.efs_storage_class_name : null
}

# ============================================================================
# Access Instructions
# ============================================================================

output "configure_kubectl" {
  description = "Path to the generated kubeconfig file (no AWS CLI or kubectl required)"
  value       = var.deploy_eks ? module.aws_eks.configure_kubectl : null
}

output "kubeconfig" {
  description = "Generated kubeconfig content (no AWS CLI required). Usage: terraform output -raw kubeconfig > ~/.kube/config"
  sensitive   = true
  value       = var.deploy_eks ? module.aws_eks.kubeconfig : null
}

# ============================================================================
# Edge Deployment Outputs (if installed)
# ============================================================================

output "edge_installed" {
  description = "Whether Edge is installed"
  value       = var.install_edge
}

output "edge_namespace" {
  description = "Kubernetes namespace where Edge components are deployed (if installed)"
  value       = var.install_edge ? guardium-data-protection_deployment.edge[0].edge_namespace : null
}

output "edge_registry_url" {
  description = "Container registry URL used by the Edge deployment (if installed)"
  value       = var.install_edge ? guardium-data-protection_deployment.edge[0].registry_url : null
}

output "edge_platform" {
  description = "Platform where Edge is deployed (if installed)"
  value       = var.install_edge ? guardium-data-protection_deployment.edge[0].platform : null
}

output "edge_deployment_status" {
  description = "Edge deployment status message (if installed)"
  value       = var.install_edge ? guardium-data-protection_deployment.edge[0].deployment_status : null
}

output "edge_work_dir" {
  description = "Working directory for the edge bundle (if installed)"
  value       = var.install_edge ? guardium-data-protection_deployment.edge[0].work_dir : null
}

output "edge_summary" {
  description = "Edge deployment summary (if installed)"
  value = var.install_edge ? join("\n", [
    "Edge Deployment Summary:",
    "  Namespace: ${guardium-data-protection_deployment.edge[0].edge_namespace}",
    "  Platform:  ${guardium-data-protection_deployment.edge[0].platform}",
    "  Status:    ${guardium-data-protection_deployment.edge[0].deployment_status}",
    "",
    "To check status:",
    "  kubectl get configmap edge-controller-client-cm -n ${guardium-data-protection_deployment.edge[0].edge_namespace} -o yaml",
    "  kubectl get pods -n ${guardium-data-protection_deployment.edge[0].edge_namespace}",
  ]) : null
}

# ============================================================================
# Combined Summary
# ============================================================================

output "deployment_summary" {
  description = "Complete deployment summary"
  value = {
    cluster_name       = var.deploy_eks ? module.aws_eks.cluster_name : var.external_eks_cluster_name
    cluster_endpoint   = var.deploy_eks ? module.aws_eks.cluster_endpoint : null
    kubernetes_version = var.kubernetes_version
    aws_region         = var.aws_region
    vpc_id             = var.deploy_eks ? module.aws_eks.vpc_id : null
    node_group_status  = var.deploy_eks ? module.aws_eks.node_group_status : null
    ebs_storage_class  = var.deploy_eks ? module.aws_eks.ebs_storage_class_name : null
    efs_storage_class  = var.deploy_eks ? module.aws_eks.efs_storage_class_name : null
    edge_installed     = var.install_edge
    edge_namespace     = var.install_edge ? guardium-data-protection_deployment.edge[0].edge_namespace : null
    edge_status        = var.install_edge ? guardium-data-protection_deployment.edge[0].deployment_status : null
  }
}

output "access_instructions" {
  description = "Instructions to access the EKS cluster"
  value = var.deploy_eks ? join("\n", [
    "============================================================",
    "AWS EKS Cluster Access Instructions (no AWS CLI required)",
    "============================================================",
    "",
    "Kubeconfig was generated automatically at:",
    "  ${module.aws_eks.configure_kubectl}",
    "",
    "1. Use the generated kubeconfig:",
    "   export KUBECONFIG=${module.aws_eks.configure_kubectl}",
    "   # Or copy to default location:",
    "   # terraform output -raw kubeconfig > ~/.kube/config",
    "",
    "2. Verify cluster access:",
    "   kubectl get nodes",
    "",
    "3. View cluster info:",
    "   kubectl cluster-info",
    "",
    "4. Check storage classes:",
    "   kubectl get storageclass",
    "",
    var.install_edge ? "5. Check Edge deployment:\n   kubectl get pods -n ${guardium-data-protection_deployment.edge[0].edge_namespace}\n" : "",
    "============================================================",
  ]) : join("\n", [
    "============================================================",
    "Using Existing EKS Cluster: ${var.external_eks_cluster_name}",
    "============================================================",
    "",
    "Note: For an existing cluster, configure kubectl manually:",
    "  export KUBECONFIG=/path/to/your/kubeconfig",
    "",
    var.install_edge ? "Check Edge deployment:\n   kubectl get pods -n ${guardium-data-protection_deployment.edge[0].edge_namespace}\n" : "",
    "============================================================",
  ])
}
