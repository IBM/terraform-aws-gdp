# Automated installation of GDP appliances on AWS

## Scope

The modules contained here automate installation of GDP appliances onto AWS.

The following are supported:

* Central Manager
* Aggregator
* Collector

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
# Copyright IBM Corp. 2025
# SPDX-License-Identifier: Apache-2.0
#
```

## Authors

Module is maintained by IBM with help from [these awesome contributors](https://github.com/IBM/terraform-guardium-datastore-va/graphs/contributors).
