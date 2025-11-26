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
# 3️⃣ Create new SG (safe: always create unless user provided one)
# =====================================================
resource "aws_security_group" "guardium_agg_sg" {
  count = var.existing_guardium_aggregator_sg_id != "" ? 0 : 1

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

  aggregator_count         = var.aggregator_count
  aggregator_ami_id        = var.aggregator_ami_id
  aggregator_instance_type = var.aggregator_instance_type

  resolver1        = var.resolver1
  resolver2        = var.resolver2
  domain           = var.domain
  timezone         = var.timezone
  tags             = var.tags
  assign_public_ip = var.assign_public_ip
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

