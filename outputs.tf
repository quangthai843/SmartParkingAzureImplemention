output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "frontend_url" {
  description = "Public HTTPS URL for your Client Browser (S3 + CloudFront replacement)"
  value       = "https://${azurerm_static_web_app.frontend.default_host_name}"
}

output "backend_api_url" {
  description = "Public HTTPS URL for your ASP.NET Core API & VNPay IPN Webhook"
  value       = "https://${azurerm_container_app.backend_api.ingress[0].fqdn}"
}

output "mysql_private_fqdn" {
  description = "Internal VNet address for your MySQL Flexible Server"
  value       = azurerm_mysql_flexible_server.mysql.fqdn
}

output "iothub_hostname" {
  description = "MQTT Broker Hostname for your Edge AI & Hardware Nodes"
  value       = azurerm_iothub.iothub.hostname
}