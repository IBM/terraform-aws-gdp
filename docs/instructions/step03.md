# Step 3: Install Required Software

Install Terraform, expect, PowerShell, and the AWS CLI on the Linux VM; create an AWS key pair.

**Navigation:** [Index](index.md) · [1 · Setup Linux](step01.md) · [2 · Install software](step03.md) · [3 · Deploy CM](step04.md) · [4 · Deploy Aggregators](step05.md) · [5 · Deploy Collectors](step06.md)

---

## Prerequisites

- You are logged into the Linux VM as the user created in [Step 1](step01.md), in your working directory.
- An **AWS Access Key ID** and **AWS Secret Access Key**. If you do not have these, ask your AWS administrator.
- Access to the AWS Console in a web browser.

> **Warning:** If any installation step produces an error, stop and troubleshoot before continuing. A failure at this stage is likely to cause errors later when running Terraform.

> **Note (RHEL / CentOS / Fedora):** All commands below use `dnf` and `yum`, which are specific to Red Hat-based distributions. Adapt them for your distribution if necessary.

---

## Install yum-utils

```
sudo dnf install -y yum-utils
```

## Install Terraform

```
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo yum install -y terraform
```

## Install expect

The Terraform scripts use `expect` to automate interactive SSH sessions during appliance configuration.

```
sudo dnf install -y expect
```

## Install PowerShell

The Terraform scripts also call PowerShell scripts for certain configuration tasks.

```
sudo rm -f /etc/yum.repos.d/microsoft.repo
curl -o packages-microsoft-prod.rpm https://packages.microsoft.com/config/rhel/9/packages-microsoft-prod.rpm
sudo rpm -Uvh packages-microsoft-prod.rpm
sudo dnf update --nobest
```

> **Note:** `dnf update --nobest` may take several minutes and may prompt you to confirm packages to be installed. Answer `y` when prompted.

```
sudo dnf install powershell
```

> **Note:** This command may also prompt you to confirm packages. Answer `y` when prompted.

Verify that PowerShell is working.

```
pwsh
```

You should see the PowerShell version printed and a `PS ...>` prompt. Then exit.

```
exit
```

## Install the AWS CLI

First switch to your home directory, then run the installation.

```
cd
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws configure
```

You will be prompted for your **AWS Access Key ID** and **AWS Secret Access Key**. You will also be prompted for a default region and default output format — you can press Enter for both of those.

Return to your working directory when done.

```
cd ~/work
```

## Create an AWS EC2 key pair

You need an RSA key pair to allow Terraform to connect to the GDP instances it creates via SSH. The following steps show how to create one in the AWS Console.

> **Note:** The steps below reflect one common way to reach the AWS Console. Your organisation's AWS sign-in URL may differ.

1. Open the AWS Console in a web browser and navigate to the **EC2** dashboard.
2. In the left-side menu, locate the **Network & Security** section and click **Key Pairs**.
3. Click the orange **Create key pair** button (top-right of the page).
4. Fill in the form:
   - **Name:** a descriptive name (e.g. `mykeyname`). AWS will create a file named `mykeyname.pem`.
   - **Key pair type:** RSA
   - **Private key file format:** .pem
5. Click **Create key pair**. Your browser will prompt you to download the `.pem` file. Save it to a known location on your computer.
6. Copy the `.pem` file to your Linux VM's `~/.ssh/` directory. Run this command from your computer (replace the filename and hostname as appropriate).
   ```
   scp -O mykeyname.pem eli@terraformaws.dev.fyre.ibm.com:/home/eli/.ssh/
   ```
7. Also copy it to the `~/.ssh/` directory on your computer and set its permissions.
   ```
   cp mykeyname.pem ~/.ssh/
   chmod 400 ~/.ssh/mykeyname.pem
   ```
8. Back on the Linux VM, set the correct permissions there too.
   ```
   chmod 400 ~/.ssh/mykeyname.pem
   ```

## Default policy on the Central Manager

When Terraform provisions the Central Manager, it automatically installs a default policy on it. If you want to use a different policy, you can change which policy is installed by editing `modules/central-manager/configure_guardium.expect` before running Terraform.

## Note your IP addresses

You will need the IP addresses of your Linux VM and your computer later when configuring security group access in [Step 3: Deploy the Central Manager](step04.md).

On the Linux VM:

```
curl ifconfig.me
```

On your computer:

```
curl https://api.ipify.org
```

Save both IP addresses for use in the next step.

> **Tip:** Proceed to [Step 3: Deploy the Central Manager](step04.md).
