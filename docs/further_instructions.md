## Further instructions for creating GDP appliances

This document adds details to the basic Terraform instructions.

## 1 Convert an aggregator to central manager

Once you have created an aggregator, you can convert it into a central manager by following these steps.

### 1.1 Store the license using CLI

Use SSH with your AWS PEM key to connect to the instance as the CLI user.

```
ssh -i path-to-PEM-file cli@ip-address
```

Once connected, store the GDP license with this command.

```
store license
```

You will be prompted for the license. Copy/paste it from where you have it saved. You will receive the message: License key has been applied.

### 1.2 Accept the license in GDP

Back in GDP, navigate to the License screen and accept the license.

### 1.3 Upgrade to Central Manager using CLI

Back in the CLI, enter this command:

```
store unit type manager
```

After this, the appliance will now be a central manager.

## 2 Connect an aggregator to a central manager

_Do this **before** running the Terraform script for the aggregator._

### 2.1 Get the IP address of the central manager

Connect to the AWS dashboard and locate the central manager you created earlier.

Click on its instance ID to see information about the machine.

Note its public IP address. If it does not have a public IP address, note its private IP address.

### 2.2 Edit the Expect file

Back in the Terraform repository files, locate this file and edit it.

```
vi modules/aggregator/configure_guardium.expect
```

Scroll down towards the bottom of the file and locate this line.

`send "register management ip-address 8443\r"`

Replace ip-address with the IP address of the central manager. Then save the file.

### 2.3 Run the Terraform process

You can now run the aggregator Terraform process.

## 3 Connect a collector to an aggregator

_Do this **before** running the Terraform script for the collector._

### 2.1 Get the IP address of the aggregator

Connect to the AWS dashboard and locate the aggregator you created earlier.

Click on its instance ID to see information about the machine.

Note its public IP address. If it does not have a public IP address, note its private IP address.

### 2.2 Edit the Expect file

Back in the Terraform repository files, locate this file and edit it.

```
vi modules/collector/configure_guardium.expect
```

Scroll down towards the bottom of the file and locate this line.

`send "store system aggregator ip-address\r"`

Replace ip-address with the IP address of the aggregator. Then save the file.

### 2.3 Run the Terraform process

You can now run the collector Terraform process.
