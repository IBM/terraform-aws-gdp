#
# Copyright (c) IBM Corp. 2026
# SPDX-License-Identifier: Apache-2.0
#

#############################################
# Outputs - Guardium Aggregator module
#############################################

# =====================================================
# Instance Network Information
# =====================================================

output "private_ip" {
  description = "Private IP address(es) of the Guardium Aggregator instance(s)"
  value = [
    for agg in aws_instance.aggregator : agg.private_ip
  ]
}

output "public_ip" {
  description = "Public IP address(es) of the Guardium Aggregator instance(s)"
  value = [
    for agg in aws_instance.aggregator : try(agg.public_ip, null)
  ]
}

output "instance_ip" {
  description = "Primary IP for each instance (public if available, otherwise private)"
  value = [
    for agg in aws_instance.aggregator :
    coalesce(try(agg.public_ip, null), agg.private_ip)
  ]
}

# =====================================================
# Instance Metadata
# =====================================================

output "instance_id" {
  description = "Instance ID(s) of the Guardium Aggregator"
  value = [
    for agg in aws_instance.aggregator : agg.id
  ]
}

output "instance_name" {
  description = "Instance Name tag(s) of the Guardium Aggregator"
  value = [
    for agg in aws_instance.aggregator : agg.tags["Name"]
  ]
}

# =====================================================
# Guardium Configuration Context
# =====================================================

output "resolver1" {
  description = "Primary DNS resolver configured for the Guardium Aggregator"
  value       = var.resolver1
}

output "resolver2" {
  description = "Secondary DNS resolver configured for the Guardium Aggregator"
  value       = var.resolver2
}

output "domain" {
  description = "Domain configuration for the Guardium Aggregator"
  value       = var.domain
}

output "timezone" {
  description = "Timezone configuration for the Guardium Aggregator"
  value       = var.timezone
}
