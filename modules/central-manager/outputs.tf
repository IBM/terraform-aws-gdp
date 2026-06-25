#
# Copyright (c) IBM Corp. 2026
# SPDX-License-Identifier: Apache-2.0
#

##############################################
# Outputs - Guardium Central Manager module #
##############################################

# =====================================================
# Instance Network Information
# =====================================================

output "private_ip" {
  description = "Private IP address(es) of the Guardium Central Manager instance(s)"
  value = [
    for cm in aws_instance.central_manager : cm.private_ip
  ]
}

output "public_ip" {
  description = "Public IP address(es) of the Guardium Central Manager instance(s)"
  value = [
    for cm in aws_instance.central_manager : try(cm.public_ip, null)
  ]
}

output "instance_ip" {
  description = "Primary IP for each instance (public if available, otherwise private)"
  value = [
    for cm in aws_instance.central_manager :
    coalesce(try(cm.public_ip, null), cm.private_ip)
  ]
}

# =====================================================
# Instance Metadata
# =====================================================

output "instance_id" {
  description = "Instance ID(s) of the Guardium Central Manager"
  value = [
    for cm in aws_instance.central_manager : cm.id
  ]
}

output "instance_name" {
  description = "Instance Name tag(s) of the Guardium Central Manager"
  value = [
    for cm in aws_instance.central_manager : cm.tags["Name"]
  ]
}

# =====================================================
# Guardium Configuration Context
# =====================================================

output "resolver1" {
  description = "Primary DNS resolver configured for the Guardium Central Manager"
  value       = var.resolver1
}

output "resolver2" {
  description = "Secondary DNS resolver configured for the Guardium Central Manager"
  value       = var.resolver2
}

output "domain" {
  description = "Domain configuration for the Guardium Central Manager"
  value       = var.domain
}

output "timezone" {
  description = "Timezone configuration for the Guardium Central Manager"
  value       = var.timezone
}
