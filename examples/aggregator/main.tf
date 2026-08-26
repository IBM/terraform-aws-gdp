#
# Copyright (c) IBM Corp. 2026
# SPDX-License-Identifier: Apache-2.0
#

##############################################
# IBM Guardium GDP - Aggregator Example
##############################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# =====================================================
# 1️⃣ Use shared auto_vpc module when enabled
# =====================================================
module "auto_vpc" {
  source = "../../modules/auto_vpc"
  region = var.region
  count  = var.enable_auto_vpc && var.vpc_id == null ? 1 : 0
}

locals {
  final_vpc_id    = coalesce(var.vpc_id, try(module.auto_vpc[0].vpc_id, null))
  final_subnet_id = coalesce(var.subnet_id, try(module.auto_vpc[0].subnet_agg_id, null))
  # Cloud-Init: resolve user_data_file path relative to this directory
  user_data       = var.user_data_file != "" ? file("${path.module}/${trimprefix(var.user_data_file, "./")}") : null
  # Count derived from topology — no manual variable needed
  topology             = jsondecode(file("${path.module}/../../shared-config/topology.json"))
  aggregator_count     = length(local.topology.aggregators)
  agg_instance_names   = [for agg in local.topology.aggregators : agg.instance_name]
  # Central Manager: name from topology, IP discovered from AWS
  cm_name       = local.topology.central_managers[0].instance_name
  distinct_cms  = distinct([for agg in local.topology.aggregators : agg.registration_cm])
  cm_private_ip = data.aws_instance.central_manager.private_ip
}

# Validate that all aggregators register with the same Central Manager
resource "null_resource" "validate_single_cm" {
  count = length(local.distinct_cms) == 1 ? 0 : 1

  provisioner "local-exec" {
    command = <<EOT
echo "[ERROR] All aggregators must register with the same Central Manager, but topology.json lists multiple: ${join(", ", local.distinct_cms)}" >&2
exit 1
EOT
  }
}

# =====================================================
# 1️⃣b Lookup Central Manager instance from AWS
# =====================================================
data "aws_instance" "central_manager" {
  filter {
    name   = "tag:Name"
    values = [local.cm_name]
  }
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
  filter {
    name   = "vpc-id"
    values = [local.final_vpc_id]
  }
}

# =====================================================
# 2️⃣ Lookup existing Guardium Aggregator SG
# =====================================================
data "aws_security_groups" "guardium_agg_existing" {
  count = local.final_vpc_id != null ? 1 : 0

  filter {
    name   = "group-name"
    values = ["guardium-agg-sg"]
  }

  filter {
    name   = "vpc-id"
    values = [local.final_vpc_id]
  }
}

# =====================================================
# 3️⃣ Create new SG (only if none exists)
# =====================================================
resource "aws_security_group" "guardium_agg_sg" {
  count = (
    var.existing_guardium_aggregator_sg_id != "" ? 0 :
    length(try(data.aws_security_groups.guardium_agg_existing[0].ids, [])) > 0 ? 0 : 1
  )

  name        = "guardium-agg-sg"
  description = "Security group for Guardium Aggregator"
  vpc_id      = local.final_vpc_id

  dynamic "ingress" {
    for_each = [
      { from = 22,   to = 22,   desc = "SSH access" },
      { from = 8443, to = 8443, desc = "Guardium Web Console" },
      { from = 3306, to = 3306, desc = "Database communications" },
      { from = 8447, to = 8447, desc = "Guardium patch/upgrade" },
      { from = 9983, to = 9983, desc = "Guardium replication/aggregation" },
      { from = 8445, to = 8445, desc = "Application usage and administration" },
      { from = 8983, to = 8983, desc = "Solr / indexing service" }
    ]
    content {
      from_port   = ingress.value.from
      to_port     = ingress.value.to
      protocol    = "tcp"
      cidr_blocks = concat(var.allowed_cidrs, var.custom_allowed_cidrs)
      description = ingress.value.desc
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "guardium-agg-sg"
    Role = "Aggregator"
  })
}

# When using an existing SG, ensure all Guardium ports exist for allowed_cidrs.
locals {
  agg_using_existing_sg = (
    var.existing_guardium_aggregator_sg_id != "" ? true :
    length(try(data.aws_security_groups.guardium_agg_existing[0].ids, [])) > 0
  )
  agg_existing_sg_id = (
    var.existing_guardium_aggregator_sg_id != "" ? var.existing_guardium_aggregator_sg_id :
    try(data.aws_security_groups.guardium_agg_existing[0].ids[0], null)
  )

  agg_guardium_ports = [
    { port = 22,   desc = "SSH access" },
    { port = 8443, desc = "Guardium Web Console" },
    { port = 3306, desc = "Database communications" },
    { port = 8447, desc = "Guardium patch/upgrade" },
    { port = 9983, desc = "Guardium replication/aggregation" },
    { port = 8445, desc = "Application usage and administration" },
    { port = 8983, desc = "Solr / indexing service" },
  ]

  agg_sg_rules = local.agg_using_existing_sg && local.agg_existing_sg_id != null ? {
    for pair in flatten([
      for p in local.agg_guardium_ports : [
        for cidr in concat(var.allowed_cidrs, var.custom_allowed_cidrs) : {
          key  = "${p.port}-${cidr}"
          port = p.port
          desc = p.desc
          cidr = cidr
        }
      ]
    ]) : pair.key => pair
  } : {}
}

