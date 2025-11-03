# Create resource group to hold all resources
resource "azurerm_resource_group" "rg" {
    name = "${random_pet.prefix.id}-rg"
    location = var.location
  
}

# Create Virtual Network for VM
resource "azurerm_virtual_network" "my_terraform_network" {
  name = "${random_pet.prefix.id}-vnet"
    address_space = [ "10.0.0.0/16" ]
    resource_group_name = azurerm_resource_group.rg.name
    location = azurerm_resource_group.rg.location
}

# Create subnet inside the virtual network
resource "azurerm_subnet" "my_terraform_subnet" {
    name = "${random_pet.prefix.id}-subnet"
    resource_group_name = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.my_terraform_network.name
    address_prefixes = [ "10.0.1.0/24" ]

}

# Create static public IP address for VM
resource "azurerm_public_ip" "my_terraform_public_ip" {
  name = "${random_pet.prefix.id}-public-ip"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method = "Static"
  sku = "Standard"

}

# Create firewall
resource "azurerm_network_security_group" "my_terraform_nsg" {
  name = "${random_pet.prefix.id}-nsg"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH" 
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"    
    source_port_range          = "*"
    destination_port_range     = "22" 
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "web"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}

# Create virtual NIC for VM
resource "azurerm_network_interface" "my_terraform_nic" {
  name = "${random_pet.prefix.id}-nic"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name = "my_nic_configuration"
    subnet_id = azurerm_subnet.my_terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.my_terraform_public_ip.id
  }

}


# Connecting firewall to the NIC
resource "azurerm_network_interface_security_group_association" "my_nsg_nic_assoc" {
  network_interface_id      = azurerm_network_interface.my_terraform_nic.id
  network_security_group_id = azurerm_network_security_group.my_terraform_nsg.id
}

# Create Linux VM
resource "azurerm_linux_virtual_machine" "my_vm_machine" {
# This name should match the vm name in the MAKEFILE
  name                  = "dev-vm"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_B1s" 
  admin_username        = var.admin_username

  identity {
    type = "SystemAssigned"
  }
  
  network_interface_ids = [
    azurerm_network_interface.my_terraform_nic.id,
  ]

  # SSK Key authentication
  admin_ssh_key {
    username = var.admin_username
    public_key = var.admin_public_key
  }

  os_disk {
    name = "myOsDisk"
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # Defines the VM image to use (Ubuntu 22.04 LTS)
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# Generates a random name (e.g., "dev-vm-blue-pony")
resource "random_pet" "prefix" {
  prefix = var.prefix
  length = 1
}

resource "random_string" "acr_name" {
  length  = 5
  lower   = true
  numeric = false
  special = false
  upper   = false
}

resource "azurerm_container_registry" "my_acr" {
  name                = "${random_string.acr_name.result}registry" 
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard"
  admin_enabled       = false 
}

data "azurerm_client_config" "current" {}


resource "azurerm_role_assignment" "acr_pull_role_for_vm" {
  principal_id         = azurerm_linux_virtual_machine.my_vm_machine.identity[0].principal_id
  scope                = azurerm_container_registry.my_acr.id
  role_definition_name = "AcrPull"
}



resource "github_actions_secret" "vm_ip" {
  repository       = "bid-assist"
  secret_name      = "VM_IP"
  plaintext_value  = azurerm_public_ip.my_terraform_public_ip.ip_address
}

resource "github_actions_secret" "acr_name" {
  repository       = "bid-assist"
  secret_name      = "ACR_NAME"
  plaintext_value  = azurerm_container_registry.my_acr.name
}

resource "github_actions_secret" "acr_login_server" {
  repository       = "bid-assist"
  secret_name      = "ACR_LOGIN_SERVER"
  plaintext_value  = azurerm_container_registry.my_acr.login_server
}
