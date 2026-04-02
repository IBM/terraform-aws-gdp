# Copyright (c) IBM Corporation
# SPDX-License-Identifier: Apache-2.0

# Deploy AWS EKS
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
     guardium-data-protection = {
      source  = "IBM/guardium-data-protection"
      version = "~> 1.4.0"
    }
  }
}

provider "aws" {
  region     = var.aws_region
  profile    = var.aws_profile != "" ? var.aws_profile : null
  access_key = var.aws_access_key_id != "" ? var.aws_access_key_id : null
  secret_key = var.aws_secret_access_key != "" ? var.aws_secret_access_key : null
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC for EKS cluster
module "vpc" {
  count   = var.deploy_eks ? 1 : 0
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway        = true
  single_nat_gateway        = false
  enable_dns_hostnames      = true
  enable_dns_support        = true
  map_public_ip_on_launch   = var.node_group_subnet_type == "public"

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  )
}

# ---------------------------------------------------------------------------
# VPC Cleanup — remove AWS resources created dynamically by Kubernetes
# (ALB/NLB load balancers, NAT Gateways, security groups, orphaned ENIs)
# that are NOT tracked by Terraform and would otherwise cause
# DependencyViolation errors on VPC/subnet/IGW deletion during
# `terraform destroy`.
#
# Destroy ordering (enforced by depends_on chains):
#   module.eks destroyed  →  guardium-data-protection_aws_vpc_cleanup destroyed
#     (provider Delete() runs here, deletes orphaned resources via AWS SDK)
#   →  module.vpc destroyed  (subnets and IGW now clean)
resource "guardium-data-protection_aws_vpc_cleanup" "vpc_cleanup" {
  count             = var.deploy_eks ? 1 : 0
  vpc_id            = module.vpc[0].vpc_id
  region            = var.aws_region
  profile           = var.aws_profile
  access_key_id     = var.aws_access_key_id
  secret_access_key = var.aws_secret_access_key

  depends_on = [module.vpc]
}

# EKS Cluster
module "eks" {
  count   = var.deploy_eks ? 1 : 0
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc[0].vpc_id
  subnet_ids = module.vpc[0].private_subnets

  # Enable IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  # Cluster endpoint access
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Enable cluster creator admin permissions
  enable_cluster_creator_admin_permissions = true

  # EKS Managed Node Group
  eks_managed_node_groups = {
    (var.node_group_name) = {
      name           = var.node_group_name
      instance_types = [var.node_instance_type]
      
      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size
      desired_size = var.node_group_desired_size

      disk_size = var.node_volume_size

      # Node group subnet override: use public subnets when direct SSH from outside
      # the VPC is needed (eks_hostname_type = "public"). Public subnets have
      # map_public_ip_on_launch = true so each node gets a routable public IP.
      subnet_ids = var.node_group_subnet_type == "public" ? module.vpc[0].public_subnets : module.vpc[0].private_subnets

      # Enable SSH access
      key_name = var.ssh_key_name

      # Additional security group rules
      vpc_security_group_ids = [aws_security_group.node_group_ssh[0].id]

      tags = var.tags
    }
  }

  # Cluster addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  tags = var.tags

  # Ensures that during `terraform destroy`, module.eks is torn down BEFORE
  # guardium-data-protection_aws_vpc_cleanup runs (which deletes orphaned
  # LBs/ENIs), which in turn runs BEFORE module.vpc is destroyed.
  depends_on = [guardium-data-protection_aws_vpc_cleanup.vpc_cleanup]
}

# Security group for SSH access to nodes
resource "aws_security_group" "node_group_ssh" {
  count       = var.deploy_eks ? 1 : 0
  name_prefix = "${var.cluster_name}-node-ssh-"
  vpc_id      = module.vpc[0].vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidr_blocks
    description = "Allow SSH access to nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-node-ssh"
    }
  )
}

# IAM role for EBS CSI driver
module "ebs_csi_irsa_role" {
  count   = var.deploy_eks ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-ebs-csi-controller"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks[0].oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = var.tags
}

# IAM role for EFS CSI driver
module "efs_csi_irsa_role" {
  count   = var.deploy_eks ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-efs-csi-controller"

  attach_efs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks[0].oidc_provider_arn
      namespace_service_accounts = ["kube-system:efs-csi-controller-sa"]
    }
  }

  tags = var.tags
}

# EBS CSI Driver addon
resource "aws_eks_addon" "ebs_csi_driver" {
  count                    = var.deploy_eks ? 1 : 0
  cluster_name             = module.eks[0].cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.ebs_csi_driver_version
  service_account_role_arn = module.ebs_csi_irsa_role[0].iam_role_arn

  depends_on = [module.eks]
}

# EFS CSI Driver addon
resource "aws_eks_addon" "efs_csi_driver" {
  count                    = var.deploy_eks ? 1 : 0
  cluster_name             = module.eks[0].cluster_name
  addon_name               = "aws-efs-csi-driver"
  addon_version            = var.efs_csi_driver_version
  service_account_role_arn = module.efs_csi_irsa_role[0].iam_role_arn

  depends_on = [module.eks]
}

# EFS File System
resource "aws_efs_file_system" "eks_efs" {
  count = var.deploy_eks && var.create_efs ? 1 : 0

  creation_token = "${var.cluster_name}-efs"
  encrypted      = true

  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-efs"
    }
  )
}