resource "aws_security_group_rule" "guardium_agg_allowed_cidrs" {
  for_each = local.agg_sg_rules

  security_group_id = local.agg_existing_sg_id
  type              = "ingress"
  from_port         = each.value.port
  to_port           = each.value.port
  protocol          = "tcp"
  cidr_blocks       = [each.value.cidr]
  description       = each.value.desc
}

# =====================================================
# 4️⃣ Call the Aggregator Module
# =====================================================
module "guardium_aggregator" {
  source = "../../modules/aggregator"

  region                 = var.region
  vpc_id                 = local.final_vpc_id
  subnet_id              = local.final_subnet_id
  vpc_security_group_ids = (
    var.existing_guardium_aggregator_sg_id != ""
    ? [var.existing_guardium_aggregator_sg_id]
    : (
        length(try(data.aws_security_groups.guardium_agg_existing[0].ids, [])) > 0
        ? data.aws_security_groups.guardium_agg_existing[0].ids
        : [aws_security_group.guardium_agg_sg[0].id]
      )
  )

  key_name      = var.key_name
  pem_file_path = var.pem_file_path

  iam_instance_profile = var.iam_instance_profile

  aggregator_count         = local.aggregator_count
  aggregator_ami_id        = var.aggregator_ami_id
  aggregator_instance_type = var.aggregator_instance_type
  ami_type                 = var.ami_type

  resolver1           = var.resolver1
  resolver2           = var.resolver2
  domain              = var.domain
  timezone            = var.timezone
  shared_secret       = var.shared_secret
  central_manager_ip  = local.cm_private_ip
  license_base        = var.license_base
  license_append      = var.license_append
  user_data           = local.user_data
  tags                = var.tags
  assign_public_ip    = var.assign_public_ip

  # Instance naming and root volume configuration
  instance_names                    = local.agg_instance_names
  root_volume_size                  = var.root_volume_size
  root_volume_type                  = var.root_volume_type
  root_volume_delete_on_termination = var.root_volume_delete_on_termination
}

# =====================================================
# 5️⃣ Outputs (Extended - Safe and Multi-Instance Compatible)
# =====================================================
output "final_vpc_id" {
  description = "The final VPC ID used (auto-created or provided)"
  value       = local.final_vpc_id
}

output "final_subnet_id" {
  description = "The final Subnet ID used (auto-created or provided)"
  value       = local.final_subnet_id
}

output "security_group_in_use" {
  description = "Security group ID used for Guardium Aggregator"
  value = (
    var.existing_guardium_aggregator_sg_id != ""
    ? var.existing_guardium_aggregator_sg_id
    : (
        length(try(data.aws_security_groups.guardium_agg_existing[0].ids, [])) > 0
        ? data.aws_security_groups.guardium_agg_existing[0].ids[0]
        : aws_security_group.guardium_agg_sg[0].id
      )
  )
}

# -----------------------------------------------------
# Guardium Aggregator Instance Details
# -----------------------------------------------------

output "guardium_agg_public_ip" {
  description = "Public IP address(es) of the Guardium Aggregator instance(s)"
  value       = try(flatten([module.guardium_aggregator.public_ip]), [])
}

output "guardium_agg_private_ip" {
  description = "Private IP address(es) of the Guardium Aggregator instance(s)"
  value       = try(flatten([module.guardium_aggregator.private_ip]), [])
}

output "guardium_agg_instance_ip" {
  description = "Primary instance IP (public if available, else private)"
  value = (
    length(try(flatten([module.guardium_aggregator.public_ip]), [])) > 0
    ? flatten([module.guardium_aggregator.public_ip])
    : flatten([module.guardium_aggregator.private_ip])
  )
}

output "guardium_agg_resolver1" {
  description = "Primary DNS resolver for the Guardium Aggregator"
  value       = var.resolver1
}

output "guardium_agg_resolver2" {
  description = "Secondary DNS resolver for the Guardium Aggregator"
  value       = var.resolver2
}

output "guardium_agg_domain" {
  description = "Configured domain for the Guardium Aggregator"
  value       = var.domain
}

output "guardium_agg_timezone" {
  description = "Timezone configuration for the Guardium Aggregator"
  value       = var.timezone
}
