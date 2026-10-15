# Step 4: Deploy and Connect to the Central Manager

Configure `terraform.tfvars`, run Terraform to provision the Central Manager, then connect to it.

**Navigation:** [Index](index.md) · [1 · Setup Linux](step01.md) · [2 · Install software](step03.md) · [3 · Deploy CM](step04.md) · [4 · Deploy Aggregators](step05.md) · [5 · Deploy Collectors](step06.md)

---

## Prerequisites

- All required software is installed.
- You are logged into the Linux VM as your Terraform user, in your working directory.
- You have the AWS Console open in a web browser.

## Navigate to the example directory

```
cd terraform-aws-gdp/examples/central-manager/
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
| `region` | AWS region code where the Central Manager will be created. In the AWS Console, click the region name in the top-right corner and note the code from the drop-down list — use the code (e.g. `us-east-1`), not the location name. | `us-east-1` |
| `vpc_id` | ID of the VPC where the Central Manager will be created. In the AWS Console, navigate to **VPC › Your VPCs** and note the VPC ID (not the VPC name). | `vpc-0b88123d60e712fe2` |
| `subnet_id` | ID of the subnet within the VPC. From the VPC Dashboard, click **Subnets**, filter by your VPC, and note the Subnet ID (not the subnet name). | `subnet-0c82066180e40df72` |
| `ami_type` | Type of AMI being used. Use `legacy` for unit-type-specific AMIs (one AMI per appliance type). Use `unified` for a single AMI that can be configured as any appliance type. | `legacy` |
| `central_manager_ami_id` | AMI ID of the Central Manager image. In the EC2 Dashboard, click **AMI Catalog › My AMIs**, locate the Central Manager AMI you want to use, and copy its AMI ID (not the name). | `ami-0f3ceaf1844a82568` |
| `central_manager_instance_type` | AWS instance type for the Central Manager. In the EC2 Dashboard, click **Instance Types** and note the type code. | `m6i.2xlarge` |
| `key_name` | Name of the AWS key pair created in [Step 2](step03.md). This is the filename of the `.pem` file without the extension. | `mykeyname` |
| `pem_file_path` | Absolute path to the `.pem` file **on the Linux VM**. | `/home/eli/.ssh/mykeyname.pem` |
| `allowed_cidrs` | List of CIDR blocks that are allowed to access the Central Manager. Typically includes the VPC CIDR (so other appliances can communicate), plus the IP addresses of your Linux VM and your computer (noted in [Step 2](step03.md)). Use `/32` for individual host IPs. | `["10.0.0.0/16", "170.225.223.16/32", "147.236.177.70/32"]` |
| `custom_allowed_cidrs` | Additional CIDR blocks to allow (optional). Leave as an empty list if not needed. | `[]` |
| `instance_name_prefix` | Name prefix for the Central Manager instance. The instance number is appended automatically (e.g. `guard-cm` produces `guard-cm-01`). | `guard-cm` |
| `assign_public_ip` | Whether to assign a public IP address to the Central Manager. If you leave this as `false`, you must use a bastion host for the deployment. The instructions in these pages assume you are setting this value to `true`. | `false` |
| `user_data_file` | Path to the Cloud-Init user-data file, used for license handling. Do not change this value. | `./user-data.yaml` |
| `shared_secret` | A secret word used when Aggregators and Collectors register with this Central Manager. Choose any value you want; you will need it again when deploying managed units. | `guard` |
| `license_base` | Base license for the Central Manager. Obtain this from your IBM Guardium administrator. Leave empty to skip automated license installation. | *(long encoded string — obtain from your administrator)* |
| `license_append` | Append license for the Central Manager. Obtain this from your IBM Guardium administrator. Leave empty to skip automated license installation. | *(long encoded string — obtain from your administrator)* |
| `domain` | Domain name for the GDP appliance. This is site-specific. | `corp.mycompany.local` |
| `timezone` | Timezone for the GDP appliance, in [tz database](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) format. | `America/New_York` |
| `resolver1` / `resolver2` | Primary and secondary DNS resolvers for the GDP appliance. These are site-specific. | `8.8.4.4` / `1.1.1.1` |
| `tags` | A map of AWS tags to apply to the created resources. These are site-specific and used for cost tracking and organisation. | `{ Environment = "dev", Project = "GuardiumGDP", Owner = "you@example.com", Role = "CentralManager" }` |

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
| `instance_name_prefix` | Prefix for the instance name tag. The instance number is appended automatically (e.g. `guard-cm` produces `guard-cm-01`). | `guard-cm` |
| `root_volume_size` | Size of the root EBS volume in GB. Minimum 1500 GB for a Central Manager. | `1500` |
| `root_volume_type` | EBS volume type. | `gp3` |
| `root_volume_delete_on_termination` | Whether the root volume is deleted when the instance is terminated. | `true` |

## Run Terraform

Once you have finished editing and saved `terraform.tfvars`, run the following commands.

```
terraform init -reconfigure
terraform plan
terraform apply -auto-approve
```

The plan will be displayed. The script will take several minutes to complete.

> **Warning:** If there are errors, stop, fix the issue, and run `terraform apply` again. Do not proceed to the next step with a failed deployment.

When the script finishes successfully it prints details about the provisioned instance, including the security group ID and both internal and external IP addresses. **Record these values** — you will need them below.

## Connect to the Central Manager

Access the GDP web console and CLI of the Central Manager you just created.

### Connecting in a web browser

To connect to the Central Manager in a web browser, type the following URL in the address bar, replacing `ip-address` with the public IP address of the Central Manager instance. To find the public IP address, either look at the output from the Terraform run, or find the instance in the AWS Console.

```
https://ip-address:8443
```

Log in using:

- **User:** `admin`
- **Password:** the instance ID of the CM instance (from the AWS Console)

You will be prompted to change the password.

### Connecting via SSH

To connect to the CLI user of the Central Manager via SSH, use the following command from your computer. Replace `path-to-pem-file` with the path to the `.pem` file you saved from AWS, and replace `ip-address` with the public IP address of the Central Manager.

```
ssh -i [path-to-pem-file] cli@[ip-address]
```

### Handle failed connections

If the connection does not work, this is probably because you did not enter your computer's IP address in the `allowed_cidrs` entry of `terraform.tfvars` earlier, or your computer's IP address has changed since then. You will need to add your computer's IP address to the inbound rules of the Central Manager's security group in the AWS Console.

1. Find the Central Manager instance in the AWS Console. Navigate to its **Security** tab and click on the security group.
2. On the security group page, click **Edit inbound rules** and add the following two rules:

   | Type | Port range | Source |
   |---|---|---|
   | Custom TCP | 8443 | Enter your computer's IP address, or choose **My IP** |
   | SSH | 22 | Enter your computer's IP address, or choose **My IP** |

3. Click **Save rules**. You should now be able to connect to the Central Manager.

> **Tip:** Proceed to [Step 5: Deploy the Aggregators](step05.md).
