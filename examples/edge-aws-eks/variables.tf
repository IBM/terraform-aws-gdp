# Copyright (c) IBM Corporation
# SPDX-License-Identifier: Apache-2.0

# Complete AWS EKS Deployment Variables - Unified Provider Edition
# Uses aws-eks module and guardium-data-protection provider

# ============================================================================
# Deployment Control
# ============================================================================

variable "deploy_eks" {
  description = "Whether to deploy EKS cluster (set to false to use existing cluster)"
  type        = bool
  default     = true
}

variable "external_eks_cluster_name" {
  description = "External EKS cluster name (required if deploy_eks=false)"
  type        = string
  default     = ""
}

# ============================================================================
# AWS Credentials
# ============================================================================

variable "aws_region" {
  description = "AWS region where the EKS cluster will be created"
  type        = string
  default     = "us-east-2"
}

variable "aws_profile" {
  description = "AWS profile to use for authentication (optional, can use AWS_PROFILE env var)"
  type        = string
  default     = ""
}

variable "aws_access_key_id" {
  description = "AWS access key ID (optional, alternative to aws_profile)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS secret access key (optional, alternative to aws_profile)"
  type        = string
  default     = ""
  sensitive   = true
}

# ============================================================================
# EKS Cluster Configuration
# ============================================================================

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "edge-eks-gm"
}

variable "kubernetes_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.33"
}

# ============================================================================
# Network Configuration
# ============================================================================

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

# ============================================================================
# Node Configuration
# ============================================================================

variable "node_group_name" {
  description = "Name of the EKS managed node group"
  type        = string
  default     = "ng-gm"
}

variable "node_instance_type" {
  description = "EC2 instance type for the EKS node group"
  type        = string
  default     = "m5.4xlarge"
}

variable "node_group_min_size" {
  description = "Minimum number of nodes in the node group"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in the node group"
  type        = number
  default     = 4
}

variable "node_group_desired_size" {
  description = "Desired number of nodes in the node group"
  type        = number
  default     = 2
}

variable "node_volume_size" {
  description = "Size of the EBS volume attached to each node (in GB)"
  type        = number
  default     = 500
}

# ============================================================================
# SSH Configuration
# ============================================================================

variable "node_group_subnet_type" {
  description = "Subnet type for EKS worker nodes: 'private' (default) or 'public'. Use 'public' only when direct SSH from outside the VPC is required (e.g. certificate installation from a machine with no VPC access)."
  type        = string
  default     = "private"

  validation {
    condition     = contains(["private", "public"], var.node_group_subnet_type)
    error_message = "node_group_subnet_type must be either 'private' or 'public'"
  }
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair to use for node access"
  type        = string
  default     = ""
}

variable "ssh_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to SSH into the nodes"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ============================================================================
# Storage Configuration
# ============================================================================

variable "create_efs" {
  description = "Whether to create an EFS file system for the cluster"
  type        = bool
  default     = true
}

variable "ebs_csi_driver_version" {
  description = "Version of the EBS CSI driver addon"
  type        = string
  default     = null # Uses latest version if not specified
}

variable "efs_csi_driver_version" {
  description = "Version of the EFS CSI driver addon"
  type        = string
  default     = null # Uses latest version if not specified
}

# ============================================================================
# Tags
# ============================================================================

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default = {
    Environment = "development"
    ManagedBy   = "terraform"
    Project     = "guardium-jewel"
  }
}

# ============================================================================
# Edge Deployment Configuration (Optional)
# ============================================================================

variable "install_edge" {
  description = "Whether to install Edge components"
  type        = bool
  default     = false
}

variable "edge_name" {
  description = "Name of the edge to deploy (required if downloading bundle from CM)"
  type        = string
  default     = ""
}

variable "edge_bundle_directory" {
  description = "Path to local edge bundle directory. If empty, bundle will be downloaded from CM."
  type        = string
  default     = ""
}

variable "edge_cm_url" {
  description = "Guardium Insights Central Manager URL"
  type        = string
  default     = ""
}

variable "edge_oauth_token" {
  description = "OAuth token for CM authentication"
  type        = string
  default     = ""
  sensitive   = true
}

variable "edge_monitor_max_attempts" {
  description = "Maximum polling attempts for edge deployment monitoring (default: 180 = ~30 min with 10s interval)"
  type        = number
  default     = 180
}

variable "edge_monitor_sleep_interval" {
  description = "Sleep interval in seconds between edge monitoring polls"
  type        = number
  default     = 10
}

variable "edge_cleanup_bundle" {
  description = "Whether to cleanup downloaded edge bundle on destroy"
  type        = bool
  default     = true
}

variable "external_image_registry" {
  description = "Set to true when using an external image registry (e.g. Docker Hub, Quay) instead of the CM private registry. Skips registry certificate installation on cluster nodes."
  type        = bool
  default     = false
}

# ============================================================================
# Edge EKS-Specific Configuration
# ============================================================================

variable "eks_hostname_type" {
  description = "Type of hostname to use for EKS nodes: 'public' or 'private'"
  type        = string
  default     = "public"

  validation {
    condition     = contains(["public", "private"], var.eks_hostname_type)
    error_message = "EKS hostname type must be either 'public' or 'private'"
  }
}

variable "eks_ssh_user" {
  description = "SSH user for EKS nodes"
  type        = string
  default     = "ec2-user"
}

variable "eks_ssh_key_path" {
  description = "Path to SSH private key for EKS nodes (required if installing Edge)"
  type        = string
  default     = ""
}

variable "eks_ssh_key_passphrase" {
  description = "Passphrase for the EKS SSH key (if the key is passphrase-protected)"
  type        = string
  default     = ""
  sensitive   = true
}

# ============================================================================
# Kubernetes Metrics Server Configuration
# ============================================================================

variable "k8s_metrics_server_install" {
  description = "Whether to install Kubernetes Metrics Server into the EKS cluster"
  type        = bool
  default     = false
}

variable "k8s_mertics_server_airgap_install" {
  description = "Whether to use airgap (offline) installation for Kubernetes Metrics Server"
  type        = bool
  default     = false
}

variable "k8s_metrics_server_airgap_install_path" {
  description = "Local file or directory path to the Metrics Server manifests for airgap installation"
  type        = string
  default     = ""
}
