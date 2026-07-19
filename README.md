# Automated Installation of IBM Guardium Data Protection on AWS

## Overview

Terraform modules for automated deployment of IBM Guardium Data Protection (GDP) appliances on AWS with intelligent readiness detection, unified AMI support, and automated configuration.

## Before Starting

To download the repository from the Terraform Registry, click on the View Source button on the front page of the project. This will open the GitHub repository. From there you can download the code to your computer using normal Git commands, such as:

```
git clone https://github.com/IBM/terraform-aws-gdp.git
```

## Supported Components

* **Central Manager**
* **Aggregator**
* **Collector**
* **Edge Gateway**


For background and detailed technical information, see the [project info document](docs/project_info.md).

## Summary of process

```
┌────────────────────────────────────────────────────┐
│                                                    │
│      Plan the installation, gather parameter       │
│                                                    │
└────────────────────────────────────────────────────┘
                          │
                          │
                          ▼
┌────────────────────────────────────────────────────┐
│                                                    │
│             Create the Central Manager             │
│                                                    │
└────────────────────────────────────────────────────┘
                          │
                          │
                          ▼
┌────────────────────────────────────────────────────┐
│                                                    │
│        Manually enter license and configure        │
│                                                    │
└────────────────────────────────────────────────────┘
                          │
                          │
                          ▼
┌────────────────────────────────────────────────────┐
│                                                    │
│               Create the Aggregators               │
│                                                    │
└────────────────────────────────────────────────────┘
                          │
                          │
                          ▼
┌────────────────────────────────────────────────────┐
│                                                    │
│               Create the Collectors                │
│                                                    │
└────────────────────────────────────────────────────┘
```

## Process flow

1. Connect to AWS. Plan the installation.
    * Region
    * VPC
    * Subnet
    * Security Group
    * Machine Types
    * AMI Files

2. Run the Terraform process to create a Central Manager.
3. Connect to the Central Manager by web browser and SSH (to CLI) to enter GDP license and convert to Central Manager.
4. Edit the parameters for the Aggregators to connect to the Central Manager.
5. Run the Terraform process to create the Aggregators.
6. Edit the parameters for the Collectors to connect to the Aggregators.
7. Run the Terraform process to create the Collectors.

## Prerequisites

### AWS

* Ability to login to AWS and view the EC2 instances and other information.
* RSA PEM key to connect to AWS from the machine that will be running the Terraform process.
* Ability to SSH into a bastion host if you are creating appliances with private IP addresses.

### Linux

* A clone of the GitHub repository for the Terraform scripts.
* Expect
* Microsoft Powershell
* yum-utils
* PEM key from AWS installed in your ssh agent

The documentation here assumes you will be using a Linux computer to run the Terrafrom process. Instructions to install these items will vary depending upon which Linux distribution you are using.

### GDP

* License (only required if you are creating a central manager)

## Usage

### Central Manager

Create a GDP Central Manager on AWS:

```hcl
module "central_manager" {

  # AWS Configuration
  region                        = "us-east-1"
  vpc_id                        = "vpc-1c99234371f8230f3"
  subnet_id                     = "subnet-1d93177291f513083"
  central_manager_ami_id        = "ami-0955ca4c9f731cc20"
  central_manager_instance_type = "m6i.2xlarge"
  key_name                      = "my_rsa_key"
  pem_file_path                 = "/home/my-user/.ssh/my_rsa_key.pem"
  allowed_cidrs                 = [
                                    "10.0.0.0/16",
                                    "170.225.223.17/32"
                                  ]
  assign_public_ip              = false

  # Guardium Configuration
  domain    = "corp.mycompany.local"
  timezone  = "America/New_York"
  resolver1 = "8.8.4.4"
  resolver2 = "1.1.1.1"
  tags      = {
                Environment = "dev"
                Project     = "GuardiumGDP"
                Owner       = "customer@example.com"
                Role        = "CentralManager"
              }
}
```


### Aggregator

Create a GDP Aggregator on AWS:

```hcl
module "aggregator" {

  # AWS Configuration
  region                   = "us-east-1"
  vpc_id                   = "vpc-1c99234371f8230f3"
  subnet_id                = "subnet-1d93177291f513083"
  aggregator_ami_id        = "ami-0955ca4c9f731cc20"
  aggregator_instance_type = "m6i.2xlarge"
  key_name                 = "my_rsa_key"
  pem_file_path            = "/home/my-user/.ssh/my_rsa_key.pem"
  allowed_cidrs            = [
                               "10.0.0.0/16",
                               "170.225.223.17/32"
                             ]
  assign_public_ip         = false

  # Guardium Configuration
  domain    = "corp.mycompany.local"
  timezone  = "America/New_York"
  resolver1 = "8.8.4.4"
  resolver2 = "1.1.1.1"
  tags      = {
                Environment = "dev"
                Project     = "GuardiumGDP"
                Owner       = "customer@example.com"
                Role        = "Aggregator"
              }
}
```


### Collector

Create a GDP Collector on AWS:

```hcl
module "collector" {

  # AWS Configuration
  region                  = "us-east-1"
  vpc_id                  = "vpc-1c99234371f8230f3"
  subnet_id               = "subnet-1d93177291f513083"
  collector_ami_id        = "ami-0955ca4c9f731cc20"
  collector_instance_type = "m6i.2xlarge"
  key_name                = "my_rsa_key"
  pem_file_path           = "/home/my-user/.ssh/my_rsa_key.pem"
  allowed_cidrs           = [
                              "10.0.0.0/16",
                              "170.225.223.17/32"
                            ]
  assign_public_ip        = false

  # Guardium Configuration
  domain    = "corp.mycompany.local"
  timezone  = "America/New_York"
  resolver1 = "8.8.4.4"
  resolver2 = "1.1.1.1"
  tags      = {
                Environment = "dev"
                Project     = "GuardiumGDP"
                Owner       = "customer@example.com"
                Role        = "Collector"
              }
}
```

### Edge Gateway

Deploy edge gateway on AWS EKS:

```hcl
module "edge" {

  # AWS EKS cluster name
  aws_region                             = "us-east-1"
  aws_profile                            = "my-aws-profile"

  vpc_cidr                               = "10.0.0.0/16"
  private_subnet_cidrs                   = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnet_cidrs                    = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  node_group_name                        = "ng-edge"
  node_instance_type                     = "m5.4xlarge"
  node_group_min_size                    = 1
  node_group_max_size                    = 4
  node_group_desired_size                = 2
  node_volume_size                       = 500

  create_efs                             = true
  ebs_csi_driver_version                 = null

  cluster_name                           = "my-eks-cluster"
  kubernetes_version                     = "1.33"

  k8s_metrics_server_install             = true
  k8s_metrics_server_airgap_install      = true
  k8s_metrics_server_airgap_install_path = "/path/metrics-server-yaml"


  tags                                   = {
                                              Environment = "aws"
                                              ManagedBy   = "terraform"
                                              Project     = "edge-gateway"
                                              Owner       = "your-name"
                                           }


  # Edge Gateway Configuration
  edge_name                              = "my-edge"
  edge_bundle_directory                  = "/path/to/edge-bundle/my-edge"

  platform                               = "eks"
  external_image_registry                = true

  monitor_max_attempts                   = 180
  monitor_sleep_interval                 = 10
  cleanup_bundle                         = true
  delete_timeout                         = "2h"

}
```

## Key Features

### Unified AMI Support

**Unified AMIs** - A single AMI image that can be configured as a Collector, Aggregator, or Central Manager through cloud-init configuration.

**Legacy AMIs (Default)**:
- Separate AMIs for each unit type (collector, aggregator, central-manager)
- No automatic cloud-init injection
- Set `ami_type = "legacy"` or omit (default)
- Maintains backward compatibility with existing deployments

**Unified AMI (Recommended for New Deployments)**:
- Single AMI for all unit types
- Automatic unit type configuration via cloud-init
- Set `ami_type = "unified"`
- Simplified AMI management

### Intelligent Readiness Detection

