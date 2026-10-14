# Deploying GDP on AWS

A step-by-step runbook for provisioning GDP appliances on AWS using Terraform.

## Prerequisites

- An AWS account with permission to create EC2 instances, security groups, and key pairs
- An AWS Access Key ID and Secret Access Key
- GDP AMI images available in your AWS region
- GDP license keys (base and append) for the Central Manager

## Target audience

These instructions assume you are comfortable working at a Linux command line and have some familiarity with GDP, but do not require deep Terraform expertise.

## Choose your path

### IBM employees

You will provision a Linux VM on IBM Fyre to use as your Terraform host.

1. **[Set up Linux](step01.md)** — Create a Fyre VM, set up a user, configure GitHub SSH access, and clone the Terraform repository.
2. **[Install required software](step03.md)** — Install Terraform, expect, PowerShell, and the AWS CLI; create an AWS key pair; note your IP addresses.
3. **[Deploy and connect to the Central Manager](step04.md)** — Configure `terraform.tfvars`, run `terraform apply` to provision the Central Manager, then connect to it.
4. **[Deploy the Aggregators](step05.md)** — Configure `terraform.tfvars` and run `terraform apply` to provision the Aggregator instances.
5. **[Deploy the Collectors](step06.md)** — Configure `terraform.tfvars` and run `terraform apply` to provision the Collector instances.

### Customers

You will use your own Linux machine as the Terraform host, with all required software already installed.

1. **[Deploy and connect to the Central Manager](step04.md)** — Configure `terraform.tfvars`, run `terraform apply` to provision the Central Manager, then open inbound rules on the security group and access the GDP web console and CLI.
2. **[Deploy the Aggregators](step05.md)** — Configure `terraform.tfvars` and run `terraform apply` to provision the Aggregator instances.
3. **[Deploy the Collectors](step06.md)** — Configure `terraform.tfvars` and run `terraform apply` to provision the Collector instances.

## Repository

The Terraform scripts used in this runbook are available at [github.com/IBM/terraform-aws-gdp](https://github.com/IBM/terraform-aws-gdp).
