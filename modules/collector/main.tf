#
# Copyright (c) IBM Corp. 2026
# SPDX-License-Identifier: Apache-2.0
#

# IBM Guardium GDP - Collector Module

resource "aws_instance" "collector" {
  count         = var.collector_count
  ami           = var.collector_ami_id
  instance_type = var.collector_instance_type
  subnet_id     = var.subnet_id
  vpc_security_group_ids = var.vpc_security_group_ids
  key_name      = var.key_name

  # IAM instance profile for AWS service access (e.g., CloudWatch, S3, SQS)
  iam_instance_profile = var.iam_instance_profile

  associate_public_ip_address = var.assign_public_ip
  user_data                   = local.final_user_data

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    delete_on_termination = var.root_volume_delete_on_termination
  }

  tags = merge(
    var.tags,
    {
      Name = format("%s-%02d", var.instance_name_prefix, count.index + 1)
      Role = "Collector"
    }
  )
}

data "aws_subnet" "selected" {
  id = var.subnet_id
}

locals {
  # Network configuration from subnet
  subnet_cidr   = data.aws_subnet.selected.cidr_block
  subnet_prefix = split("/", local.subnet_cidr)[1]
  subnet_mask   = cidrnetmask(local.subnet_cidr)
  gateway_ip    = cidrhost(local.subnet_cidr, 1)

  # User data processing for unified AMI
  user_data_clean = var.user_data != null && var.user_data != "" ? replace(var.user_data, "/^#cloud-config\\s*/", "") : "{}"
  user_config     = try(yamldecode(local.user_data_clean), {})
  user_guardium   = try(local.user_config.ibm.guardium, {})

  # System-enforced Guardium config (collector only needs license_accepted)
  system_guardium = {
    license_accepted = true
  }

  # Merge user and system configs (system takes precedence)
  merged_guardium = merge(local.user_guardium, local.system_guardium)
  merged_config = merge(
    local.user_config,
    {
      ibm = merge(
        try(local.user_config.ibm, {}),
        { guardium = local.merged_guardium }
      )
    }
  )

  # Final user_data: merged for unified AMI, pass-through for legacy
  unified_user_data = "#cloud-config\n${yamlencode(local.merged_config)}"
  final_user_data   = lower(var.ami_type) == "unified" ? local.unified_user_data : (
    var.user_data != null && var.user_data != "" ? var.user_data : null
  )
}

# Wait for Guardium CLI readiness after boot
resource "null_resource" "wait_for_guardium_ready" {
  depends_on = [aws_instance.collector]
  count      = var.collector_count

  provisioner "local-exec" {
    command = "${path.module}/../common/scripts/wait_for_guardium_ready.sh"

    environment = {
      GUARDIUM_INSTANCE_NAME       = aws_instance.collector[count.index].tags["Name"]
      GUARDIUM_INSTANCE_PUBLIC_IP  = aws_instance.collector[count.index].public_ip
      GUARDIUM_INSTANCE_PRIVATE_IP = aws_instance.collector[count.index].private_ip
      GUARDIUM_PEM_FILE            = var.pem_file_path
      GUARDIUM_MAX_WAIT            = var.guardium_ready_max_wait
      GUARDIUM_POLL_INTERVAL       = var.guardium_ready_poll_interval
      GUARDIUM_LOG_FILE            = var.guardium_ready_log_file
    }
  }

  triggers = {
    instance_id = aws_instance.collector[count.index].id
  }
}

# Configure Guardium via Expect automation
resource "null_resource" "configure_guardium" {
  depends_on = [null_resource.wait_for_guardium_ready]

  for_each = {
    for idx, instance in aws_instance.collector :
    instance.tags["Name"] => {
      hostname   = instance.tags["Name"]
      private_ip = instance.private_ip

      # Use private IP if no public DNS/IP
      public_dns = coalesce(instance.public_dns, instance.public_ip, instance.private_ip)
    }
  }

  provisioner "local-exec" {
    command = <<EOT
echo "============================================================"
echo "[INFO] Configuring Guardium Collector: ${each.value.hostname}"
echo "[INFO] Connection target: ${each.value.public_dns}"
/usr/bin/expect ${path.module}/configure_guardium.expect \
  "${each.value.hostname}" \
  "${each.value.private_ip}" \
  "${each.value.public_dns}" \
  "${var.pem_file_path}" \
  "${local.subnet_prefix}" \
  "${local.gateway_ip}" \
  "${var.resolver1}" \
  "${var.domain}" \
  "${var.resolver2}" \
  "${var.timezone}" \
  "${var.shared_secret}" \
  "${var.central_manager_ip}" \
  "${var.license_base}" \
  "${var.license_append}"
echo "[INFO] Collector configuration complete for ${each.value.hostname}"
echo "============================================================"
EOT
  }
}

output "collector_public_ips" {
  description = "Public IPs of Guardium Collector instances (if any)"
  value       = [for i in aws_instance.collector : try(i.public_ip, null)]
}

output "collector_private_ips" {
  description = "Private IPs of Guardium Collector instances"
  value       = [for i in aws_instance.collector : i.private_ip]
}

