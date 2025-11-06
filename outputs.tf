output "vm_public_ip" {
  description = "The public IP address of the VM"
  value       = azurerm_public_ip.my_terraform_public_ip.ip_address
}

output "ssh_command" {
  description = "Command to SSH into the VM"
  value       = "ssh -i ~/.ssh/id_rsa_azure ${var.admin_username}@${azurerm_public_ip.my_terraform_public_ip.ip_address}"
}

output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.rg.name
}

output "acr_login_server" {
  description = "The login server URL of the new ACR"
  value       = azurerm_container_registry.my_acr.login_server
}

output "acr_name" {
  description = "The name of the Azure Container Registry"
  value       = azurerm_container_registry.my_acr.name
}

output "deploy_public_key" {
  description = "The public key for GitHub Actions deployment"
  value       = var.deploy_public_key
}

output "key_vault_uri" {
  description = "The URI of the new Key Vault"
  value       = azurerm_key_vault.my_key_vault.vault_uri
}