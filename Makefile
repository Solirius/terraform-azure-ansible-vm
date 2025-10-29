# Get the Resource Group name from terraform output
RG_NAME := $(shell terraform output -raw resource_group_name 2>/dev/null)
VM_NAME = "dev-vm"


# These words/files explicitly tell Make they're not associated with files. E.g. if you run Make init, it will run as expected even if you do have a file names init
.PHONY: all init validate fmt plan apply destroy vm-stop vm-start vm-ssh help

all: apply


# Initializes Terraform, pulling providers and configuring the backend.
init:
	@echo "Terraform initializing..."
	@terraform init \
		-backend-config="resource_group_name=$(AZ_BACKEND_RG)" \
		-backend-config="storage_account_name=$(AZ_BACKEND_STORAGE_ACCOUNT)" \
		-backend-config="container_name=tfstate" \
		-backend-config="key=dev/vm/terraform.tfstate"

# Validates the syntax of the Terraform files.
validate:
	@echo "Validating Terraform files..."
	@terraform validate

# Formats the Terraform files for readability.
fmt:
	@echo "Formatting Terraform files..."
	@terraform fmt

# Creates an execution plan.
plan:
	@echo "Running Terraform plan..."
	@terraform plan

# Creates or updates the infrastructure.
# -auto-approve skips the 'yes' prompt, good for automation.
apply:
	@echo "Applying Terraform configuration..."
	@terraform apply -auto-approve

# Destroys all infrastructure managed by this configuration.
# -auto-approve skips the 'yes' prompt.
destroy:
	@echo "Destroying all infrastructure..."
	@terraform destroy -auto-approve



# --- VM Power Management (Uses Azure CLI) ---

# Stops (de-allocates) the VM to save money. Infrastructure remains.
vm-stop:
	@echo "Stopping (de-allocating) VM: $(VM_NAME) in RG: $(RG_NAME)..."
	@az vm deallocate --resource-group $(RG_NAME) --name $(VM_NAME)

# Starts the VM.
vm-start:
	@echo "Starting VM: $(VM_NAME) in RG: $(RG_NAME)..."
	@az vm start --resource-group $(RG_NAME) --name $(VM_NAME)

# Helper to SSH into the VM (requires 'jq' to be installed).
vm-ssh:
	@echo "Connecting to VM..."
	@ssh $(shell terraform output -json ssh_command | jq -r 'split(" ")[1:] | @sh')

help:
	@echo ""
	@echo "Available 'make' commands:"
	@echo "  make init      - Initialize Terraform (backend and providers)."
	@echo "  make validate  - Validate Terraform syntax."
	@echo "  make fmt       - Format Terraform code."
	@echo "  make plan      - Show a plan of changes to be made."
	@echo "  make apply     - Build or update the infrastructure."
	@echo "  make destroy   - Destroy all infrastructure."
	@echo "  make vm-stop   - Stop (de-allocate) the VM to save costs."
	@echo "  make vm-start  - Start the VM."
	@echo "  make vm-ssh    - SSH into the running VM."
	@echo ""