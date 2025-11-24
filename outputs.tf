output "vm_public_ips" {
  value = azurerm_public_ip.main[*].ip_address
}
