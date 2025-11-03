# Terraform Azure CI/CD Pipeline Environment

This project deploys a complete, CI/CD-ready environment on Microsoft Azure. It uses **Terraform** to build the infrastructure (VM, Firewall, Container Registry) and **Ansible** to provision the VM (installing Docker, Azure CLI, and deploy keys).

The goal of this repository is to create a "target" environment. You can then point your own application's GitHub Actions pipeline at this environment to achieve fully automated, push-to-deploy CI/CD.

This guide is in three parts:
* **Part 1: Infrastructure Setup (This Repo)**: Deploy the VM and all supporting Azure infrastructure.
* **Part 2: VM Provisioning (This Repo)**: Configure the VM by installing Docker and other tools.
* **Part 3: Application Deployment (Your App Repo)**: A guide for connecting *your* application to this new infrastructure.


## Prerequisites

Before you start, you should have the following tools installed:
1.  **Terraform** (~> 1.5)
2.  **Azure Account** (create free account with $200 credit)
3.  **Azure CLI** (`az`)
4.  **Ansible** (for provisioning the VM)
5.  **make**
6.  An **SSH Key Pair** (usually at `~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub`)
7.  **(Optional for `make vm-ssh`)** `jq` (a command-line JSON processor)

## Part 1: Infrastructure Setup (This Repo)

This part creates all the Azure resources needed to host your application.


### Step 1: Get the Code
Clone this repository to your local machine and cd into it.

```bash
git clone <repository-url>
cd <repository-name>
```

### Step 2: Create SSH Key
You need **two** SSH key pairs: one for you to log in as an **Admin**, and one for GitHub Actions to log in as a **Deployer**. 

It will ask you for a passphrase/password, pressing Enter should be fine.

#### Create your Admin Key (if you don't have one):
```bash
# This creates ~/.ssh/id_rsa_azure (private) and ~/.ssh/id_rsa_azure.pub (public)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_azure
```

#### Create a Deploy Key for GitHub Actions:
```bash
# This creates ~/.ssh/github_deploy_key (private) and ~/.ssh/github_deploy_key.pub (public)
# The -N "" sets an empty passphrase, which is required for automation.
ssh-keygen -t rsa -b 4096 -f ~/.ssh/github_deploy_key -N ""
```


### Step 3: Login to Azure & Create Service Principal
This Service Principal (security identity/robot account) will be used by Terraform and GitHub Actions to manage resources.

