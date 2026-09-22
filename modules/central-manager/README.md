# Guardium Central Manager Module for AWS

## Overview

This module deploys IBM Guardium Data Protection (GDP) Central Manager instances on AWS with automated configuration and intelligent readiness detection.

## Features

- **Unified AMI Support**: Single AMI for all unit types with automatic configuration.
- **Intelligent Readiness Detection**: Polls Guardium CLI until operational (replaces blind waits).
- **Automated Configuration**: Expect-based CLI automation for initial setup.
- **Flexible Networking**: Public or private IP deployment.
- **Cloud-Init Integration**: Custom user-data with safe merging for unified AMIs.
- **Configurable Storage**: Customizable root volume size, type, and retention.

## Parameters

All parameters must be modified in the terraform.tfvars file. See the [documentation](../../examples/central-manager/README.md) in the example for detailed instructions.

### AWS-related: Required to change

| Name | Comment | 
| --- | --- | 
| region | Code of the AWS region where you are creating the instances, e.g. us-east-1 | 
| vpc_id | ID of the VPC where the appliance will be created | 
| subnet_id | Subnet where the appliance will be created | 
| central_manager_ami_id, aggregator_ami_id, collector_ami_id | AMI file to use when building the CM | 
| central_manager_instance_type, aggregator_instance_type, collector_instance_type | Aws hardware profile to use when building the CM | 
| key_name | Name of the PEM key, without the path or .pem extension | 
| pem_file_path | Full path to the PEM file, including the .pem extension | 
| allowed_cidrs | IP addresses that will be allowed to connect to the appliance |

### AMI Configuration

| Name | Default | Description |
| --- | --- | --- |
| ami_type | "legacy" | AMI type: 'legacy' for unit-type-specific AMIs, 'unified' for multi-unit-type AMIs. When using unified AMI, the system automatically configures the correct unit type. |

### IAM Configuration (Optional)

| Name | Default | Description |
| --- | --- | --- |
| iam_instance_profile | null | IAM instance profile name or ARN to attach to the instance for AWS service access. |

### GDP-related: Can use defaults

| Name | Comment | 
| --- | --- | 
| domain | Local domain, e.g. mydept.myco.local | 
| timezone | Timezone of the appliance, e.g. Asia/Singapore | 
| resolver1 | DNS server for the appliance, default value of 8.8.4.4 provided | 
| resolver2 | DNS server for the appliance, default value of 1.1.1.1 provided | 
| tags -> Environmant | Name for the appliance environment, default value of dev provided | 
| tags -> Project | Project name for the appliance, e.g. MyDeptGDP | 
| tags -> Owner | Email address of the GDP owner | 
| tags -> Role | Role of the appliance, e.g. MyRole | 

### Instance Naming and Storage Configuration (Optional)

| Name | Default | Description |
| --- | --- | --- |
| instance_name_prefix | "guard-cm" | Prefix for instance name tag. Instance number will be appended (e.g., guard-cm-01). |
| root_volume_size | 1500 | Size of the root EBS volume in GB. Minimum 1500 GB for Central Manager. |
| root_volume_type | "gp3" | Type of the root EBS volume (gp2, gp3, io1, io2). |
| root_volume_delete_on_termination | true | Whether to delete the root volume when the instance is terminated. |

**Examples:**

Custom naming and storage:
```hcl
module "central_manager" {
  source = "./modules/central-manager"
  instance_name_prefix = "prod-cm"
  root_volume_size     = 2000
  root_volume_type     = "gp3"
  # ... other required variables ...
}
```

### Guardium Readiness Polling Configuration (Optional)

The module includes intelligent polling to detect when Guardium is ready for configuration. This replaces blind waits and significantly reduces deployment time.

| Name | Default | Description | 
| --- | --- | --- |
| guardium_ready_max_wait | 1200 | Maximum time in seconds to wait for Guardium CLI (20 minutes). Increase for slow environments. |
| guardium_ready_poll_interval | 30 | Seconds between readiness checks. Lower = faster detection but more network traffic. |
| guardium_ready_log_file | "" | Optional log file path for polling output. Empty = stdout only. |

**Examples:**

Standard deployment (uses defaults):
```hcl
module "central_manager" {
  source = "./modules/central-manager"
  # ... other required variables ...
}
```

Production with extended timeout and logging:
```hcl
module "central_manager" {
  source = "./modules/central-manager"
  guardium_ready_max_wait      = 1800  # 30 minutes
  guardium_ready_poll_interval = 60    # Check every minute
  guardium_ready_log_file      = "/var/log/guardium-deployment.log"
  # ... other required variables ...
}
```

## Unified AMI vs Legacy AMI

**Legacy AMI (Default)**:
- Separate AMI for Aggregator (then converted into a Central Manager)
- No automatic cloud-init injection
- Maintains backward compatibility

**Unified AMI (Recommended)**:
- Single AMI for all unit types
- Automatic injection of `aggregator: true` and `license_accepted: true`
- Simplified AMI management

Set `ami_type = "unified"` to use unified AMI mode.

## Intelligent Readiness Detection

The module includes a sophisticated polling mechanism that:
- Detects when Guardium CLI becomes operational
- Eliminates blind wait times
- Provides detailed progress logging
- Handles both public and private IP connectivity
- Configurable timeout and polling intervals

This significantly reduces deployment time and provides better visibility into the deployment process.

## Manual Steps

After Terraform completes, the instance is created as a stand-alone Aggregator. You must manually convert it to a Central Manager. See the [documentation](../../examples/central-manager/README.md) in the example for detailed instructions.
