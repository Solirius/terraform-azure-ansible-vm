# Packer, Ansible & Terraform

This project automates and creates a VM Image on Azure using **Packer** and **Ansible**, and then deploys a cluster of Virtual Machines using that image with **Terraform**.


## Prerequisites

You will need the following tools isntalled on your machine (if you haven't already)

```bash
# Install HashiCorp Tap
brew tap hashicorp/tap

# Install Packer and Terraform
brew install hashicorp/tap/packer
brew install hashicorp/tap/terraform

# Install Azure CLI
brew install azure-cli

# Install Ansible
brew install ansible
```


## Azure Authenticaiton and Setup
Create a Service Principal to allow Packer to build images and Terraform to create temporary resources
### Create Service Principal
```bash
# Log in to Azure
az login

# This grants "Contributor" access to your subscription
az ad sp create-for-rbac \
  --name "packer-builder" \
  --role "Contributor" \
  --scopes "/subscriptions/$(az account show --query id -o tsv)"
```

### Export Environment Variables
The output of the previous command with give your some keys (`appId`, `password`, and `tenant`). Use those with the placeholders below:

```bash
export PACKER_VAR_client_id="<YOUR_APP_ID>"
export PACKER_VAR_client_secret="<YOUR_PASSWORD>"
export PACKER_VAR_tenant_id="<YOUR_TENANT_ID>"
export PACKER_VAR_subscription_id="$(az account show --query id -o tsv)"

# Define Resource Group names
export PACKER_VAR_resource_group="rg-packer-builds"      # Temp group for Packer
export PACKER_VAR_image_resource_group="rg-images"       # Storage for final images
```


## Create Resource Groups
Create resource group to host the build artifacts and the final image
```bash
# Group for temporary build resources (Packer will use this)
az group create --name rg-packer-builds --location ukwest

# Group to store the final Image
az group create --name rg-images --location ukwest
```

## Build Image (using Packer)
### Initialise Packer
```bash
packer init linux_ubuntu.pkr.hcl
```

### Validate Packer code (optional)
```bash
packer init linux_ubuntu.pkr.hcl
```

### Format Packer code (optional)
```bash
packer fmt linux_ubuntu.pkr.hcl
```


### Build Packer
This creates a VM, runs Ansible, and captures the image.
```bash
packer build linux_ubuntu.pkr.hcl
```

## Deploy Infrastructure
### SSH Key Setup
Terraform configuration requires an SSH public key to inject into the VMs. If you don't have one, generate it:
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

### Deploy
#### Initialise Terraform
```bash
terraform init
```

#### Plan deployment 
```bash
terraform plan
```

#### Apply Configuration
```bash
terraform apply
# Type 'yes'
```

## Verification
Once completed, it will output the public IP addresses of the new VMs.
E.g.
```bash
vm_public_ips = [
  "20.254.241.66",
  "20.162.112.111",
  "20.254.233.14",
]
```

### Test Connectivity
Pick one of the IPs and SSH into it:
```bash
ssh adminuser@20.254.241.66 # For example
```

### Check Docker
Verify Ansible successfully installed Docker during the build process
```bash
docker --version
sudo systemctl status docker
```

## Cleanup
When done, destroy resources
1. Delete Terraform resources (VMs, NICs, IPs)
```bash
terraform destroy
# Type 'yes' to confirm
```

2. Delete Image and Resource Groups (Terraform didn't manage `rg-images` group, must delete it manually)
```bash
az group delete --name rg-images --yes --no-wait
az group delete --name rg-packer-builds --yes --no-wait
```
