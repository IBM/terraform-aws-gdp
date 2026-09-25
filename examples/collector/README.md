# Create GDP Collector for AWS

## Introduction

Use this example to create a GDP Collector on AWS.

## Summary of process

The Terraform scripts should be run in this order.

1. Configure the Terraform process.
2. Run the Terraform process. This will create an Collector.

## 1. Configuration

### 1.1 Edit the parameters

Create the file terraform.tfvars based on the example file.

```
cp terraform.tfvars.example terraform.tfvars
```

Edit the file and enter the parameters for your installation.

```
vi terraform.tfvars
```

The parameters are documented in the file. For additional information about the parameters, see the [parameters document](docs/parameters.md).

After you have verified the parameters, save the file and exit the editor.

#### Unified AMI Support

This example supports both **legacy** and **unified** AMI types:

**Legacy AMI (Default):**
```hcl
ami_type = "legacy"  # or omit this line
collector_ami_id = "ami-legacy-collector-12345"
```

**Unified AMI (Recommended):**
```hcl
ami_type = "unified"
collector_ami_id = "ami-unified-67890"
```

When using a unified AMI, the system automatically injects `license_accepted: true` via cloud-init. The unified AMI defaults to collector mode, so no additional configuration is needed.

**Unified AMI with Custom Cloud-Init:**
```hcl
ami_type = "unified"
collector_ami_id = "ami-unified-67890"
user_data_file = "./custom-config.yaml"
```

Your custom cloud-init configuration will be safely merged with the system configuration. See the main [README](../../README.md#unified-ami-support) for more details.

### 1.2 Connect to a Central Manager

In AWS, locate the IP address of the Central Manager you want this Collector to register with.

Set `central_manager_ip` in your `terraform.tfvars` to that IP:

```hcl
central_manager_ip = "10.0.0.10"   # replace with the IP address of the Central Manager
```

The Terraform module handles registration automatically — no manual edits to the expect script are needed.

> **Standalone mode:** Leave `central_manager_ip` empty (or omit it) to deploy the Collector without registering it with a CM. In standalone mode the Collector accepts license keys directly.

## 2. Run the Terraform process

Start by initializing Terraform.

```
terraform init
```

Then set up Terraform to run the process you have defined.

```
terraform plan
```

Finally, run the process.

```
terraform apply
```

You will be prompted to enter "yes" after a few seconds. Then the process will run until it completes. This could take up to 45 minutes.

## 3 Connect to GDP

In AWS, locate the instance that was created by the Terraform process.

Note its **IP address** and its **instance ID**.

Connect to GDP via a browser with a URL like this:

```
https://ip-address:8443
```

You can then begin using GDP. In the login screen:
* User: `admin`
* Password: `same password you set for the Central Manager`

You will be prompted to immediately change the password.
