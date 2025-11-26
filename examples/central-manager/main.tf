##############################################
# IBM Guardium GDP - Central Manager Example #
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
  final_subnet_id = coalesce(var.subnet_id, try(module.auto_vpc[0].subnet_cm_id, null))
}

# =====================================================
# 2️⃣ Create Security Group (or reuse existing)
# =====================================================
resource "aws_security_group" "guardium_cm_sg" {
  count = var.existing_guardium_cm_sg_id != "" ? 0 : 1

  name        = "guardium-cm-sg"
  description = "Security group for Guardium Central Manager"
  vpc_id      = local.final_vpc_id

  # --- Ingress rules for Guardium ports ---
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

  # --- Allow all outbound traffic ---
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "guardium-cm-sg"
    Role = "CentralManager"
  })
}

# =====================================================
# 3️⃣ Deploy Guardium Central Manager module
# =====================================================
module "guardium_central_manager" {
  source = "../../modules/central-manager"

  region                 = var.region
  vpc_id                 = local.final_vpc_id
  subnet_id              = local.final_subnet_id
  vpc_security_group_ids = (
    var.existing_guardium_cm_sg_id != "" ?
    [var.existing_guardium_cm_sg_id] :
    [aws_security_group.guardium_cm_sg[0].id]
  )

  key_name      = var.key_name
  pem_file_path = var.pem_file_path

  central_manager_count         = var.central_manager_count
  central_manager_ami_id        = var.central_manager_ami_id
  central_manager_instance_type = var.central_manager_instance_type

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
  description = "The security group ID in use for Guardium CM"
  value = (
    var.existing_guardium_cm_sg_id != "" ?
    var.existing_guardium_cm_sg_id :
    aws_security_group.guardium_cm_sg[0].id
  )
}

# -----------------------------------------------------
# Guardium Central Manager Instance Details
# -----------------------------------------------------

output "guardium_cm_public_ip" {
  description = "Public IP address(es) of the Guardium Central Manager instance(s)"
  value       = try(flatten([module.guardium_central_manager.public_ip]), [])
}

output "guardium_cm_private_ip" {
  description = "Private IP address(es) of the Guardium Central Manager instance(s)"
  value       = try(flatten([module.guardium_central_manager.private_ip]), [])
}

output "guardium_cm_instance_ip" {
  description = "Primary instance IP (public if available, else private)"
  value = (
    length(try(flatten([module.guardium_central_manager.public_ip]), [])) > 0 ?
    flatten([module.guardium_central_manager.public_ip]) :
    flatten([module.guardium_central_manager.private_ip])
  )
}

output "guardium_cm_resolver1" {
  description = "Primary DNS resolver"
  value       = var.resolver1
}

output "guardium_cm_resolver2" {
  description = "Secondary DNS resolver"
  value       = var.resolver2
}

output "guardium_cm_domain" {
  description = "Domain configuration"
  value       = var.domain
}

output "guardium_cm_timezone" {
  description = "Timezone configuration"
  value       = var.timezone
}

