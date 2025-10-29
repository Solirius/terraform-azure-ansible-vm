variable "location" {
  type        = string
  default     = "North Europe"
  description = "The Azure region to deploy resources in."
}

variable "admin_username" {
  type        = string
  default     = "azureuser"
  description = "Administrator username for the VM."
}

variable "admin_public_key" {
  type        = string
  sensitive   = true
  description = "Public SSH key for VM authentication."
}

variable "prefix" {
  type        = string
  default     = "dev-vm"
  description = "Prefix for all resources (e.g., dev-vm-rg, dev-vm-vnet)."
}

variable "my_public_ip" {
  type        = string
  sensitive   = true
  description = "Your local public IP. Used to lock down SSH access."
}