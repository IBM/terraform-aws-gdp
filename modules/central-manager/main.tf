##############################################
# IBM Guardium GDP - Central Manager Module
##############################################

resource "aws_instance" "central_manager" {
  count         = var.central_manager_count
  ami           = var.central_manager_ami_id
  instance_type = var.central_manager_instance_type
  subnet_id     = var.subnet_id
  vpc_security_group_ids = var.vpc_security_group_ids
  key_name      = var.key_name

  associate_public_ip_address = var.assign_public_ip
  user_data                   = var.user_data != null && var.user_data != "" ? var.user_data : null

  root_block_device {
    volume_size           = 1500
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = merge(
    var.tags,
    {
      Name = format("guard-cm-%02d", count.index + 1)
      Role = "CentralManager"
    }
  )
}

data "aws_subnet" "selected" {
  id = var.subnet_id
}

locals {
  subnet_cidr = data.aws_subnet.selected.cidr_block
  subnet_mask = cidrnetmask(local.subnet_cidr)
  gateway_ip  = cidrhost(local.subnet_cidr, 1)
}

# Wait for initial boot to stabilize before reboot
resource "time_sleep" "wait_before_reboot" {
  depends_on = [aws_instance.central_manager]
  count      = var.central_manager_count

  create_duration = "5m"

  triggers = {
    instance_id = aws_instance.central_manager[count.index].id
  }
}

# Reboot Central Manager instance (required for proper initialization)
resource "aws_ec2_instance_state" "reboot_cm" {
  count       = var.central_manager_count
  instance_id = aws_instance.central_manager[count.index].id
  state       = "running"
  force       = true

  depends_on = [time_sleep.wait_before_reboot]
}

# Wait for instance to stabilize after reboot
resource "time_sleep" "wait_after_reboot" {
  depends_on = [aws_ec2_instance_state.reboot_cm]
  count      = var.central_manager_count

  create_duration = "3m"

  triggers = {
    instance_id = aws_instance.central_manager[count.index].id
  }
}

# Monitor instance status checks
data "aws_instance" "cm_status" {
  count       = var.central_manager_count
  instance_id = aws_instance.central_manager[count.index].id

  depends_on = [time_sleep.wait_after_reboot]
}

# Wait for Guardium initialization after status checks pass
resource "time_sleep" "wait_for_guardium_init" {
  depends_on = [data.aws_instance.cm_status]
  count      = var.central_manager_count

  create_duration = "10m"

  triggers = {
    instance_id   = aws_instance.central_manager[count.index].id
    instance_state = data.aws_instance.cm_status[count.index].instance_state
  }
}

# =====================================================
# Configure Guardium using Expect Automation
# =====================================================
resource "null_resource" "configure_guardium" {
  depends_on = [time_sleep.wait_for_guardium_init]

  for_each = {
    for idx, instance in aws_instance.central_manager :
    instance.tags["Name"] => {
      hostname   = instance.tags["Name"]
      private_ip = instance.private_ip
      # fallback: prefer Public DNS > Public IP > Private IP
      public_dns = coalesce(instance.public_dns, instance.public_ip, instance.private_ip)
    }
  }

  provisioner "local-exec" {
    command = <<EOT
echo "============================================================"
echo "[INFO] Starting Guardium configuration for: ${each.value.hostname}"
echo "[INFO] Connection target: ${each.value.public_dns}"
/usr/bin/expect ${path.module}/configure_guardium.expect \
  "${each.value.hostname}" \
  "${each.value.private_ip}" \
  "${each.value.public_dns}" \
  "${var.pem_file_path}" \
  "${local.subnet_mask}" \
  "${local.gateway_ip}" \
  "${var.resolver1}" \
  "${var.domain}" \
  "${var.resolver2}" \
  "${var.timezone}" \
  "${var.shared_secret}" \
  "${var.license_base}" \
  "${var.license_append}"

echo "[INFO] Completed configuration for ${each.value.hostname}"
echo "============================================================"
EOT
  }
}

output "central_manager_public_ips" {
  value       = [for i in aws_instance.central_manager : try(i.public_ip, null)]
}

output "central_manager_private_ips" {
  value       = [for i in aws_instance.central_manager : i.private_ip]
}