# EFS Mount Targets
resource "aws_efs_mount_target" "eks_efs" {
  count = var.deploy_eks && var.create_efs ? length(module.vpc[0].private_subnets) : 0

  file_system_id  = aws_efs_file_system.eks_efs[0].id
  subnet_id       = module.vpc[0].private_subnets[count.index]
  security_groups = [aws_security_group.efs[0].id]
}

# Security group for EFS
resource "aws_security_group" "efs" {
  count = var.deploy_eks && var.create_efs ? 1 : 0

  name_prefix = "${var.cluster_name}-efs-"
  vpc_id      = module.vpc[0].vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow NFS traffic from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-efs"
    }
  )
}

# Get cluster auth token via AWS provider (Go SDK - no AWS CLI required)
# depends_on forces evaluation during apply (after EKS is created) instead of
# during planning, which would generate a token that expires before it's used.
data "aws_eks_cluster_auth" "cluster" {
  count      = var.deploy_eks ? 1 : 0
  name       = module.eks[0].cluster_name
  depends_on = [module.eks]
}

# Fallback: look up existing cluster when deploy_eks = false
# This allows the kubernetes provider to connect for destroy operations
# and supports the "use existing cluster" workflow.
data "aws_eks_cluster" "existing" {
  count = var.deploy_eks ? 0 : 1
  name  = var.cluster_name
}

data "aws_eks_cluster_auth" "existing" {
  count = var.deploy_eks ? 0 : 1
  name  = var.cluster_name
}

provider "kubernetes" {
  host                   = var.deploy_eks ? module.eks[0].cluster_endpoint : data.aws_eks_cluster.existing[0].endpoint
  cluster_ca_certificate = var.deploy_eks ? base64decode(module.eks[0].cluster_certificate_authority_data) : base64decode(data.aws_eks_cluster.existing[0].certificate_authority[0].data)
  token                  = var.deploy_eks ? data.aws_eks_cluster_auth.cluster[0].token : data.aws_eks_cluster_auth.existing[0].token
}

# kubectl provider: skips plan-time API validation so storage classes can be
# managed in a single apply even when the cluster is being created or replaced.
provider "kubectl" {
  host                   = var.deploy_eks ? module.eks[0].cluster_endpoint : data.aws_eks_cluster.existing[0].endpoint
  cluster_ca_certificate = var.deploy_eks ? base64decode(module.eks[0].cluster_certificate_authority_data) : base64decode(data.aws_eks_cluster.existing[0].certificate_authority[0].data)
  token                  = var.deploy_eks ? data.aws_eks_cluster_auth.cluster[0].token : data.aws_eks_cluster_auth.existing[0].token
  load_config_file       = false
}

# Generate kubeconfig via Go SDK (no AWS CLI or kubectl required)
locals {
  kubeconfig_content = var.deploy_eks ? yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = module.eks[0].cluster_name
    clusters = [{
      name = module.eks[0].cluster_name
      cluster = {
        server                     = module.eks[0].cluster_endpoint
        certificate-authority-data = module.eks[0].cluster_certificate_authority_data
      }
    }]
    contexts = [{
      name = module.eks[0].cluster_name
      context = {
        cluster = module.eks[0].cluster_name
        user    = module.eks[0].cluster_name
      }
    }]
    users = [{
      name = module.eks[0].cluster_name
      user = {
        token = data.aws_eks_cluster_auth.cluster[0].token
      }
    }]
  }) : null
}

resource "local_file" "kubeconfig" {
  count    = var.deploy_eks ? 1 : 0
  content  = local.kubeconfig_content
  filename = "${path.root}/kubeconfig_${module.eks[0].cluster_name}"

  file_permission = "0600"
}

# Apply EBS StorageClass via kubectl_manifest so the kubectl provider's
# load_config_file=false behaviour is used — this skips plan-time API
# validation and avoids "connection refused" errors when the cluster is
# being created or replaced in a single apply.
resource "kubectl_manifest" "ebs_sc" {
  count = var.deploy_eks ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "storage.k8s.io/v1"
    kind       = "StorageClass"
    metadata = {
      name = "ebs-sc"
    }
    provisioner          = "ebs.csi.aws.com"
    reclaimPolicy        = "Delete"
    volumeBindingMode    = "WaitForFirstConsumer"
    allowVolumeExpansion = true
    parameters = {
      type   = "gp3"
      fsType = "ext4"
    }
  })

  depends_on = [aws_eks_addon.ebs_csi_driver]
}

# Apply EFS StorageClass via kubectl_manifest for the same reason as above.
# The fileSystemId is a dynamic value resolved at apply time after the EFS
# filesystem is created.
resource "kubectl_manifest" "efs_sc" {
  count = var.deploy_eks && var.create_efs ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "storage.k8s.io/v1"
    kind       = "StorageClass"
    metadata = {
      name = "efs-sc"
    }
    provisioner          = "efs.csi.aws.com"
    reclaimPolicy        = "Delete"
    allowVolumeExpansion = true
    parameters = {
      provisioningMode = "efs-ap"
      fileSystemId     = aws_efs_file_system.eks_efs[0].id
      directoryPerms   = "700"
    }
  })

  depends_on = [
    aws_eks_addon.efs_csi_driver,
    aws_efs_mount_target.eks_efs
  ]
}