#### Log into Azure account with terminal
```bash
az login
```
#### Set your default subscription
```bash
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

#### Create the Service Principal
```bash
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/YOUR_SUBSCRIPTION_ID"
```

This will output something like this:
```json
{
  "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "displayName": "azure-cli-2025-10-28-14-30-00",
  "password": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "tenant": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

**SAVE THE OUTPUT!** This is the **only time** you will see the password. You will need this for your GitHub Secrets later.


### Step 4: Create Terraform Backend
Terraform needs to store its state file. This is usually done locally but best practice is somewhere secure, like in your Azure Storage Account. This is a manual one time thing.

#### Choosing properties
 + **Choose a unique name** for your storage account (e.g. `tfstate` + your initials + date)
 + Resource Group Name (e.g. tfstate-rg)
 + Location (e.g. UKSouth)

Run these commands to create the backend resources
```bash
# 1. Create the resource group
az group create --name tfstate-rg --location "UK South"

# 2. Create the storage account (REPLACE THE NAME!)
az storage account create --name "tfstateYOURNAME123" --resource-group tfstate-rg --location "UK South" --sku Standard_LRS

# 3. Create the container
az storage container create --name tfstate --account-name "tfstateYOURNAME123"
```

#### Update the versions.tf file
Open the `versions.tf` file. This file should be configured to use the backed, bu tthe nams are passed in by the `Makefile`, so no hardcoding is needed. It should look like this:
```bash
    backend "azurerm" {
      # This block is intentionally empty.
      # 'make init' passes the configuration.
    }
```

### Step 5: Configure Project Secrets & Variables

#### Set credentials as environmental variables. 
* Note, this will be saved until you close the terminal (would have to re-enter after)
The `ARM_` variables are for Terraform to log in. The `AZ_BACKEND_` variables are for `make init` to find your new backend. 

Run each line one by one, inserting the id from the output creating the service principal

```bash
# Get these from Step 3 (Service Principal)
export ARM_CLIENT_ID="<your-appId>"
export ARM_CLIENT_SECRET="<your-password>"
export ARM_TENANT_ID="<your-tenant>"
export ARM_SUBSCRIPTION_ID="<your-subscription-id>"

# Get these from Step 4 (Backend)
export AZ_BACKEND_RG="tfstate-rg"
export AZ_BACKEND_STORAGE_ACCOUNT="tfstateYOURNAME123"
```

#### Create your Secrets File
Company the example file. This file is listed in `.gitignore` and will never be commited to Git
```bash
cp secrets.auto.tfvars.example secrets.auto.tfvars
```

#### Open the secrets.auto.vars file
Fill it with the 3 reqired values: 

- To get `admin_public_key`: `cat ~/.ssh/id_rsa_azure.pub` (Your admin key)
- To get `my_public_ip`: `curl ifconfig.me` (Your current home/office IP)
- To get `deploy_public_key`: `cat ~/.ssh/github_deploy_key.pub` (The GitHub key)


Your secrets.auto.tfvars file should look something like this:
```bash
admin_public_key = "ssh-rsa AAAA...[your ADMIN key]..."
my_public_ip     = "89.123.45.67"
deploy_public_key = "ssh-rsa AAAA...[your GITHUB key]..."
```

### Step 6: Deploy Infrastructure
#### Initialise Terraform (using the Makefile file)
```bash
make init
```

#### Build infrastructure
```bash
make apply
```

### If you run into Resource Provider Registration Rrrors
You can simply register the provider through the Azure command line. The example below will register the Microsft.Network resource provider.
```bash
az provider register --namespace Microsoft.Network
```

The above commands runs Terraform and builds:
- A new Resource Group
- A Virtual Network and Subnet
- A secure Network Security Group (Firewall)
- A Public IP Address
- An **Azure Container Registry (ACR)**
- A **Linux Virtual Machine (VM)** with a **Managed Identity**
- **Role Assignments** to allow your VM to pull from the ACR


## Part 2: VM Provisioning(This Repo)
After `make apply` is successful, the VM will be running, but it's "empty". The enxt step is to provision it with Ansible to install all the software it needs. 

### Step 1: Run the Provisioner
This will configure your new VM. 
```bash
make provision
```
Have a look at the `Makefile` and `playbook.yml` to see the command used, but it does the following: 
1. Waits for the VM's SSH port to be ready.
2. Installs all system updates.
3. Installs Docker, Docker Compose, and all prerequisites.
4. Adds your `azureuser` to the `docker` group (so you don't need `sudo`).
5. Installs the **Azure CLI** onto the VM (for Managed Identity login).
6. Securely adds your **GitHub Deploy Key** to the VM's `authorized_keys`.

### Step 2: Verify and Connect
Once `make provision` is done, you can verify everything is working by:

#### SSH'ing into the VM:
```bash
make vm-ssh
```

### Check Docker (no sudo)
Once inside the VM, check the version of Docker installed and your user has the right permissions:
```bash
docker ps
```

### Check Azure CLI
This proves the **Azure CL**I is installed
```bash
az --version
```

### Hello World Docker image (Optional)
You can also run this Docker image to make sure its all working (https://hub.docker.com/_/hello-world)
```bash
docker run hello-world
```





## Part 3: VM Provisioning (Your App Repo)
The infrastructure is now ready. This section allows you to configure **your own application repository** to deploy to this environment.

### **Method 1: Full CI/CD**
This uses **GitHub Actions** to automatically build a **private Docker image** and deploy it when you `git push`.

#### **Step 1: Automate Your GitHub Secrets**
To avoid manually updating GitHub secrets every time you `make destroy`, you can have Terraform manage them for you.

1. **Create a GitHub Personal Access Token (PAT):**
+ Go to GitHub **Settings > Developer settings > Personal access tokens > Tokens (classic).**
+ Click **Generate new token (classic)**.
+ Give it a **Note** (e.g., ``terraform-infra-manager``).
+ Set **Expiration** (e.g., 90 days).
+ Check the ``repo`` scope.
+ Click **Generate token** and **copy the token**.

2. **Set the Token Locally:**
+ In your **infrastructure repo** terminal, set this environment variable:
```bash
export GITHUB_TOKEN="ghp_YOUR_NEW_TOKEN_HERE"
```

3. **Configure Terraform**
+ Add the GitHub provider to the `versions.tf` and the `github_actions_secret` resources to the `main.tf` file.
+ This tells Terraform to find your application repo and update its secrets
+ Add to `versions.tf`:
```bash
terraform {
  # ...
  required_providers {
    # ... (azurerm provider) ...
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}
provider "github" {}
```

+ Add to `main.tf`:
```bash
# This resource will create/update secrets in your *app* repo
resource "github_actions_secret" "vm_ip" {
  repository       = "your-app-repo-name" # <-- CHANGE THIS
  secret_name      = "VM_IP"
  plaintext_value  = azurerm_public_ip.my_terraform_public_ip.ip_address
}

resource "github_actions_secret" "acr_name" {
  repository       = "your-app-repo-name" # <-- CHANGE THIS
  secret_name      = "ACR_NAME"
  plaintext_value  = azurerm_container_registry.my_acr.name
}

resource "github_actions_secret" "acr_login_server" {
  repository       = "your-app-repo-name" # <-- CHANGE THIS
  secret_name      = "ACR_LOGIN_SERVER"
  plaintext_value  = azurerm_container_registry.my_acr.login_server
}
```

4. **Run** `terraform init -upgrade` to install the new `github` provider **
5. **Run** `make apply` to create your infrastructure and update your application repo's GitHub Secrets automatically. 


#### **Step 2: Set Manual GitHub Secrets**
You still need to set the secrets that don't change, as well as your new deploy key. Do this in your **application repo's** GitHub settings (**Settings > Secrets and variables > Actions**):

- `AZURE_CLIENT_ID`: Your Service Principal `appId` (from Part 1, Step 3).
- `AZURE_CLIENT_SECRET`: Your Service Principal `password`.
- `AZURE_TENANT_ID`: Your Service Principal `tenant`.
- `AZURE_SUBSCRIPTION_ID`: Your Subscription ID.
- `DEPLOY_KEY_PRIVATE`: The **private key** file contents (run `cat ~/.ssh/github_deploy_key`).
- `VM_USER`: `azureuser` (or your `admin_username`).
- `GH_PAT`: (Optional, if your app repo is private) A GitHub PAT with `repo` scope to clone.


#### **Step 3: Configure your Application's Compose Files**
1. **Update** `compose.yml` (or `docker-compose.yml`): Tell your app's `web` service to get its image name from a variable/
```bash
services:
  web:
    build: .
    # This tells it to use the pipeline's image tag
    image: ${IMAGE_NAME:-my-app-web:local}
    # ...
```

2. **Create** `compose.prod.yml`: This file disables local volumes, forcing the VM to use the pre-built code inside the image.
```bash
services:
  web:
    # This override disables the volume mount
    volumes: []
```

#### Step 4: Create the CI/CD Pipeline
In your **application repo**, create `.github/workflows/ci.yml`. This file defines the full automated workflow.
```bash
name: CI/CD - Build, Push to ACR, and Deploy to VM

on:
  push:
    branches: [ "main" ] # Triggers on push to main

jobs:
  #--------------------------------------
  # JOB 1: Continuous Integration (CI)
  #--------------------------------------
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - name: "Checkout Code"
        uses: actions/checkout@v4

      # (Optional) Add your test steps here
      # - name: "Run Tests"
      #   run: docker compose run web your-test-command

      - name: "Log in to Azure"
        uses: azure/login@v1
        with:
          creds: >
            {
              "clientId": "${{ secrets.AZURE_CLIENT_ID }}",
              "clientSecret": "${{ secrets.AZURE_CLIENT_SECRET }}",
              "tenantId": "${{ secrets.AZURE_TENANT_ID }}",
              "subscriptionId": "${{ secrets.AZURE_SUBSCRIPTION_ID }}"
            }

      - name: "Log in to Azure Container Registry"
        uses: azure/docker-login@v1
        with:
          login-server: ${{ secrets.ACR_LOGIN_SERVER }}
          username: ${{ secrets.AZURE_CLIENT_ID }}
          password: ${{ secrets.AZURE_CLIENT_SECRET }}

      - name: "Build and Push Docker image"
        run: |
          export IMAGE_NAME=${{ secrets.ACR_LOGIN_SERVER }}/your-app-name:latest
          docker compose build
          docker compose push
  
  #--------------------------------------
  # JOB 2: Continuous Deployment (CD)
  #--------------------------------------
  deploy-to-vm:
    needs: build-and-push # Waits for Job 1 to succeed
    runs-on: ubuntu-latest
    
    steps:
      - name: "SSH and Deploy to VM"
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.VM_IP }}
          username: ${{ secrets.VM_USER }}
          key: ${{ secrets.DEPLOY_KEY_PRIVATE }}
          script: |
            # Set variables for the VM
            export IMAGE_NAME=${{ secrets.ACR_LOGIN_SERVER }}/your-app-name:latest
            export APP_DIR="/home/${{ secrets.VM_USER }}/my-app-folder"
            export GIT_REPO_URL="[https://github.com/your-username/your-app-repo.git](https://github.com/your-username/your-app-repo.git)"
            
            # 1. Get latest compose files
            if [ -d "$APP_DIR" ]; then
              cd $APP_DIR
              git pull
            else
              git clone $GIT_REPO_URL $APP_DIR
              cd $APP_DIR
            fi
            
            # 2. Log in using the VM's own Identity
            az login --identity
            
            # 3. Log Docker into ACR
            az acr login --name ${{ secrets.ACR_NAME }}
            
            # 4. Pull the new image from ACR
            docker compose pull
            
            # 5. Restart stack with the new image
            docker compose -f compose.yml -f compose.prod.yml up -d
```

(Remember to change `your-app-name` and the `GIT_REPO_URL` in the file above!)

Now, every `git push` to your app's `main` branch will automatically build and deploy it to your VM.


### **Method 2: The Simple Way (Public Docker Hub Image)**

If your application is just a public image (like `nginx` or `wordpress`), the process is much simpler. You don't need a CI/CD pipeline, an ACR, or any of the application-side setup.
1. **SSH into your VM:**
```bash
make vm-ssh
```

2. **Create a `docker-compose.yml` file** on the VM:
```bash
# Make a new directory for your app
mkdir my-public-app
cd my-public-app

# Create the compose file
nano compose.yml
```

3. Paste the configuration for your public app. For example, to run Nginx:
```bash
# In compose.yml on the VM
services:
  web:
    image: "nginx:latest" # Pulls directly from Docker Hub
    ports:
      - "80:80" # Maps VM port 80 to container port 80
```

4. Run it:
```bash
docker compose up -d
```

Your app is now running. This is simpler but is a manual process and doesn't use your own code.


## Appendix: Makefile Command Reference
All commands are run from the **Infrastructure Repo** (Part 1).
- `make all`: **(Recommended)** Builds infrastructure (`apply`) and then provisions it (provision).
- `make apply`: Builds or updates the infrastructure (VM, ACR, etc.).
- `make provision`: Runs the Ansible playbook to install Docker, Azure CLI, etc.
- `make destroy`: **Deletes all resources** (VM, VNet, IP, ACR).
- `make vm-stop`: Stops (de-allocates) the VM to save money.
- `make vm-start`: Starts the VM up again.
- `make vm-ssh`: Helper to SSH into the running VM.
- `make init`: Initialises the Terraform backend (run this first).
- `make validate`: Validates Terraform syntax.
- `make plan`: Shows what changes Terraform will make.
- `make help`: Displays a list of all available commands.