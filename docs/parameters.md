## Parameters used by the Terraform process

This document lists the parameters you must enter before running the Terraform process to install GDP appliances.

The parameters are grouped by subject. In general, you will only have to set them up once, and then you can use the process multiple times, as long as you destroy the existing instance before creating a new one.

All parameters should be edited in the file terraform.tfvars under these directories:
* examples/central-manager
* examples/aggregator
* examples/collector

### AWS-related

> **_These are all critical parameters. You must verify that you have the correct values in order for the process to work correctly. If you are unsure about the AWS configuration, check with your AWS administrator._**

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

### GDP-related

> **_These parameters are less critical. You can generally accept the defaults if you do not have a specific need to change them._**

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

