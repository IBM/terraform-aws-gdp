# Copyright (c) IBM Corporation
# SPDX-License-Identifier: Apache-2.0

variable "deploy_eks" {
  description = "Whether to deploy EKS cluster resources (set to false to skip deployment)"
  type        = bool
  default     = true
}

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

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default = {
    Environment = "development"
    ManagedBy   = "terraform"
    Project     = "guardium-jewel"
  }
}