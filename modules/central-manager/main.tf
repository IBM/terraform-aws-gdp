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

# Wait for Guardium boot (20 min)
resource "null_resource" "wait_for_guardium_ready" {
  depends_on = [aws_instance.central_manager]

  provisioner "local-exec" {
    command = <<EOT
echo "[INFO] Waiting 20 minutes for Guardium Central Manager initialization..."
sleep 1200
EOT
  }
}

# =====================================================
# Configure Guardium using Expect Automation
# =====================================================
resource "null_resource" "configure_guardium" {
  depends_on = [null_resource.wait_for_guardium_ready]

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
  "${var.timezone}"

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

