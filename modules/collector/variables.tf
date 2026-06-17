#
# Copyright (c) IBM Corp. 2026
# SPDX-License-Identifier: Apache-2.0
#

###########################################
# Collector Module - Input Variables #
###########################################

variable "region" {
  description = "AWS region for the Guardium deployment"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where Guardium Collector will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for Guardium Collector instance"
  type        = string
}

variable "vpc_security_group_ids" {
  description = "List of security group IDs to associate with the Guardium Collector instance"
  type        = list(string)
}

variable "key_name" {
  description = "AWS EC2 key pair name used for SSH access"
  type        = string
}

variable "pem_file_path" {
  description = "Path to the local PEM key for SSH automation"
  type        = string
}

variable "ami_type" {
  description = "AMI type: 'legacy' for unit-type-specific AMIs, 'unified' for multi-unit-type AMIs. When using unified AMI, the system automatically configures the correct unit type."
  type        = string
  default     = "legacy"

  validation {
    condition     = contains(["legacy", "unified"], var.ami_type)
    error_message = "ami_type must be 'legacy' or 'unified'."
  }
}

variable "collector_ami_id" {
  description = "AMI ID for Guardium Collector"
  type        = string
}

variable "collector_instance_type" {
  description = "Instance type for Guardium Collector"
  type        = string
}

variable "collector_count" {
  description = "Number of Guardium Collector instances to deploy"
  type        = number
}

variable "resolver1" {
  description = "Primary DNS resolver for Guardium Collector configuration"
  type        = string
}

variable "resolver2" {
  description = "Secondary DNS resolver for Guardium Collector configuration"
  type        = string
}

variable "domain" {
  description = "Domain name for Guardium Collector configuration"
  type        = string
}

variable "timezone" {
  description = "Set TimeZone for Guardium Collector configuration"
  type        = string
}

variable "shared_secret" {
  description = "Shared secret for registering this Collector with the Central Manager"
  type        = string
  default     = ""
}

variable "central_manager_ip" {
  description = "IP address of the Central Manager to register with"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "assign_public_ip" {
  description = "If true, instance receives a public IP. Set to false for private-only deployments."
  type        = bool
}

variable "user_data" {
  description = "Cloud-Init user data (e.g. #cloud-config YAML). Optional; leave null to omit."
  type        = string
  default     = null
}

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

variable "iam_instance_profile" {
  description = "IAM instance profile name or ARN to attach to the collector instance for AWS service access"
  type        = string
  default     = null
}

###########################################
# Guardium Readiness Polling Configuration
###########################################

variable "guardium_ready_max_wait" {
  description = "Maximum time in seconds to wait for Guardium CLI to become ready (default: 1200 = 20 minutes)"
  type        = number
  default     = 1200

  validation {
    condition     = var.guardium_ready_max_wait >= 60
    error_message = "guardium_ready_max_wait must be at least 60 seconds"
  }
}

variable "guardium_ready_poll_interval" {
  description = "Interval in seconds between Guardium CLI readiness checks (default: 30)"
  type        = number
  default     = 30

  validation {
    condition     = var.guardium_ready_poll_interval >= 10 && var.guardium_ready_poll_interval <= 300
    error_message = "guardium_ready_poll_interval must be between 10 and 300 seconds"
  }
}

variable "guardium_ready_log_file" {
  description = "Path to log file for Guardium readiness polling. If empty, logs to stdout only."
  type        = string
  default     = ""
}

###########################################
# Instance Naming Configuration
###########################################

variable "instance_name_prefix" {
  description = "Prefix for instance name tag (e.g., 'guard-col'). The instance number will be appended."
  type        = string
  default     = "guard-col"
}

###########################################
# Root Volume Configuration
###########################################

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 550

  validation {
    condition     = var.root_volume_size >= 550
    error_message = "root_volume_size must be at least 550 GB for Guardium Collector."
  }
}

variable "root_volume_type" {
  description = "Type of the root EBS volume (e.g., gp3, gp2, io1, io2)"
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.root_volume_type)
    error_message = "root_volume_type must be one of: gp2, gp3, io1, io2"
  }
}

variable "root_volume_delete_on_termination" {
  description = "Whether to delete the root volume when the instance is terminated."
  type        = bool
  default     = true
}
