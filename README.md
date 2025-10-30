# Terraform Azure VM Deployment

This project deploys a single Linux VM on Microsoft Azure using Terraform. It includes a `Makefile` to simplify operations.

## Prerequisites

Before you start, you should have the following tools installed:
1.  **Terraform** (~> 1.5)
2.  **Azure Account** (create free account with $200 credit)
3.  **Azure CLI** (`az`)
4.  **make**
5.  An **SSH Key Pair** (usually at `~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub`)
6.  **(Optional for `make vm-ssh`)** `jq` (a command-line JSON processor)

## 1. Setup & Authentication

This project uses a remote backend in Azure Storage and authenticates using a Service Principal.

### Step 1: Get the Code
Clone this repository to your local machine and cd into it.

```bash
git clone <repository-url>
cd <repository-name>
```

### Step 2: Create SSH Key
You need an SSH key to securely connect to the VM. If you don't have one, run this command. It will ask you for a passphrase/password, pressing Enter should be fine.

```bash
# This creates ~/.ssh/id_rsa (private) and ~/.ssh/id_rsa.pub (public)
ssh-keygen -t rsa -b 4096
```

### Step 3: Login to Azure & Create Service Principal
Use a Service Principal (security identity/robot account) for authentication to use Azure resources

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

Save this somewhere secure

#### Set credentials as environmental variables. 
* Note, this will be saved until you close the terminal (would have to re-enter after)

Run each line one by one, inserting the id from the output creating the service principal

```bash
export ARM_CLIENT_ID="<your-appId-from-above>"
export ARM_CLIENT_SECRET="<your-password-from-above>"
export ARM_TENANT_ID="<your-tenant-from-above>"
export ARM_SUBSCRIPTION_ID="<your-subscription-id>"
```


### Step 4: Create Terraform Backend
Terraform needs to store its state file. This is usually done locally but best practice is somewhere secure, like in your Azure Storage Account. This is a manual one time thing.

#### Choosing properties
 + Choose a unique name for your storage account (e.g. tfstate + your initials + date)
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
Open the versions.tf file and replace storage_account_name with your unique name you created.
```bash
    backend "azurerm" {
        storage_account_name = "YOUR_STORAGE_ACCOUNT_NAME"
        resource_group_name = "tfstate-rg"
        container_name = "tfstate"
        key = "dev/vm/terraform.tfstate"
    }
```

### Step 5: Configure Project Secrets
#### Copy the example secrets file
Theres an example secrets file, copy it, open secrets.auto.tfvars and copy your
```bash
cp secrets.auto.tfvars.example secrets.auto.tfvars
```

#### Open the secrets.auto.vars file and copy content of your public SSH key and paste it as the value for admin_public_key.
To get your public SSH key, run:
```bash
cat ~/.ssh/id_rsa.pub
```

To get your public IP, run:
```bash
curl ifconfig.me
```
(Or Googling "what is my ip")


Your secrets.auto.tfvars file should look something like this:
```bash
admin_public_key = "one long line starting with ssh-rsa"
my_public_ip     = "89.123.45.67"
```

### Step 6: Deploy VM
#### Initialise Terraform (using the Makefile file)
```bash
# Replace the names with the ones you created in Step 4
export AZ_BACKEND_RG="tfstate-rg"
export AZ_BACKEND_STORAGE_ACCOUNT="tfstateYOURNAME123"

make init
```

#### Build the VM and all networking
```bash
make apply
```

Your VM should be running, have a look in Azure

### If you run into resource provider registration errors

You can simply register the provider through the Azure command line. The example below will register the Microsft.Network resource provider.
```bash
az provider register --namespace Microsoft.Network
```

### Step 7: Connect and Clean Up
You can SSH into it:
```bash
make vm-ssh
```

To save money, you can stop the VM:
```bash
make vm-stop
```

To start the VM again:
```bash
make vm-start
```

When you are completely done, you can destroy ALL resources:
```bash
make destroy
```




# Installing Docker on the running VM
Assuming the first part worked, you'll have a VM running, but it's "empty." The next step is to run the Ansible playbook to configure it and install Docker.
## Step 1: Running the Provisioner
```bash
make provision
```
This single line does the following steps:
- Fetch the VM's IP address from Terraform.
- Wait 30 seconds for the VM to boot.
- Run the playbook.yml file on the VM.
- Install Docker and all prerequisites.

## Step 2: Verify and connect
Once thats done, you can verify Docker is now running 
### SSH into the VM
```bash
make vm-ssh
```

### Check the Docker version
Once inside the VM, check the version of Docker installed:
```bash
docker --version
```

### Run Docker without sudo
Proves your user was correctly added to the docker group
```bash
docker ps
```

### Hello World Docker image
You can also run this Docker image to make sure its all working (https://hub.docker.com/_/hello-world)
```bash
docker run hello-world
```

