# Step 6: Deploy the Collectors

Configure `terraform.tfvars` and run Terraform to provision the Collector instances on AWS.

**Navigation:** [Index](index.md) · [1 · Setup Linux](step01.md) · [2 · Install software](step03.md) · [3 · Deploy CM](step04.md) · [4 · Deploy Aggregators](step05.md) · [5 · Deploy Collectors](step06.md)

---

## Prerequisites

- The Terraform scripts from [Step 4](step04.md) and [Step 5](step05.md) completed successfully.
- You are logged into the Linux VM as your Terraform user, in your working directory.
- You have the AWS Console open in a web browser.

## Navigate to the example directory

```
cd terraform-aws-gdp/examples/collector/
```

## Create the variables file

The repository includes a fully commented example file. Copy it to create your own `terraform.tfvars`.

```
cp terraform.tfvars.example terraform.tfvars
```

Open `terraform.tfvars` in a text editor and set each value as described in the table below.

## Variable reference

### Required variables

| Variable | Description | Example |
|---|---|---|
| `region` | AWS region code where the Collectors will be created. Use the region code (e.g. `us-east-1`), not the location name. | `us-east-1` |
| `vpc_id` | ID of the VPC where the Collectors will be created. In the AWS Console, navigate to **VPC › Your VPCs** and note the VPC ID (not the VPC name). | `vpc-0b88123d60e712fe2` |
| `subnet_id` | ID of the subnet within the VPC. From the VPC Dashboard, click **Subnets**, filter by your VPC, and note the Subnet ID (not the subnet name). | `subnet-0c82066180e40df72` |
| `ami_type` | Type of AMI being used. Use `legacy` unless instructed otherwise. | `legacy` |
| `collector_ami_id` | AMI ID of the Collector image. In the EC2 Dashboard, click **AMI Catalog › My AMIs**, locate the Collector AMI you want to use, and copy its AMI ID (not the name). | `ami-0ff25c370c7a4b9f1` |
| `collector_instance_type` | AWS instance type for the Collectors. In the EC2 Dashboard, click **Instance Types** and note the type code. | `m6i.2xlarge` |
| `collector_count` | The number of Collectors you want to create. | `3` |
| `key_name` | Name of the AWS key pair created in [Step 2](step03.md). This is the filename of the `.pem` file without the extension. | `mykeyname` |
| `pem_file_path` | Absolute path to the `.pem` file **on the Linux VM**. | `/home/eli/.ssh/mykeyname.pem` |
| `allowed_cidrs` | List of CIDR blocks that are allowed to access the Collectors. Typically includes the VPC CIDR, plus the IP addresses of your Linux VM and your computer. Use `/32` for individual host IPs. | `["10.0.0.0/16", "170.225.223.16/32", "147.236.177.70/32"]` |
| `custom_allowed_cidrs` | Additional CIDR blocks to allow (optional). Leave as an empty list if not needed. | `[]` |
| `assign_public_ip` | Whether to assign a public IP address to the Collectors. If you leave this as `false`, you must use a bastion host for the deployment. The instructions in these pages assume you are setting this value to `true`. | `false` |
| `user_data_file` | Path to the Cloud-Init user-data file, used for license handling. Do not edit. | `./user-data.yaml` |
| `shared_secret` | The secret key used when Collectors register with the Central Manager. Must match the value you used when deploying the Central Manager. | `guard` |
| `central_manager_ip` | The private IP address of the Central Manager. Use the private IP address here even if you are assigning public IP addresses to the Collectors. | `10.0.12.37` |
| `central_manager_public_dns` | The public IP address (or DNS hostname) of the Central Manager created in [Step 4](step04.md). This is the address used by Terraform to connect to the Central Manager when registering the Collectors. | `44.198.175.80` |
| `license_base` | Base license for the Collectors. Obtain this from your IBM Guardium administrator. | *(long encoded string — obtain from your administrator)* |
| `license_append` | Append license for the Collectors. Obtain this from your IBM Guardium administrator. | *(long encoded string — obtain from your administrator)* |
| `domain` | Domain name for the GDP appliance. This is site-specific. | `corp.mycompany.local` |
| `timezone` | Timezone for the GDP appliance, in [tz database](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) format. | `America/New_York` |
| `resolver1` / `resolver2` | Primary and secondary DNS resolvers for the GDP appliance. These are site-specific. | `8.8.4.4` / `1.1.1.1` |
| `tags` | A map of AWS tags to apply to the created resources. These are site-specific and used for cost tracking and organisation. | `{ Environment = "dev", Project = "GuardiumGDP", Owner = "you@example.com", Role = "Collector" }` |
| `data_import_cron_string` | Cron expression that controls when the Collectors send data to their Aggregators. The default value runs the export daily at 02:00. | `0 0 2 * * ? *` |
| `number_collectors_per_aggregator` | Tells Terraform how many Collectors to assign to each Aggregator for data export. For example, if you have 6 Collectors and 2 Aggregators, set this to `3` to distribute them evenly. | `2` |
| `aggregator_name_prefix` | The name prefix used for the Aggregator instances. Must match the value entered for `instance_name_prefix` in the Aggregator `terraform.tfvars` file in [Step 5](step05.md). | `guard-agg` |

