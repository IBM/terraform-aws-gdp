#############################################
# Outputs - Guardium Aggregator module
#############################################

# Return instance IPs and details for each aggregator

output "private_ip" {
  description = "Private IP address(es) of the Guardium Aggregator instance(s)"
  value = [
    for agg in aws_instance.aggregator : agg.private_ip
  ]
}

output "public_ip" {
  description = "Public IP address(es) of the Guardium Aggregator instance(s)"
  value = [
    for agg in aws_instance.aggregator : agg.public_ip
  ]
}

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

