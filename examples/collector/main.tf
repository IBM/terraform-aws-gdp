##############################################
# IBM Guardium GDP - Collector Example
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
  final_subnet_id = coalesce(var.subnet_id, try(module.auto_vpc[0].subnet_col_id, null))
}

# =====================================================
# 2️⃣ Detect or create Guardium Collector Security Group
# =====================================================
data "aws_security_groups" "guardium_col_existing" {
  count = local.final_vpc_id != null ? 1 : 0

  filter {
    name   = "group-name"
    values = ["guardium-col-sg"]
  }

  filter {
    name   = "vpc-id"
    values = [local.final_vpc_id]
  }
}

locals {
  sg_exists = length(try(data.aws_security_groups.guardium_col_existing[0].ids, [])) > 0
}

resource "aws_security_group" "guardium_col_sg" {
  count = (
    var.existing_guardium_collector_sg_id != "" ? 0 :
    local.sg_exists ? 0 : 1
  )

  name        = "guardium-col-sg"
  description = "Security group for Guardium Collector"
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
    Name = "guardium-col-sg"
    Role = "Collector"
  })
}

# =====================================================
# 3️⃣ Deploy the Guardium Collector module
# =====================================================
module "guardium_collector" {
  source = "../../modules/collector"

  region                 = var.region
  vpc_id                 = local.final_vpc_id
  subnet_id              = local.final_subnet_id
  vpc_security_group_ids = (
    var.existing_guardium_collector_sg_id != "" ? [var.existing_guardium_collector_sg_id] :
    local.sg_exists ? data.aws_security_groups.guardium_col_existing[0].ids :
    [aws_security_group.guardium_col_sg[0].id]
  )

  key_name      = var.key_name
  pem_file_path = var.pem_file_path

  collector_count         = var.collector_count
  collector_ami_id        = var.collector_ami_id
  collector_instance_type = var.collector_instance_type

  resolver1        = var.resolver1
  resolver2        = var.resolver2
  domain           = var.domain
  timezone         = var.timezone
  tags             = var.tags
  assign_public_ip = var.assign_public_ip
}

# =====================================================
# 4️⃣ Outputs (Extended - Safe and Multi-Instance Compatible)
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
  description = "Security group ID in use for Guardium Collector"
  value = (
    var.existing_guardium_collector_sg_id != "" ? var.existing_guardium_collector_sg_id :
    local.sg_exists ? data.aws_security_groups.guardium_col_existing[0].ids[0] :
    aws_security_group.guardium_col_sg[0].id
  )
}

# -----------------------------------------------------
# Guardium Collector Instance Details
# -----------------------------------------------------
output "guardium_col_public_ip" {
  value       = try(flatten([module.guardium_collector.public_ip]), [])
  description = "Public IP(s) of Guardium Collector instance(s)"
}

output "guardium_col_private_ip" {
  value       = try(flatten([module.guardium_collector.private_ip]), [])
  description = "Private IP(s) of Guardium Collector instance(s)"
}

output "guardium_col_instance_ip" {
  value = (
    length(try(flatten([module.guardium_collector.public_ip]), [])) > 0
    ? flatten([module.guardium_collector.public_ip])
    : flatten([module.guardium_collector.private_ip])
  )
  description = "Primary instance IP(s) for Guardium Collector"
}

output "guardium_col_resolver1" {
  value       = var.resolver1
  description = "Primary DNS resolver"
}

output "guardium_col_resolver2" {
  value       = var.resolver2
  description = "Secondary DNS resolver"
}

output "guardium_col_domain" {
  value       = var.domain
  description = "Configured domain"
}

output "guardium_col_timezone" {
  value       = var.timezone
  description = "Configured timezone"
}