> **Note (Customising policies):** Before running Terraform, you can edit `modules/collector/configure_guardium.expect` to change which policy will be installed on the Collectors.

### Optional: existing security groups

If you want to reuse existing AWS security groups rather than having Terraform create new ones, you can provide their IDs here. Leave all three empty if you want Terraform to manage security groups automatically.

| Variable | Description |
|---|---|
| `existing_guardium_cm_sg_id` | Security group to use for the Central Manager. Leave empty to auto-create. |
| `existing_guardium_aggregator_sg_id` | Security group for Aggregators. Leave empty to auto-create. |
| `existing_guardium_collector_sg_id` | Security group for Collectors. Leave empty to auto-create. |

### Optional: instance naming and storage

These variables are commented out in `terraform.tfvars.example` by default. Uncomment and set them if you need to override the defaults.

| Variable | Description | Default |
|---|---|---|
| `instance_name_prefix` | Prefix for the instance name tag. The instance number is appended automatically (e.g. `guard-col` produces `guard-col01`, `guard-col02`, etc.). | `guard-col` |
| `root_volume_size` | Size of the root EBS volume in GB. | `1500` |
| `root_volume_type` | EBS volume type. | `gp3` |
| `root_volume_delete_on_termination` | Whether the root volume is deleted when the instance is terminated. | `true` |

## Run Terraform

Once you have finished editing and saved `terraform.tfvars`, run the following commands.

```
terraform init -reconfigure
terraform apply -auto-approve
```

The plan will be displayed. The script will take several minutes to complete.

> **Warning:** If there are errors, stop, fix the issue, and run `terraform apply -auto-approve` again. Do not proceed with a failed deployment.

When the script finishes successfully it prints details about the provisioned instances, including their security group ID and both internal and external IP addresses. **Record these values** for future reference.

## Verify the Collector deployment

### Connect to a Collector

Connect to one of the Collectors in a web browser using its public IP address (from the Terraform output or the AWS Console):

```
https://ip-address:8443
```

Log in using:

- **User:** `admin`
- **Password:** the same password as the Central Manager

Once logged in, verify that the expected policy is installed and that the data export settings are correct (navigate to **Setup › Tools and Views › Data Import/Export**). Note that different Collectors will show different target Aggregators in their data export configuration, depending on how they were distributed across Aggregators.

### Verify registration on the Central Manager

Connect to the Central Manager (as in [Step 4](step04.md)) and navigate to **Setup › Central Management**. Confirm that all Collectors appear in the central management list.
