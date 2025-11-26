##############################################
# Outputs - IBM Guardium GDP Collector Module
##############################################

# =====================================================
# Instance Network Information
# =====================================================

output "private_ip" {
  description = "Private IP address(es) of the Guardium Collector instance(s)"
  value = [
    for i in aws_instance.collector : i.private_ip
  ]
}

output "public_ip" {
  description = "Public IP address(es) of the Guardium Collector instance(s)"
  value = [
    for i in aws_instance.collector : try(i.public_ip, null)
  ]
}

output "instance_ip" {
  description = "Primary IP for each instance (public if available, otherwise private)"
  value = [
    for i in aws_instance.collector :
    coalesce(try(i.public_ip, null), i.private_ip)
  ]
}

# =====================================================
# Instance Metadata
# =====================================================

output "instance_id" {
  description = "Instance ID(s) of the Guardium Collector"
  value = [
    for i in aws_instance.collector : i.id
  ]
}

output "instance_name" {
  description = "Instance Name tag(s) of the Guardium Collector"
  value = [
    for i in aws_instance.collector : i.tags["Name"]
  ]
}

# =====================================================
# Guardium Configuration Context
# =====================================================

output "resolver1" {
  description = "Primary DNS resolver configured for the Guardium Collector"
  value       = var.resolver1
}

output "resolver2" {
  description = "Secondary DNS resolver configured for the Guardium Collector"
  value       = var.resolver2
}

output "domain" {
  description = "Domain configuration for the Guardium Collector"
  value       = var.domain
}

output "timezone" {
  description = "Timezone configuration for the Guardium Collector"
  value       = var.timezone
}