The modules include sophisticated polling mechanisms that:
- **Detect when Guardium CLI becomes operational** - No more blind waits
- **Provide detailed progress logging** - Real-time visibility into deployment status
- **Handle both public and private IP connectivity** - Works in any network configuration
- **Configurable timeout and polling intervals** - Tune for your environment
- **Significantly reduce deployment time** - Only wait as long as necessary

This feature eliminates the guesswork from deployments and provides clear feedback on system readiness.

### Automated Configuration

- **Expect-based CLI automation** for initial Guardium setup
- **Automatic Central Manager registration** for Aggregators and Collectors
- **License installation support** for automated deployments
- **Cloud-Init integration** with safe merging for custom configurations

### How It Works

When using a unified AMI:

1. **Collector**: System injects `license_accepted: true` (unified AMI defaults to collector)
2. **Aggregator**: System injects `aggregator: true` and `license_accepted: true`
3. **Central Manager**: System injects `aggregator: true` and `license_accepted: true` (CM is a special aggregator)

### Cloud-Init Merging

When using unified AMI with custom cloud-init:
- System-critical fields (`aggregator: true`, `license_accepted: true`) are **protected**
- User configuration is **safely merged** for non-conflicting fields
- Merging happens in Terraform before passing to cloud-init
- System configuration **always takes precedence** for conflicts
- User additions (new parameters) are **preserved**

### Usage Examples

#### Legacy AMI (Current Behavior)

```hcl
module "aggregator" {
  source = "./modules/aggregator"

  # ami_type defaults to "legacy"
  aggregator_ami_id        = "ami-legacy-aggregator-12345"
  aggregator_instance_type = "m6i.2xlarge"

  # ... other parameters
}
```

#### Unified AMI (Simple)

```hcl
module "aggregator" {
  source = "./modules/aggregator"

  ami_type                 = "unified"
  aggregator_ami_id        = "ami-unified-67890"
  aggregator_instance_type = "m6i.2xlarge"

  # System automatically injects aggregator: true
  # ... other parameters
}
```

#### Unified AMI with Custom Cloud-Init

```hcl
module "aggregator" {
  source = "./modules/aggregator"

  ami_type                 = "unified"
  aggregator_ami_id        = "ami-unified-67890"
  aggregator_instance_type = "m6i.2xlarge"
  user_data_file           = "./custom-config.yaml"

  # System merges: aggregator: true + your custom config
  # ... other parameters
}
```

**custom-config.yaml:**
```yaml
#cloud-config
ibm:
  guardium:
    new_parameter: true
```

**Result:** Terraform merges the configurations before passing to cloud-init. System injects `aggregator: true` and `license_accepted: true`, while your custom `new_parameter` is preserved.

### Configurable Storage and Naming

- **Customizable root volume size** - Adjust storage to your needs
- **Multiple volume types supported** - gp2, gp3, io1, io2
- **Configurable instance naming** - Custom prefixes for better organization
- **Volume retention control** - Choose whether to delete volumes on termination

### Migration Guide

**For Existing Deployments:**
- No changes required
- `ami_type` defaults to `"legacy"`
- All existing configurations continue to work

**For New Deployments:**
- Use `ami_type = "unified"` with unified AMI
- Optionally provide custom cloud-init via `user_data_file`
- System handles unit type configuration automatically

### Cloud-Init Merging Behavior

When using unified AMI with custom cloud-init:
- System-critical fields (`aggregator: true`, `license_accepted: true`) are **protected**
- User configuration is **safely merged** for non-conflicting fields
- Merging happens in Terraform before passing to cloud-init
- System configuration **always takes precedence** for conflicts
- User additions (new parameters) are **preserved**
- Final merged YAML is passed as a single `#cloud-config` to the instance

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## Support

For issues and questions:
- Create an issue in this repository
- Contact the maintainers listed in [MAINTAINERS.md](MAINTAINERS.md)

## License

This project is licensed under the Apache 2.0 License - see the [LICENSE](LICENSE) file for details.

```text
#
# Copyright (c) IBM Corp. 2026
# SPDX-License-Identifier: Apache-2.0
#
```

## Authors

Module is maintained by IBM with help from [these awesome contributors](https://github.com/IBM/terraform-guardium-datastore-va/graphs/contributors).
