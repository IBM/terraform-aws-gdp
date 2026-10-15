# Step 1: Set up Linux

Provision a Linux machine, create a user, set up GitHub access, and clone the Terraform repository.

**Navigation:** [Index](index.md) · [1 · Setup Linux](step01.md) · [2 · Install software](step03.md) · [3 · Deploy CM](step04.md) · [4 · Deploy Aggregators](step05.md) · [5 · Deploy Collectors](step06.md)

---

## Overview

You need a Linux machine to run the Terraform scripts. This step covers creating one using IBM Fyre and then configuring it. If you already have a suitable Linux machine available, skip to the [Configure the Linux machine](#part-b-configure-the-linux-machine) section below.

> **Note:** These instructions were tested on Red Hat Enterprise Linux 9.6. The software installation steps in [Step 2: Install required software](step03.md) use `dnf`/`yum` and are specific to RHEL/CentOS/Fedora. If you use a different distribution, you will need to adapt those commands accordingly.

---

## Part A: Create a Linux VM on IBM Fyre

### Prerequisites

- Access to [IBM Fyre](https://fyre.ibm.com/).

### Steps

1. Go to [https://fyre.ibm.com/](https://fyre.ibm.com/) and sign in with your IBM W3 ID.
2. Click **Development** at the top of the screen.
3. Click the **Build VM/OCP** button.
4. On the build screen, confirm that **Advance** is selected at the top, then fill in the form as follows:
   - **Product Group:** Guardium Data Protection-ILSL
   - **Site:** SVL (or your preferred site)
   - **Platform:** x
   - **OS:** Red Hat 9.6
   - **Add To DNS:** checked
   - **Name:** a descriptive name for this VM (e.g. `terraformaws`)
   - **Add Public IP:** checked
   - **Quantity:** 1, **CPU:** 2, **Memory:** 8 GB
5. Click **Add**, then click **Build**.
6. Click **VMs** at the top of the screen and wait for the VM to finish building. The status indicator will change when it is ready.
7. Click the **⋯** menu at the bottom-left of your VM's card and choose **Change VM Password**. Set a strong root password and note it for the next step.

---

## Part B: Configure the Linux machine

### Prerequisites

- Root access to the Linux machine (or a user with `sudo` access).
- A GitHub account at [github.com](https://github.com).

> **Note:** If you already have a non-root user with `sudo` access on your Linux machine, skip the "Create a user" sub-section below and continue from **"Create a working directory"**.

### Create a user

Open a terminal on your computer and connect to the Linux machine as root. Substitute the hostname of your machine as appropriate.

```
ssh root@terraformaws.dev.fyre.ibm.com
```

On the Linux machine, create a user, set a password, and add them to the `wheel` group for `sudo` access.

```
useradd eli
passwd eli
usermod -aG wheel eli
```

Exit back to your computer.

```
exit
```

### Verify sudo access (optional)

Reconnect as the new user and confirm sudo access.

```
ssh eli@terraformaws.dev.fyre.ibm.com
```

```
sudo -l
```

You should see output ending with a line like:

```
User eli may run the following commands on terraformaws:
    (ALL) ALL
```

### Create a working directory

```
mkdir work
cd work
```

### Configure Git

Replace the name and email with your own details.

```
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

### Create an SSH key for GitHub

Use the same email address you use to log into GitHub.

```
ssh-keygen -t ed25519 -C "you@example.com"
```

When prompted for a file name, you can press Enter to accept the default (`~/.ssh/id_ed25519`), or enter a custom path such as `~/.ssh/yourname_ed25519`. If you use a custom name, use the **absolute path** (e.g. `/home/eli/.ssh/yourname_ed25519`) — if you enter only a filename without a path it will be saved in the current directory.

Start the SSH agent and add the key.

```
eval "$(ssh-agent -s)"
chmod 600 ~/.ssh/yourname_ed25519
chmod 644 ~/.ssh/yourname_ed25519.pub
ssh-add ~/.ssh/yourname_ed25519
```

Print the public key to the screen so you can copy it.

```
cat ~/.ssh/yourname_ed25519.pub
```

### Add the public key to GitHub

1. In a web browser, go to [github.com](https://github.com) and sign in.
2. Click your profile picture (top-right) and choose **Settings**.
3. In the left-side menu, click **SSH and GPG keys**.
4. Click **New SSH key**.
5. Give the key a descriptive title (e.g. *terraformaws VM*), paste the public key you copied into the **Key** field, and click **Add SSH key**.

### Test GitHub access

Back on the Linux machine, verify the key works.

```
ssh -T git@github.com
```

You should see a message confirming you have been successfully authenticated. If you do not, troubleshoot before continuing.

### Clone the Terraform repository

```
git clone git@github.com:IBM/terraform-aws-gdp.git
```

This creates a `terraform-aws-gdp` directory inside your working directory.

> **Tip:** Proceed to [Step 2: Install required software](step03.md).
