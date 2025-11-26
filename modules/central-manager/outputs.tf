#############################################
# Outputs - Guardium Central Manager module #
#############################################

# If you create multiple instances, this will return lists.

output "private_ip" {
  description = "Private IP address(es) of the Guardium Central Manager instance(s)"
  value = [
    for cm in aws_instance.central_manager : cm.private_ip
  ]
}

output "public_ip" {
  description = "Public IP address(es) of the Guardium Central Manager instance(s)"
  value = [
    for cm in aws_instance.central_manager : cm.public_ip
  ]
}

output "instance_id" {
  description = "Instance ID(s) of the Guardium Central Manager"
  value = [
    for cm in aws_instance.central_manager : cm.id
  ]
}

output "instance_name" {
  description = "Instance name tag(s)"
  value = [
    for cm in aws_instance.central_manager : cm.tags["Name"]
  ]
}

