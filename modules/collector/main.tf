##############################################
# IBM Guardium GDP - Collector Module
##############################################

# =====================================================
# EC2 Instance
# =====================================================
resource "aws_instance" "collector" {
  count         = var.collector_count
  ami           = var.collector_ami_id
  instance_type = var.collector_instance_type
  subnet_id     = var.subnet_id
  vpc_security_group_ids = var.vpc_security_group_ids
  key_name      = var.key_name

  # Allow public IP only if explicitly configured
  associate_public_ip_address = var.assign_public_ip

  root_block_device {
    volume_size           = 550
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = merge(
    var.tags,
    {
      Name = format("guard-col-%02d", count.index + 1)
      Role = "Collector"
    }
  )
}

# =====================================================
# Subnet and Network Info
# =====================================================
data "aws_subnet" "selected" {
  id = var.subnet_id
}

locals {
  subnet_cidr = data.aws_subnet.selected.cidr_block
  subnet_mask = cidrnetmask(local.subnet_cidr)
  gateway_ip  = cidrhost(local.subnet_cidr, 1)
}

# =====================================================
# Wait for Guardium boot (~20 min)
# =====================================================
resource "null_resource" "wait_for_guardium_ready" {
  depends_on = [aws_instance.collector]

  provisioner "local-exec" {
    command = <<EOT
echo "[INFO] Waiting 20 minutes for Guardium Collector to initialize..."
sleep 1200
EOT
  }
}

# =====================================================
# Configure Guardium via Expect
# =====================================================
resource "null_resource" "configure_guardium" {
  depends_on = [null_resource.wait_for_guardium_ready]

  for_each = {
    for idx, instance in aws_instance.collector :
    instance.tags["Name"] => {
      hostname   = instance.tags["Name"]
      private_ip = instance.private_ip

      #  Auto-fallback logic:
      # If instance has no public DNS or IP, fallback to private IP automatically.
      public_dns = coalesce(instance.public_dns, instance.public_ip, instance.private_ip)
    }
  }

  provisioner "local-exec" {
    command = <<EOT
echo "============================================================"
echo "[INFO] Configuring Guardium Collector: ${each.value.hostname}"
echo "[INFO] Connection target: ${each.value.public_dns}"
/usr/bin/expect ${path.module}/configure_guardium.expect \
  ${each.value.hostname} \
  ${each.value.private_ip} \
  ${each.value.public_dns} \
  ${var.pem_file_path} \
  ${local.subnet_mask} \
  ${local.gateway_ip} \
  ${var.resolver1} \
  ${var.domain} \
  ${var.resolver2} \
  ${var.timezone}
echo "[INFO] Collector configuration complete for ${each.value.hostname}"
echo "============================================================"
EOT
  }
}

# =====================================================
# Outputs
# =====================================================
output "collector_public_ips" {
  description = "Public IPs of Guardium Collector instances (if any)"
  value       = [for i in aws_instance.collector : try(i.public_ip, null)]
}

output "collector_private_ips" {
  description = "Private IPs of Guardium Collector instances"
  value       = [for i in aws_instance.collector : i.private_ip]
}

