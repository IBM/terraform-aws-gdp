# Step 5: Deploy the Aggregators

Configure `terraform.tfvars` and run Terraform to provision the Aggregator instances on AWS.

**Navigation:** [Index](index.md) · [1 · Setup Linux](step01.md) · [2 · Install software](step03.md) · [3 · Deploy CM](step04.md) · [4 · Deploy Aggregators](step05.md) · [5 · Deploy Collectors](step06.md)

---

## Prerequisites

- The Terraform script from [Step 4](step04.md) completed successfully.
- You are logged into the Linux VM as your Terraform user, in your working directory.
- You have the AWS Console open in a web browser.

## Navigate to the example directory

```
cd terraform-aws-gdp/examples/aggregator/
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
| `region` | AWS region code where the Aggregators will be created. Use the region code (e.g. `us-east-1`), not the location name. | `us-east-1` |
| `vpc_id` | ID of the VPC where the Aggregators will be created. In the AWS Console, navigate to **VPC › Your VPCs** and note the VPC ID (not the VPC name). | `vpc-0b88123d60e712fe2` |
| `subnet_id` | ID of the subnet within the VPC. From the VPC Dashboard, click **Subnets**, filter by your VPC, and note the Subnet ID (not the subnet name). | `subnet-0c82066180e40df72` |
| `ami_type` | Type of AMI being used. Use `legacy` unless instructed otherwise. | `legacy` |
| `aggregator_ami_id` | AMI ID of the Aggregator image. In the EC2 Dashboard, click **AMI Catalog › My AMIs**, locate the Aggregator AMI you want to use, and copy its AMI ID (not the name). | `ami-0f3ceaf1844a82568` |
| `aggregator_instance_type` | AWS instance type for the Aggregators. In the EC2 Dashboard, click **Instance Types** and note the type code. | `m6i.2xlarge` |
| `aggregator_count` | The number of Aggregators you want to create. | `2` |
| `key_name` | Name of the AWS key pair created in [Step 2](step03.md). This is the filename of the `.pem` file without the extension. | `mykeyname` |
| `pem_file_path` | Absolute path to the `.pem` file **on the Linux VM**. | `/home/eli/.ssh/mykeyname.pem` |
| `allowed_cidrs` | List of CIDR blocks that are allowed to access the Aggregators. Typically includes the VPC CIDR, plus the IP addresses of your Linux VM and your computer. Use `/32` for individual host IPs. | `["10.0.0.0/16", "170.225.223.16/32", "147.236.177.70/32"]` |
| `custom_allowed_cidrs` | Additional CIDR blocks to allow (optional). Leave as an empty list if not needed. | `[]` |
| `assign_public_ip` | Whether to assign a public IP address to the Aggregators. If you leave this as `false`, you must use a bastion host for the deployment. The instructions in these pages assume you are setting this value to `true`. | `false` |
| `user_data_file` | Path to the Cloud-Init user-data file, used for license handling. Do not edit. | `./user-data.yaml` |
| `shared_secret` | The secret key used when Aggregators register with the Central Manager. Must match the value you used when deploying the Central Manager. | `guard` |
| `central_manager_ip` | The private IP address of the Central Manager. Use the private IP address here even if you are assigning public IP addresses to the Aggregators. | `10.0.12.37` |
| `central_manager_public_dns` | The public IP address (or DNS hostname) of the Central Manager created in [Step 4](step04.md). This is the address used by Terraform to connect to the Central Manager when registering the Aggregators. | `44.198.175.80` |
| `license_base` | Base license for the Aggregators. Obtain this from your IBM Guardium administrator. | *(long encoded string — obtain from your administrator)* |
| `license_append` | Append license for the Aggregators. Obtain this from your IBM Guardium administrator. | *(long encoded string — obtain from your administrator)* |
| `domain` | Domain name for the GDP appliance. This is site-specific. | `corp.mycompany.local` |
| `timezone` | Timezone for the GDP appliance, in [tz database](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) format. | `America/New_York` |
| `resolver1` / `resolver2` | Primary and secondary DNS resolvers for the GDP appliance. These are site-specific. | `8.8.4.4` / `1.1.1.1` |
| `tags` | A map of AWS tags to apply to the created resources. These are site-specific and used for cost tracking and organisation. | `{ Environment = "dev", Project = "GuardiumGDP", Owner = "you@example.com", Role = "Aggregator" }` |
| `data_import_cron_string` | Cron expression that controls when the Aggregators pull data from their Collectors. The default value runs the import daily at 04:00. | `0 0 4 * * ? *` |

> **Note (Customising policies and backup CM):** Before running Terraform, you can edit `modules/aggregator/configure_guardium.expect` to change which Aggregator will be designated as the backup Central Manager, and to change which policy will be installed on the Aggregators.

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
| `instance_name_prefix` | Prefix for the instance name tag. The instance number is appended automatically (e.g. `guard-agg` produces `guard-agg01`, `guard-agg02`, etc.). | `guard-agg` |
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

> **Warning:** If there are errors, stop, fix the issue, and run `terraform apply -auto-approve` again. Do not proceed to the next step with a failed deployment.

When the script finishes successfully it prints details about the provisioned instances, including their security group ID and both internal and external IP addresses. **Record these values** — you will need them in the next step.

## Verify the Aggregator deployment

### Connect to an Aggregator

Connect to one of the Aggregators in a web browser using its public IP address (from the Terraform output or the AWS Console):

```
https://ip-address:8443
```

Log in using:

- **User:** `admin`
- **Password:** the same password as the Central Manager

Once logged in, verify that the expected policy is installed and that the data import settings are correct (navigate to **Setup › Tools and Views › Data Import/Export**). Note that different Aggregators may show different target Collectors in their data import configuration.

### Verify registration on the Central Manager

Connect to the Central Manager (as in [Step 4](step04.md)) and navigate to **Setup › Central Management**. Confirm that all Aggregators appear in the central management list and that one of them is designated as a backup Central Manager.

> **Tip:** Proceed to [Step 6: Deploy the Collectors](step06.md).
