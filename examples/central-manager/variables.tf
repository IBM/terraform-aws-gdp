##############################################
# IBM Guardium GDP - Central Manager Variables
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

variable "central_manager_ami_id" {
  description = "AMI ID of the Guardium Central Manager image."
  type        = string
}

variable "central_manager_count" {
  description = "Number of Guardium Central Manager instances to deploy."
  type        = number
  default     = 1
}

variable "central_manager_instance_type" {
  description = "Instance type for the Guardium Central Manager (e.g., m6i.2xlarge)."
  type        = string
}

variable "assign_public_ip" {
  description = "If true, assign a public IP to the Guardium Central Manager instance. Set to false for private-only deployments (no Internet exposure)."
  type        = bool
  default     = true
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
  description = "Existing Guardium Central Manager Security Group ID (optional, overrides auto-detection)."
  type        = string
  default     = ""
}

variable "existing_guardium_aggregator_sg_id" {
  description = "Existing Guardium Aggregator Security Group ID (optional, reserved for future cross-linking)."
  type        = string
  default     = ""
}

variable "existing_guardium_collector_sg_id" {
  description = "Existing Guardium Collector Security Group ID (optional, reserved for future cross-linking)."
  type        = string
  default     = ""
}

