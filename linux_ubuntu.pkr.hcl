packer {
  required_version = ">= 1.8.0"

  required_plugins {
    azure = {
      version = ">= 2.0.0"
      source  = "github.com/hashicorp/azure"
    }
    ansible = {
      version = "~> 1"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

variable "client_id" {
  type      = string
  sensitive = true
}

variable "client_secret" {
  type      = string
  sensitive = true
}

variable "subscription_id" {
  type      = string
  sensitive = true
}

variable "tenant_id" {
  type      = string
  sensitive = true
}

variable "resource_group" {
  type    = string
  default = "rg-packer-builds"
}

variable "image_resource_group" {
  type    = string
  default = "rg-images"
}

variable "image_name" {
  type    = string
  default = "ubuntu-22-04-base"
}

variable "location" {
  type    = string
  default = "ukwest"
}

source "azure-arm" "ubuntu" {
  client_id       = var.client_id
  client_secret   = var.client_secret
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  resource_group_name = var.resource_group
  location            = var.location

  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts"
  image_version   = "latest"

  vm_size = "Standard_B1s"
  os_type = "Linux"

  managed_image_name                = var.image_name
  managed_image_resource_group_name = var.image_resource_group

  keep_os_disk = false
}

build {
  sources = ["source.azure-arm.ubuntu"]

  # Update system using shelly
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y curl wget git htop python3"
    ]
  }

  # Install Docker using ansible playbook
  provisioner "ansible" {
    playbook_file = "./playbook.yml"
    use_proxy = false
    user = "${build.User}"

    extra_arguments = [
      "--extra-vars", "ansible_user=${build.User}",
    ]
  }

  # Copy config (file)
  provisioner "file" {
    source      = "${path.root}/files/app.conf"
    destination = "/tmp/app.conf"
  }

  provisioner "shell" {
    inline = [
      "sudo cp /tmp/app.conf /etc/app.conf",
      # cleanup to ensure unique VMs when cloned
      "sudo waagent -deprovision+user -force"
    ]
  }
}