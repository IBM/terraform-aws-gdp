#
# Copyright (c) IBM Corp. 2026
# SPDX-License-Identifier: Apache-2.0
#

##############################################
# IBM Guardium GDP - Aggregator Variables
##############################################

# =====================================================
# AWS & Network Configuration
# =====================================================

variable "region" {
  description = "AWS region for deployment"
  type        = string
}

variable "vpc_id" {
  description = "Existing VPC ID (optional). Leave empty to auto-create a VPC."
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "Existing Subnet ID (optional). Leave empty to auto-create a subnet."
  type        = string
  default     = null
}

variable "enable_auto_vpc" {
  description = "If true, Terraform will automatically create a new VPC, subnet, route table, and IGW when vpc_id/subnet_id are not provided."
  type        = bool
  default     = false
}

# =====================================================
# Guardium Deployment Configuration
# =====================================================

variable "key_name" {
  description = "Name of the AWS key pair to be used for SSH access."
  type        = string
}

variable "pem_file_path" {
  description = "Local path to the private key (.pem) for SSH/Expect automation."
  type        = string
}

variable "ami_type" {
  description = "AMI type: 'legacy' for unit-type-specific AMIs, 'unified' for multi-unit-type AMI. When using unified AMI, the system automatically configures the correct unit type."
  type        = string
  default     = "legacy"
}

variable "aggregator_ami_id" {
  description = "AMI ID of the Guardium Aggregator image."
  type        = string
}

variable "aggregator_count" {
  description = "Number of Guardium Aggregator instances to deploy."
  type        = number
}

variable "aggregator_instance_type" {
  description = "Instance type for the Guardium Aggregator (e.g., m6i.2xlarge)."
  type        = string
}

variable "assign_public_ip" {
  description = "If true, assign a public IP to the Guardium Aggregator instance. Set to false for private-only deployments (no Internet exposure)."
  type        = bool
  default     = true
}

# =====================================================
# Shared Secret (for Central Manager registration)
# =====================================================

variable "shared_secret" {
  description = "Shared secret used to register this Aggregator with the Central Manager. Must match the Central Manager's shared secret."
  type        = string
  default     = ""
}

variable "central_manager_ip" {
  description = "IP address of the Central Manager to register with."
  type        = string
  default     = ""
}

# =====================================================
# Cloud-Init (optional)
# =====================================================

variable "user_data_file" {
  description = "Path to a Cloud-Init user-data file (e.g. #cloud-config YAML). Relative to this directory. Leave empty to omit."
  type        = string
  default     = ""
}

variable "iam_instance_profile" {
  description = "IAM instance profile name or ARN to attach to the aggregator instance for AWS service access"
  type        = string
  default     = null
}

# =====================================================
# GDP License Keys (optional)
# =====================================================

variable "license_base" {
  description = "GDP Base license key for automated installation. Leave empty to skip."
  type        = string
  default     = ""
}

variable "license_append" {
  description = "GDP Append Trial license key for automated installation. Leave empty to skip."
  type        = string
  default     = ""
}

# =====================================================
# DNS, Domain & Timezone
# =====================================================

variable "resolver1" {
  description = "Primary DNS resolver."
  type        = string
}

variable "resolver2" {
  description = "Secondary DNS resolver."
  type        = string
}

variable "domain" {
  description = "Domain name for the Guardium instance."
  type        = string
}

variable "timezone" {
  description = "Timezone for Guardium system configuration (e.g., America/New_York)."
  type        = string
}

# =====================================================
# Security Group Configuration
# =====================================================

variable "allowed_cidrs" {
  description = "Default CIDR ranges automatically allowed (internal and management networks)."
  type        = list(string)

  # These defaults are taken directly from terraform.tfvars
  default = [
    "10.0.0.0/16",
    "170.225.223.17/32"
  ]
}

variable "custom_allowed_cidrs" {
  description = "Optional extra CIDR blocks (e.g., temporary office IPs or customer-specific access). These are merged with allowed_cidrs."
  type        = list(string)
  default     = []
}

# =====================================================
# Tagging & Metadata
# =====================================================

variable "tags" {
  description = "Map of common tags to apply to all resources."
  type        = map(string)
  default     = {}
}

# =====================================================
# Optional Existing Security Group IDs
# =====================================================

variable "existing_guardium_cm_sg_id" {
  description = "Existing Guardium Central Manager Security Group ID (optional, used for cross-linking)."
  type        = string
  default     = ""
}

variable "existing_guardium_aggregator_sg_id" {
  description = "Existing Guardium Aggregator Security Group ID (optional, overrides auto-detection)."
  type        = string
  default     = ""
}

variable "existing_guardium_collector_sg_id" {
  description = "Existing Guardium Collector Security Group ID (optional, reserved for future use)."
  type        = string
  default     = ""
}

# =====================================================
# Instance Naming Configuration
# =====================================================

variable "instance_name_prefix" {
  description = "Prefix for instance name tag (e.g., 'guard-agg'). The instance number will be appended."
  type        = string
  default     = "guard-agg"
}

# =====================================================
# Root Volume Configuration
# =====================================================

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 1500
}

variable "root_volume_type" {
  description = "Type of the root EBS volume (e.g., gp3, gp2, io1, io2)"
  type        = string
  default     = "gp3"
}

variable "root_volume_delete_on_termination" {
  description = "Whether to delete the root volume when the instance is terminated."
  type        = bool
  default     = true
}

