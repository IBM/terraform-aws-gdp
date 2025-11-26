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

variable "tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "assign_public_ip" {
  description = "If true, instance receives a public IP. Set to false for private-only deployments."
  type        = bool
}

