# Create GDP Aggregator for AWS

## Introduction

This module creates a GDP Aggregator on AWS.

## Parameters

All parameters must be modified in the terraform.tfvars file. See the [documentation](../../examples/aggregator/README.md) in the example for instructions.

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

### Parameter to register to Central Manager

See the [documentation](../../examples/aggregator/README.md) in the example for instructions how to setup the Aggregator so that it will register to a Central Manager you created earlier.
