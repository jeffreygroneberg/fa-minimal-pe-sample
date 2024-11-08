# Output hostname of function app
output "function_app_hostname" {
  value = azurerm_linux_function_app.fa.default_hostname
}

output "function_curl" {
    value = "curl 'https://${azurerm_linux_function_app.fa.default_hostname}/api/http_trigger?name=User' -v"  
}