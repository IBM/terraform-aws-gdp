##############################################
# IBM Guardium GDP - Collector Variables
##############################################

variable "region" {
  description = "AWS region for deployment"
  type        = string
}

variable "vpc_id" {
  description = "Existing VPC ID shared with Central Manager & Aggregator"
  type        = string
}

variable "subnet_id" {
  description = "Existing Subnet ID (optional). Leave empty to auto-create a new subnet."
  type        = string
  default     = null
}

variable "enable_auto_vpc" {
  description = "If true, Terraform will automatically create a new VPC, subnet, route table, and IGW when vpc_id/subnet_id are not provided."
  type        = bool
  default     = false
}


variable "key_name" {
  description = "AWS key pair for SSH access"
  type        = string
}

variable "pem_file_path" {
  description = "Path to PEM file for SSH automation"
  type        = string
}

variable "collector_ami_id" {
  description = "AMI ID for Guardium Collector"
  type        = string
}

variable "collector_instance_type" {
  description = "Instance type for Guardium Collector (e.g., m6i.xlarge)"
  type        = string
}

variable "collector_count" {
  description = "Number of Guardium Collector instances to deploy"
  type        = number
}

variable "assign_public_ip" {
  description = "Assign public IP for Guardium Collector"
  type        = bool
  default     = true
}

variable "resolver1" {
  description = "Primary DNS resolver"
  type        = string
}

variable "resolver2" {
  description = "Secondary DNS resolver"
  type        = string
}

variable "domain" {
  description = "Domain for Guardium Collector instance"
  type        = string
}

variable "timezone" {
  description = "Timezone for Guardium system"
  type        = string
}

variable "allowed_cidrs" {
  description = "Base allowed CIDR ranges (same as terraform.tfvars)"
  type        = list(string)
  default = [
    "10.0.0.0/16",
    "170.225.223.17/32"
  ]
}

variable "custom_allowed_cidrs" {
  description = "Optional additional CIDRs to merge with allowed_cidrs"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common resource tags"
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

