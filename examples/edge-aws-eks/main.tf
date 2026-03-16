# Complete AWS EKS Deployment with Edge - Unified Provider Edition
# Uses aws-eks module for cluster creation and guardium-data-protection provider for Edge deployment
# Set deploy_eks=false to skip EKS creation and only deploy edge components

terraform {
  required_version = ">= 1.2"  # lifecycle preconditions require >= 1.2
  required_providers {
    guardium-data-protection = {
      # For internal testing with IBM Artifactory
      source  = "registry.terraform.io/ibm/guardium-data-protection"
      # For public release (uncomment when published to HashiCorp registry)
      # source  = "hashicorp.com/ibm/guardium-data-protection"
      version = "1.0.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ============================================================================
# Provider Configuration
# ============================================================================

provider "guardium-data-protection" {
  cm_url       = var.edge_cm_url
  oauth_token  = var.edge_oauth_token
  platform     = "eks"

  # AWS EKS configuration
  aws_region        = var.aws_region
  aws_profile       = var.aws_profile
  aws_access_key    = var.aws_access_key_id
  aws_secret_key    = var.aws_secret_access_key
  eks_ssh_user           = var.eks_ssh_user
  eks_ssh_key_path       = var.eks_ssh_key_path
  eks_ssh_key_passphrase = var.eks_ssh_key_passphrase
  eks_hostname_type      = var.eks_hostname_type
}

provider "aws" {
  region     = var.aws_region
  profile    = var.aws_profile != "" ? var.aws_profile : null
  access_key = var.aws_access_key_id != "" ? var.aws_access_key_id : null
  secret_key = var.aws_secret_access_key != "" ? var.aws_secret_access_key : null
}

# ============================================================================
# Module 1: Create AWS EKS Cluster (Optional)
# ============================================================================

module "aws_eks" {
  source = "../aws-eks"

  # Control whether to deploy EKS
  deploy_eks = var.deploy_eks

  # AWS credentials
  aws_region            = var.aws_region
  aws_profile           = var.aws_profile
  aws_access_key_id     = var.aws_access_key_id
  aws_secret_access_key = var.aws_secret_access_key

  # Cluster configuration
  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version

  # Network configuration
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs

  # Node configuration
  node_group_name         = var.node_group_name
  node_instance_type      = var.node_instance_type
  node_group_min_size     = var.node_group_min_size
  node_group_max_size     = var.node_group_max_size
  node_group_desired_size = var.node_group_desired_size
  node_volume_size        = var.node_volume_size
  node_group_subnet_type  = var.node_group_subnet_type

  # SSH configuration
  ssh_key_name            = var.ssh_key_name
  ssh_allowed_cidr_blocks = var.ssh_allowed_cidr_blocks

  # Storage configuration
  create_efs             = var.create_efs
  ebs_csi_driver_version = var.ebs_csi_driver_version
  efs_csi_driver_version = var.efs_csi_driver_version

  # Tags
  tags = var.tags
}

# ============================================================================
# Resource 2: Deploy Edge Components via Unified Provider (Optional)
#
# Metrics Server and Edge are both installed by the guardium-data-protection provider,
# which authenticates to the EKS cluster via AWS SDK — no static Kubernetes token
# is required. This avoids the 15-minute STS token expiry problem that affects
# the hashicorp/kubernetes and gavinbunney/kubectl Terraform providers.
#
# Finalizer cleanup and namespace termination are handled natively by the
# guardium-data-protection provider via WaitForNamespaceDeletion during destroy.
# ============================================================================

locals {
  eks_cluster_name = var.deploy_eks ? module.aws_eks.cluster_name : (
    var.external_eks_cluster_name != "" ? var.external_eks_cluster_name : var.cluster_name
  )
}

resource "guardium-data-protection_deployment" "edge" {
  count    = var.install_edge ? 1 : 0
  provider = guardium-data-protection

  depends_on = [module.aws_eks]

  # Bundle source - use either edge_name (download from CM) or bundle_directory (local)
  edge_name             = var.edge_name
  edge_bundle_directory = var.edge_bundle_directory

  # Platform
  platform = "eks"

  # EKS configuration
  eks_cluster_name = var.deploy_eks ? module.aws_eks.cluster_name : var.external_eks_cluster_name

  # Monitoring configuration
  monitor_max_attempts   = var.edge_monitor_max_attempts
  monitor_sleep_interval = var.edge_monitor_sleep_interval

  # General
  cleanup_bundle          = var.edge_cleanup_bundle
  external_image_registry = var.external_image_registry

  # Kubernetes Metrics Server — installed by the guardium-data-protection provider
  # via AWS SDK credentials before Edge deployment. No static Kubernetes token required.
  k8s_metrics_server_install              = var.k8s_metrics_server_install
  k8s_metrics_server_airgap_install       = var.k8s_mertics_server_airgap_install
  k8s_metrics_server_airgap_install_path  = var.k8s_metrics_server_airgap_install_path
}
