## 🛡️ IBM Guardium GDP – Terraform Deployment (Public/Private IP) 

### 📘 Overview

This repository automates the **end-to-end deployment** of an **IBM Guardium Data Protection (GDP)** environment on **AWS** using Terraform and Expect automation scripts.<br>
It provisions and configures the following Guardium components with **Public/Private IP access**.<br>
( the defualt **Private IP**   assign_public_ip = false , in terraform.tfvars) <br>
purposes:
* **Central Manager (CM)**
* **Aggregators**
* **Collectors**

Each Guardium instance is automatically configured post-boot using SSH automation (Expect) for:

* Network and hostname setup
* Resolver and domain configuration
* Timezone setup
* Full CLI verification
* Logging of all automation phases

> ⚠️ This repository is for **Public/Private IP deployments**. update terraform.tfvars to enable disabled Public/Private IP deployments.<br>
> recommeded to deploy on  **Secured Zone** with Bastion host access.

---

## 🧩 Repository Structure

```bash
terraform-guardium-gdp/
├── versions.tf                # Defines required Terraform and provider versions
├── README.md                  # This documentation
│
├── modules/                   # Core functional modules
│   ├── central-manager/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── configure_guardium.expect
│   │   
│   ├── aggregator/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── configure_guardium.expect
|   | 
│   ├── auto-vpc/
│   │   ├── main.tf
│   │   
│   └── collector/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── configure_guardium.expect
│       
│
├── examples/                  # Practical deployment examples
│   ├── central-manager/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
|   |   |-- user-data.yaml   # Cloud-init auto approve license 
│   │   └── logs/
│   │   │   └── configure_guardium_guardium-cm-01_20251029_141533.log
│   ├── aggregator/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── logs/
│   │   │   └── configure_guardium_guardium-agg-01_20251029_141533.log
│   └── collector/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── logs/
│   │   │   └── configure_guardium_guardium-col-01_20251029_141533.log
│
└── logs/                      # (Optional centralized logs if enabled)
```

---

## ⚙️ Features

| Feature                                    | Description                                                            |
| ------------------------------------------ | ---------------------------------------------------------------------- |
| **Multi-tier Guardium Deployment**         | Automatically provisions Central Managers, Aggregators, and Collectors |
| **Public IP Configuration**                | Uses Elastic IPs for remote SSH/Expect automation                      |
| **Post-Deployment Automation**             | Each instance configured automatically via Expect script               |
| **Parallel Creation**                      | Terraform spawns multiple instances in parallel                        |
| **Automatic 20-minute Guardium Boot Wait** | Ensures the CLI is available before automation begins                  |
| **Dynamic Logs**                           | Logs stored under each module (`./logs/`) with timestamped filenames   |
| **Cross-Module Variable Control**          | Unified control of AMI, instance types, and tags via root variables    |
| **Extendable**                             | Designed for later secure-zone (bastion) adaptation                    |
| **Fully Auditable**                        | Terraform state, plan, and logs preserved for inspection               |

---

### 🧭 Prerequisites

Before deploying **IBM Guardium GDP** on AWS, please review and complete the following setup steps:

1. **Create AWS Key Pairs**
   You must create an AWS Key Pair for each AWS region where Guardium instances will be deployed.<br>
   📘 [AWS Documentation – Create key pairs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html)

