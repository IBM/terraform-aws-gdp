# Complete End-to-End AWS EKS Deployment with Edge

This is a **complete end-to-end solution** that combines AWS EKS cluster creation and optional Edge deployment in a single Terraform deployment. It uses the [`aws-eks`](../aws-eks/) module for cluster infrastructure and the unified [`terraform-provider-guardium-data-protection`](https://github.com/IBM/terraform-provider-guardium-data-protection) provider for Edge deployment.

## What This Does

1. **Creates AWS EKS Cluster** (VPC, subnets, node groups) - **OPTIONAL**
2. **Configures Storage** (EBS CSI, EFS CSI drivers)
3. **Sets up Networking** (public/private subnets, NAT gateways)
4. **Installs Kubernetes Metrics Server** (supports online and airgap) - **OPTIONAL**
5. **Deploys Edge Components** via custom provider
6. **Installs Certificates** on EKS nodes (if Edge enabled and `external_image_registry = false`)
7. **Verifies Deployment** (cluster ready, storage classes)

All in **one `terraform apply` command**! Resources are applied in the order listed above.

## Providers

| Provider | Source | Resource | Purpose |
|----------|--------|----------|---------|
| `hashicorp/aws` | `hashicorp/aws` | AWS resources | EKS cluster, VPC, IAM |
| `hashicorp/kubernetes` | `hashicorp/kubernetes` | — | Kubernetes API access |
| `hashicorp/http` | `hashicorp/http` | `data.http` | Fetch Metrics Server manifest (online mode) |
| `gavinbunney/kubectl` | `gavinbunney/kubectl` | `kubectl_manifest` | Apply Metrics Server manifests |
| `ibm/guardium-data-protection` | `hashicorp.com/ibm/guardium-data-protection` | `guardium-data-protection_deployment` | Deploy Edge components |

## Deployment Modes

### Mode 1: Full Deployment (Default)
Deploy everything from scratch - EKS cluster and Edge components.

```hcl
deploy_eks    = true  # Default
install_edge  = true
```

### Mode 2: Edge-Only Deployment
Skip EKS creation and only deploy Edge components to an existing EKS cluster.

```hcl
deploy_eks                = false
external_eks_cluster_name = "my-existing-cluster"
install_edge              = true
```

## Quick Start

### Prerequisites

- AWS CLI configured with credentials
- Terraform >= 1.0
- kubectl installed
- SSH key pair created in AWS (for node access)
- SSH private key file (if deploying Edge)

### 1. Configure

```bash
cd complete-e2e-aws-eks-deployment
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
# AWS Credentials
aws_profile = "default"
aws_region  = "us-east-2"

# Cluster Configuration
cluster_name       = "my-eks-cluster"
kubernetes_version = "1.33"

# Node Configuration
node_instance_type      = "m5.4xlarge"
node_group_desired_size = 2
ssh_key_name            = "my-eks-key"  # Must exist in AWS

# Enable Edge Deployment
install_edge = true
```

### 2. Deploy

```bash
terraform init
terraform plan
terraform apply
```

**Deployment Time**: ~30-40 minutes for EKS cluster

### 3. Access

```bash
# Configure kubectl
aws eks update-kubeconfig --region us-east-2 --name my-eks-cluster

# Verify cluster
kubectl get nodes
kubectl get storageclass
```

## Architecture

```
┌──────────────────────────────────────────────────────┐
│  complete-e2e-aws-eks-deployment (Custom Provider)   │
└──────────────────────────────────────────────────────┘
                          │
         ┌────────────────┼────────────────┐
         │                │                │
         ▼                ▼                ▼
┌──────────────┐  ┌──────────────────┐  ┌──────────────────┐
│   aws-eks    │─▶│ kubectl_manifest │─▶│    gdp_edge      │
│   (Module)   │  │ (Metrics Server) │  │   (Provider)     │
└──────────────┘  └──────────────────┘  └──────────────────┘
       │                  │                      │
       ▼                  ▼                      ▼
  EKS Cluster       Metrics Server         Edge Components
  - VPC & Subnets   - Online (GitHub)      - Certificates
  - Node Groups     - Airgap (local dir)   - Edge Pods
  - Storage         - kubectl top / HPA    - ConfigMaps
  - EBS/EFS
```

**Apply order** (enforced by `depends_on` chain):
`aws-eks` → `kubectl_manifest.metrics_server` → `gdp_edge_deployment.edge`

## Configuration Examples

### Basic EKS Cluster (No Edge)

```hcl
cluster_name            = "basic-eks"
aws_profile             = "default"
aws_region              = "us-east-2"
ssh_key_name            = "my-key"
node_group_desired_size = 2
install_edge            = false
```

### EKS with Edge Deployment

```hcl
cluster_name            = "edge-eks-prod"
aws_profile             = "production"
aws_region              = "us-east-1"
ssh_key_name            = "prod-key"
node_group_desired_size = 3

# Enable Edge (uses custom gdp-edge provider)
# The url may need port for rest api call to get edge bundle
install_edge     = true
edge_name        = "prod-edge"
edge_cm_url      = "https://guardium-cm.example.com"
edge_oauth_token = "your-oauth-token"
eks_ssh_key_path = "~/.ssh/prod-key.pem"

# Set to true when using an external image registry (e.g. Docker Hub, Quay)
# instead of the CM private registry. Skips registry certificate installation.
# external_image_registry = true
```

### EKS with Metrics Server (Online)

```hcl
cluster_name       = "edge-eks-prod"
aws_profile        = "default"
aws_region         = "us-east-2"
ssh_key_name       = "my-key"

# Install Metrics Server from GitHub (requires internet access at apply time)
k8s_metrics_server_install        = true
k8s_mertics_server_airgap_install = false
```

### EKS with Metrics Server (Airgap)

```hcl
cluster_name       = "edge-eks-airgap"
aws_profile        = "default"
aws_region         = "us-east-2"
ssh_key_name       = "my-key"

# Install Metrics Server from a local directory (no internet access required)
# Path is relative to the directory where terraform apply is run.
# The directory must contain the Metrics Server YAML manifests (*.yaml / *.yml).
k8s_metrics_server_install             = true
k8s_mertics_server_airgap_install      = true
k8s_metrics_server_airgap_install_path = "./airgap_kubenetes_metrics_server_installation/"
```

### Deploy Edge to Existing EKS Cluster

```hcl
deploy_eks                = false
external_eks_cluster_name = "my-existing-eks-cluster"
aws_region                = "us-east-2"
aws_profile               = "default"

install_edge      = true
edge_name         = "my-edge"
edge_cm_url       = "https://guardium-insights.example.com"
edge_oauth_token  = "your-oauth-token"
eks_ssh_key_path  = "~/.ssh/my-key.pem"
eks_hostname_type = "public"
```

### Large Production Cluster

```hcl
cluster_name            = "large-prod-eks"
kubernetes_version      = "1.33"
node_instance_type      = "m5.8xlarge"
node_group_min_size     = 3
node_group_max_size     = 10
node_group_desired_size = 5
node_volume_size        = 1000

vpc_cidr             = "172.16.0.0/16"
private_subnet_cidrs = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
public_subnet_cidrs  = ["172.16.101.0/24", "172.16.102.0/24", "172.16.103.0/24"]

ssh_allowed_cidr_blocks = ["10.0.0.0/8"]

tags = {
  Environment = "production"
  CostCenter  = "engineering"
  Owner       = "platform-team"
}
```

### Node Subnet Type — Private vs Public IPs

The `node_group_subnet_type` variable controls whether worker nodes are placed in private or public subnets.

| Value | Node IP | Use case |
|-------|---------|----------|
| `"private"` (default) | No public IP | Production; SSH via VPN, bastion, or AWS SSM |
| `"public"` | Public IP assigned | Dev/test; SSH directly from outside the VPC (e.g. laptop with no VPN) |

```hcl
# Private subnets (default — recommended for production)
node_group_subnet_type = "private"

# Public subnets — required when Terraform runs on a machine outside the VPC
# with no VPN or bastion host (assigns a public IP to each node)
node_group_subnet_type = "public"
```

> **Note**: `eks_hostname_type` is separate — it controls which hostname is used when the gdp-edge provider SSHs into nodes (`"public"` to use the public DNS name, `"private"` to use the private DNS name). When `node_group_subnet_type = "public"`, set `eks_hostname_type = "public"` as well.

## Outputs

```bash
terraform output
```

Key outputs:
- `deployment_summary` - Complete cluster information
- `access_instructions` - How to access the cluster
- `configure_kubectl` - kubectl configuration command
- `cluster_endpoint` - EKS API endpoint
- `edge_summary` - Edge deployment status (if installed)
- `edge_namespace` - Edge namespace (if installed)

## Storage Classes

The deployment creates two storage classes:

- **ebs-sc** (gp3): Block storage for databases, persistent volumes
- **efs-sc** (EFS): Shared file storage, ReadWriteMany volumes

## Troubleshooting

### EKS Cluster Creation Failed

```bash
aws service-quotas list-service-quotas --service-code eks --region us-east-2
```

### Node Group Not Ready

```bash
kubectl get nodes
kubectl describe node <node-name>
ssh -i ~/.ssh/my-key.pem ec2-user@<node-public-ip>
sudo journalctl -u kubelet -f
```

### Edge Deployment Failed

```bash
kubectl get pods -n <edge-namespace>
kubectl logs -n <edge-namespace> <pod-name>
ssh -i ~/.ssh/my-key.pem ec2-user@<node-ip>
sudo ls -la /etc/containerd/certs.d/
```

## Cleanup

```bash
terraform destroy
```

This will remove all resources in reverse order: Edge -> EKS cluster -> VPC/networking.

## File Structure

```
edge-aws-eks/
├── main.tf                                    # Module + provider resource definitions
├── variables.tf                               # All variables
├── outputs.tf                                 # Combined outputs
├── terraform.tfvars.example                   # Example configuration
├── airgap_kubenetes_metrics_server_installation/
│   └── components.yaml                        # Metrics Server manifests for airgap install
├── .gitignore                                 # Security patterns
└── README.md                                  # This file
```

