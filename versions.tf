terraform {
    # Ensure Terraform version is 1.5 or higher, but below 2.0
    required_version = "~> 1.5"

    # Configuration needs Azure Resource Manager (azurerm) from Hashicorp
    # Pinning the version to 3.0 to prevent breaking changes
    required_providers {
      azurerm = {
        source = "hashicorp/azurerm"
        version = "~> 3.0"
      }
    }

    # Configure backend to store the states remotely in Azure. 
    # With the Azure Storage Account Name, inside the Resource Group, in a specific container, with a sepcific filename
    backend "azurerm" {}
}

# This initialises the AzureRM provider. Features block is empty but is required, even if no special features are configured 
provider "azurerm" {
  features {}

  skip_provider_registration = true
}