2. **Select the Correct Guardium AMI Versions**
   Guardium installation images are provided as AWS AMIs. Make sure to select the correct version for your deployment.<br>
   📄 [IBM Guardium Cloud Deployment on AWS (AMI Reference Guide)](https://www.ibm.com/support/pages/sites/default/files/inline-files/%24FILE/IBM%2520Security%2520Guardium%2520Cloud%2520Deployment%2520-%2520AWS_0.pdf)

3. **Set the System Time Zone**
   After instance creation, configure the correct time zone and system time.
   Use the following command to view available time zones and set the appropriate one for your deployment:<br>
   📗 [IBM Docs – Set time zone, date, and time](https://www.ibm.com/docs/en/gdp/12.x?topic=configuration-set-time-zone-date-time)


---

| Requirement                  | Description                                        |
| ---------------------------- | -------------------------------------------------- |
| **Terraform v1.6+**          | Infrastructure as Code engine                      |
| **AWS Account**              | With permissions for EC2, VPC, and Security Groups |
| **AWS CLI configured**       | `aws configure` with credentials/profile           |
| **Expect utility installed** | Required for post-deployment CLI automation        |
| **SSH Key Pair**             | Existing EC2 key pair in AWS + local PEM file      |
| **AMI Image**                | Guardium GDP base image (AMI ID per region)        |

---

### Install Expect (Linux)

```bash
sudo yum install expect -y     # RHEL/CentOS
# or
sudo apt install expect -y     # Ubuntu/Debian
```

---

## 🗝️ File Permissions

Before applying Terraform, ensure all automation scripts are executable:

```bash
chmod +x modules/central-manager/configure_guardium.expect
chmod +x modules/aggregator/configure_guardium.expect
chmod +x modules/collector/configure_guardium.expect
```

---

## 🧩 Example Configuration


### File: `examples/central-manager/terraform.tfvars`
You can deploy multiple instances according to the value of `central_manager_count = 1`, depending on the size of the VPC.<br>

```hcl

######################################
# IBM Guardium GDP – Aggregator Vars
######################################

# Copy this file to terraform.tfvars and edit the values in it
# before running "terraform plan" and "terraform apply".

# =====================================================
# AWS Region & Network
# =====================================================

# AWS region where GDP is to be created.
region = "us-east-1"

# ID of the VPC that GDP will be created in.
vpc_id = "vpc-0b88123d60e712fe2"

# Subnet that GDP will be created in.
subnet_id = "subnet-08e64682d699e4e57"

# =====================================================
# Guardium Aggregator Deployment
# =====================================================

# AMI image to be used for the GDP machine.
aggregator_ami_id = "ami-0955ca4c9f731cc20"

# AWS instance type to be used for the GDP machine.
aggregator_instance_type = "m6i.2xlarge"

# How many aggregators to create.
aggregator_count = 1

# =====================================================
# SSH Access
# =====================================================

# Name of the key pair used to access GDP on AWS
key_name = "my_rsa_key"

# Path on the computer running this process to the PEM file
pem_file_path  = "/home/my-user/.ssh/my_rsa_key.pem"

# =====================================================
# Security Group CIDRs
# =====================================================

# IP addresses that can access the GDP machine.
allowed_cidrs = [
  "10.0.0.0/16",
  "170.225.223.17/32"
]

# Optional custom admin IPs
custom_allowed_cidrs = [
  # "192.168.10.0/24",
  # "203.0.113.45/32"
]

# =====================================================
# Public vs Private IP
# =====================================================

# Should the GDP machine have a public IP address or be
# accessible only through bastion.use true or false
assign_public_ip = false

# =====================================================
# Shared Secret (for Central Manager registration)
# =====================================================

# Shared secret that must match the Central Manager. Used when registering this Aggregator.
shared_secret = "guard"

# =====================================================
# Central Manager Registration
# =====================================================

# IP address of the Central Manager to register with
central_manager_ip = "10.0.0.10"

# =====================================================
# GDP Configuration
# =====================================================

# Domain name
domain = "corp.mycompany.local"

# Timezone
timezone = "America/New_York"

# DNS servers
resolver1 = "8.8.4.4"
resolver2 = "1.1.1.1"

# GDP tags
tags = {
  Environment = "dev"
  Project     = "GuardiumGDP"
  Owner       = "customer@example.com"
  Role        = "Aggregator"
}

# =====================================================
# Existing Security Groups (optional)
# =====================================================
# Leave empty to auto-create a new SG or detect existing "guardium-agg-sg"
existing_guardium_aggregator_sg_id = ""
existing_guardium_cm_sg_id         = ""
existing_guardium_collector_sg_id  = ""



```

---

## 🚀 Deployment

### 1. Initialize Terraform
before running the terraform command make sure to update your public IP in terraform.tfvar , example if you from IBM allow the cidrs  allowed_cidrs = ["10.0.0.0/16", "9.80.60.123/32"]  
```
# Access Control
allowed_cidrs = ["10.0.0.0/16", "170.225.223.17/32"] 
```

```bash
cd examples/central-manager
terraform init -reconfigure
```

### 2. Review Plan

```bash
terraform plan
```

### 3. Apply Infrastructure

```bash
terraform apply
```

### 4. Confirm when prompted:

Type **`yes`** to proceed with deployment.

---

## 🧠 Automation Workflow

### Expect Script (`configure_guardium.expect`)

Each instance runs this script post-boot:

| Phase       | Description                                     |
| ----------- | ----------------------------------------------- |
| **Phase 1** | SSH login and Guardium CLI network setup        |
| **Phase 2** | Apply hostname, domain, resolvers, and timezone |
| **Phase 3** | Restart network, wait for reboot                |
| **Phase 4** | Reconnect, verify configuration (show commands) |

Automation waits **~20 minutes** after creation to allow Guardium initialization, then performs CLI automation with real-time logging.

---

## 🧾 Log Files

By default, logs are stored under each module:

```
examples/central-manager/logs/
examples/aggregator/logs/
examples/collector/logs/
```

Example file name:

```
configure_guardium_guardium-cm-01_20251029_141533.log
```

You can follow progress in real-time:

```bash
tail -f examples/central-manager/logs/configure_guardium_*.log
```

> To centralize all logs under the project root, adjust:
>
> ```tcl
> file mkdir "../../logs"
> set LOGFILE "../../logs/configure_guardium_${HOSTNAME}_${DATESTAMP}.log"
> ```

---


## 🔍 Troubleshooting

| Issue                              | Possible Cause                  | Resolution                                     |
| ---------------------------------- | ------------------------------- | ---------------------------------------------- |
| **Timeout waiting for CLI prompt** | Guardium boot not complete      | Wait longer or increase sleep (default 20 min) |
| **Permission denied (.pem)**       | Wrong PEM permissions           | Run `chmod 400 ~/.ssh/guardiumcli.pem`         |
| **Expect not found**               | Expect not installed            | Run `sudo yum install expect -y`               |
| **SSH refused**                    | Security group or VPC misconfig | Verify CIDR rules and subnet routing           |
| **No logs written**                | Missing execute permission      | Run `chmod +x configure_guardium.expect`       |

---

## 🧩 Future Enhancements

* Bastion-secured deployment (`terraform-guardium-gdp-secure`)
* Cross-registration (Collector → Aggregator → CM)
* Integration with  tagging policies
* Optional CloudWatch monitoring hooks

---
**known and common issue** when running the Guardium CLI automation for timezone configuration. 
---

### ⚠️ Known Issue – `set time zone y` Command Fails

**Symptom:**
During the Guardium CLI automation (e.g., `configure_guardium.expect` or Terraform `local-exec`), you may encounter the following error:

```
(local-exec): ERROR: Command 'y' unknown.
USAGE: Commands are:
?, add, aggregator, background, backup, clone, ...
```

**Cause:**
This happens when the Expect script accidentally sends an extra `"y"` input after the `set time zone` command — typically due to a defualt time zone 
```
guard.yourcompany.com> store system clock timezone America/New_York
module.guardium_collector.null_resource.configure_guardium["guardium-col-01"] (local-exec):
module.guardium_collector.null_resource.configure_guardium["guardium-col-01"] (local-exec): Current timezone America/New_York
module.guardium_collector.null_resource.configure_guardium["guardium-col-01"] (local-exec): No change for the timezone
module.guardium_collector.null_resource.configure_guardium["guardium-col-01"] (local-exec): Command ran on: Thu Oct 30 10:19:36 2025
module.guardium_collector.null_resource.configure_guardium["guardium-col-01"] (local-exec): ok
```
Guardium CLI interprets `"y"` as a separate command and returns:

```
ERROR: Command 'y' unknown.
```

**Impact:**

* The timezone is usually set correctly **despite the error**, so this message can be safely ignored.
* It does **not stop** the automation or impact the final configuration.


**Symptom:**
```
(local-exec): spawn ssh -o StrictHostKeyChecking=no -i /home/ec2-user/.ssh/guardiumcli.pem cli@10.0.11.253
(local-exec): ERROR: Incorrect number of arguments
Usage: cli_wrapper
```
**Impact:**
Guardium’s cli user runs all commands through its internal cli_wrapper, which doesn’t accept arbitrary shell commands (like echo OK).
So when Terraform or the Expect script does that to “test connectivity,” Guardium interprets it as an incomplete cli_wrapper command and shows:

“ERROR: Incorrect number of arguments – Usage: cli_wrapper”
It does not indicate a failure in authentication or connectivity.
It only means Guardium’s restricted CLI rejected the test command.
The actual SSH session is successful, so Terraform proceeds to run the configuration commands normally.

**Symptom:**
```
Error: [WARN] A duplicate Security Group rule was found on (sg-0b93f60f0e0dda8ef). This may be
│ a side effect of a now-fixed Terraform issue causing two security groups with
│ identical attributes but different source_security_group_ids to overwrite each
│ other in the state. See https://github.com/hashicorp/terraform/pull/2376 for more
│ information and instructions for recovery. Error: operation error EC2: AuthorizeSecurityGroupIngress, https response error StatusCode: 400, RequestID: b372f65e-1770-4384-8e74-4beaead16365, api error InvalidPermission.Duplicate: the specified rule "peer: 170.225.223.17/32, TCP, from port: 22, to port: 22, ALLOW" already exists
│ 
│   with aws_security_group_rule.guardium_cm_ssh_allowed_cidrs["170.225.223.17/32"],
│   on main.tf line 113, in resource "aws_security_group_rule" "guardium_cm_ssh_allowed_cidrs":
│  113: resource "aws_security_group_rule" "guardium_cm_ssh_allowed_cidrs" {
│ 
```
**Impact:**
you can ignore this error. The rule already exists on the security group, so the desired state is already met. The Guardium configuration completed successfully.
To avoid this error in future runs, we can add error handling so Terraform skips creating rules that already exist. Updating the code:
Yes, you can ignore this error. The rule already exists on the security group, so the desired state is already met.
What happened:
The security group already has port 22 (SSH) enabled for 170.225.223.17/32
Terraform tried to create it again → AWS returned "duplicate"
The Guardium configuration completed successfully
