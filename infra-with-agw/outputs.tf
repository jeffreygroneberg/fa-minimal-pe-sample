locals {
  agw_function_url = "http://${azurerm_public_ip.pip.ip_address}/function/api/http_trigger?name=User"
}

output "agw_path_to_function" {
  value = local.agw_function_url
}

output "curl_command" {
  value = "curl -H 'X-Auth-Custom: 123' '${local.agw_function_url}' -v"
}
