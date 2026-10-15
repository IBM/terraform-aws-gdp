# Step 2: Set up the Linux VM

Create a user, configure Git, set up GitHub SSH access, and clone the Terraform repository.

**Navigation:** [Index](index.md) · [1 · Create VM](step01.md) · [2 · Set up VM](step02.md) · [3 · Install software](step03.md) · [4 · Deploy CM](step04.md) · [5 · Deploy Aggregators](step05.md) · [6 · Deploy Collectors](step06.md)

---

## Prerequisites

- Root access to the Linux VM (from [Step 1](step01.md) or your own machine).
- A GitHub account at [github.com](https://github.com).

> **Note:** If you already have a non-root user with `sudo` access on your Linux machine, skip the user-creation sub-section below and continue from **"Configure Git"**.

---

## Create a user

Open a terminal on your computer and connect to the Linux VM as root. Substitute the hostname of your VM as appropriate.

```
ssh root@terraformaws.dev.fyre.ibm.com
```

On the Linux VM, create a user, set a password, and add them to the `wheel` group for `sudo` access.

```
useradd eli
passwd eli
usermod -aG wheel eli
```

Exit back to your computer.

```
exit
```

## Verify sudo access (optional)

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

## Create a working directory

```
mkdir work
cd work
```

## Configure Git

Replace the name and email with your own details.

```
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

## Create an SSH key for GitHub

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

## Add the public key to GitHub

1. In a web browser, go to [github.com](https://github.com) and sign in.
2. Click your profile picture (top-right) and choose **Settings**.
3. In the left-side menu, click **SSH and GPG keys**.
4. Click **New SSH key**.
5. Give the key a descriptive title (e.g. *terraformaws VM*), paste the public key you copied into the **Key** field, and click **Add SSH key**.

## Test GitHub access

Back on the Linux VM, verify the key works.

```
ssh -T git@github.com
```

You should see a message confirming you have been successfully authenticated. If you do not, troubleshoot before continuing.

## Clone the Terraform repository

```
git clone git@github.com:IBM/terraform-aws-gdp.git
```

This creates a `terraform-aws-gdp` directory inside your working directory.

> **Tip:** Proceed to [Step 3: Install required software](step03.md).
