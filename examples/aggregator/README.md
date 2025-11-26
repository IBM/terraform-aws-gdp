# Create GDP Aggregator for AWS

## Introduction

Use this example to create a GDP Aggregator on AWS.

## Summary of process

The Terraform scripts should be run in this order.

1. Configure the Terraform process.
2. Run the Terraform process. This will create an Aggregator.

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

### 1.2 Prepare the connection to Central Manager

In AWS, locate the IP address of the Central Manager you want this Aggregator to be registered to.

Locate this file and edit it:

```
vi modules/aggregator/configure_guardium.expect
```

Scroll down towards the bottom of the file and locate this line.

`send "register management ip-address 8443\r"`

Replace ip-address with the IP address of the central manager. Then save the file.

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
* Password: `the instance ID from AWS`

You will be prompted to immediately change the password.
