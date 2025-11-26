# Create GDP Central Manager for AWS

## Introduction

Use this example to create a GDP Central Manager on AWS.

## Summary of process

1. Configure the Terraform process.
2. Run the Terraform process. This will create an Aggregator that can be converted to a Central Manager.
3. Manually store and accept the GDP license, and convert the Aggregator to a Central Manager.

The instructions for running the Terraform scripts (steps 1 and 3) are below. Information about step 2 and connecting the appliances to each other are in the [further instructions document](../../docs/further_instructions.md).

## 1. Edit the parameters

Create the file terraform.tfvars based on the example file.

```
cp terraform.tfvars.example terraform.tfvars
```

Edit the file and enter the parameters for your installation.

```
vi terraform.tfvars
```

The parameters are documented in the file. For additional information about the parameters, see the [parameters document](../../docs/parameters.md).

After you have verified the parameters, save the file and exit the editor.

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

## 3. Connect to GDP

In AWS, locate the instance that was created by the Terraform process.

Note its **IP address** and its **instance ID**.

Connect to GDP via a browser with a URL like this:

```
https://ip-address:8443
```

You can then begin using GDP. In the login screen:
* User: `admin` 
* Password: `the instance ID from AWS` 

You will be prompted to immediately change the password.
