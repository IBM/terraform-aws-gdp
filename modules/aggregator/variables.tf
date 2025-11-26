###########################################
# Aggregator Module - Input Variables #
###########################################

variable "region" {
  description = "AWS region for the Guardium deployment"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where Guardium Aggregator will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for Guardium Aggregator instance"
  type        = string
}

variable "vpc_security_group_ids" {
  description = "List of security group IDs to associate with the Guardium Aggregator instance"
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

variable "aggregator_ami_id" {
  description = "AMI ID for Guardium Aggregator"
  type        = string
}

variable "aggregator_instance_type" {
  description = "Instance type for Guardium Aggregator"
  type        = string
}

variable "aggregator_count" {
  description = "Number of Guardium Aggregator instances to deploy"
  type        = number
}

variable "resolver1" {
  description = "DNS resolver for Guardium Aggregator configuration"
  type        = string
}

variable "resolver2" {
  description = "Secondary DNS resolver for Guardium Aggregator configuration"
  type        = string
}

variable "domain" {
  description = "Domain name for Guardium Aggregator configuration"
  type        = string
}

variable "timezone" {
  description = "Set TimeZone for Guardium Aggregator configuration"
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

