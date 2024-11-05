# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.workload_name}-${var.environment}-${var.location}"
  location = var.location
}

# Virtual Network Function App
resource "azurerm_virtual_network" "vnet" {

  name                = "vnet-${var.workload_name}-${var.environment}-${azurerm_resource_group.rg.location}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]

}

# Subnet
resource "azurerm_subnet" "subnet-pe" {

  name                 = "subnet-pe-${var.workload_name}-${var.environment}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

}

# Subnet
resource "azurerm_subnet" "subnet-fa" {

  name                 = "subnet-fa-${var.workload_name}-${var.environment}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]

  # subnet delegation serverFarms
  delegation {
    name = "serverFarms"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }

  private_link_service_network_policies_enabled = true

}

# Storage Account
resource "azurerm_storage_account" "sa" {

  name                     = "sa${var.workload_name}${var.environment}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # only true when deploying locally
  public_network_access_enabled = true

  # network rule
  network_rules {
    default_action = "Deny"
    # for local deployment this should be the public IP of the machine
    ip_rules = ["91.89.197.67"]
    bypass   = ["AzureServices"]
  }

}

resource "azurerm_storage_share" "function" {
  name                 = "functionfileshare"
  storage_account_name = azurerm_storage_account.sa.name
  quota                = 5
}

# Private Endpoint for Storage Account File
resource "azurerm_private_endpoint" "storage_pe_blob" {
  name                = "pe-${var.workload_name}-${var.environment}-storage-blob"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet-pe.id

  private_service_connection {
    name                           = "storage-connection-blob"
    private_connection_resource_id = azurerm_storage_account.sa.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = azurerm_private_dns_zone_virtual_network_link.blob_dns_link.name
    private_dns_zone_ids = [azurerm_private_dns_zone.blob_dns_zone.id]
  }

}

# Private Endpoint for Storage Account Blob
resource "azurerm_private_endpoint" "storage_pe_file" {
  name                = "pe-${var.workload_name}-${var.environment}-storage-file"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet-pe.id

  private_service_connection {
    name                           = "storage-connection-file"
    private_connection_resource_id = azurerm_storage_account.sa.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = azurerm_private_dns_zone_virtual_network_link.file_dns_link.name
    private_dns_zone_ids = [azurerm_private_dns_zone.file_dns_zone.id]
  }
}

# Private DNS Zone for Blob Storage
resource "azurerm_private_dns_zone" "blob_dns_zone" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

# Private DNS Zone for File Storage
resource "azurerm_private_dns_zone" "file_dns_zone" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

# Link Blob DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "blob_dns_link" {
  name                  = azurerm_private_dns_zone.blob_dns_zone.name
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.blob_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# Link File DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "file_dns_link" {
  name                  = azurerm_private_dns_zone.file_dns_zone.name
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.file_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# App Service Plan
resource "azurerm_service_plan" "asp" {
  name                = "asp-${var.workload_name}-${var.environment}-${azurerm_resource_group.rg.location}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "EP1"
}

# Function App
resource "azurerm_linux_function_app" "fa" {
  name                          = "fa-${var.workload_name}-${var.environment}"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  service_plan_id               = azurerm_service_plan.asp.id
  storage_account_name          = azurerm_storage_account.sa.name
  storage_uses_managed_identity = true
  public_network_access_enabled = true
  functions_extension_version   = "~4"
  virtual_network_subnet_id     = azurerm_subnet.subnet-fa.id


  site_config {

    vnet_route_all_enabled = true

    application_stack {
      python_version = "3.11"
    }

  }

  app_settings = {
    # needed for the function app to be able to access the storage account for blob creation and triggers etc 
    WEBSITE_CONTENTOVERVNET                  = "1"
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = azurerm_storage_account.sa.primary_connection_string
    WEBSITE_CONTENTSHARE                     = azurerm_storage_share.function.name
  }

  identity {
    type = "SystemAssigned"
  }

  depends_on = [azurerm_private_endpoint.storage_pe_blob, azurerm_private_endpoint.storage_pe_file]
}

# the managed identity needs access to read and modify the storage and file share for deployments
resource "azurerm_role_assignment" "function_mi_access_to_storage_account" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = azurerm_linux_function_app.fa.identity.0.principal_id
}

resource "azurerm_role_assignment" "function_mi_access_to_storage_account_data" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.fa.identity.0.principal_id
}

resource "azurerm_role_assignment" "function_mi_access_to_storage_account_file" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage File Data Privileged Contributor"
  principal_id         = azurerm_linux_function_app.fa.identity.0.principal_id
}

### --------------
### Gateway stuff
### --------------

# Virtual network for Gateway
resource "azurerm_virtual_network" "vnet-gw" {

  name                = "vnet-${var.workload_name}-${var.environment}-agw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.2.0.0/16"]

}

# Peering between the two VNets
resource "azurerm_virtual_network_peering" "vnet-peering" {
  name                         = "vnet-peering-${var.workload_name}-${var.environment}"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.vnet-gw.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

# Subnet for Gateway
resource "azurerm_subnet" "subnet-gw" {

  name                 = "subnet-gw-${var.workload_name}-${var.environment}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet-gw.name
  address_prefixes     = ["10.2.1.0/24"]
}

# Subnet for Private Endpoints pointing to Azure Function
resource "azurerm_subnet" "subnet-pe-gw" {

  name                 = "subnet-pe-gw-${var.workload_name}-${var.environment}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet-gw.name
  address_prefixes     = ["10.2.2.0/24"]
}

# Private DNS Zone for my Vnet Gateway used for the Azure Function Endpoints
resource "azurerm_private_dns_zone" "gw_dns_zone" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.rg.name
}

# Link DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "gw_dns_link" {

  name                  = azurerm_private_dns_zone.gw_dns_zone.name
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.gw_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet-gw.id

}

# Private Endpoint for Azure Function
resource "azurerm_private_endpoint" "function_pe" {
  name                = "pe-${var.workload_name}-${var.environment}-function"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet-pe-gw.id

  private_service_connection {
    name                           = "function-connection"
    private_connection_resource_id = azurerm_linux_function_app.fa.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = azurerm_private_dns_zone_virtual_network_link.gw_dns_link.name
    private_dns_zone_ids = [azurerm_private_dns_zone.gw_dns_zone.id]
  }

}

# Public IP for Gateway
resource "azurerm_public_ip" "pip" {
  name                = "pip-${var.workload_name}-${var.environment}-agw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"] // Add this line to specify the availability zone
}

## App Gateway uses a lot of name references. Let's define them here
locals {
  application_gateway_name    = "appgw-${var.workload_name}-${var.environment}"
  gateway_ip_config_name      = "appGatewayIpConfig"
  frontend_port_name          = "port_80"
  frontend_ip_config_name     = "appGatewayFrontendIP"
  backend_pool_name           = "appGatewayBackendPool"
  backend_http_settings_name  = "appGatewayBackendHttpSettings"
  http_listener_name          = "appGatewayHttpListener"
  request_routing_rule_name   = "appGatewayPathBasedRoutingRule"
  url_path_map_name           = "urlPathMap"
  path_rule_name              = "app1-rule"
  redirect_configuration_name = "defaultRedirectConfiguration"
}

resource "azurerm_application_gateway" "appgw" {

  name                = local.application_gateway_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = local.gateway_ip_config_name
    subnet_id = azurerm_subnet.subnet-gw.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_config_name
    public_ip_address_id = azurerm_public_ip.pip.id
  }

  backend_address_pool {
    name  = local.backend_pool_name
    fqdns = [azurerm_linux_function_app.fa.default_hostname]
  }

  backend_http_settings {
    name                                = local.backend_http_settings_name
    cookie_based_affinity               = "Disabled"
    port                                = 80
    protocol                            = "Http"
    pick_host_name_from_backend_address = true
    path                                = "/"
    request_timeout                     = 20
  }

  http_listener {
    name                           = local.http_listener_name
    frontend_ip_configuration_name = local.frontend_ip_config_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  # Path based Routing Rule
  request_routing_rule {

    name               = local.request_routing_rule_name
    rule_type          = "PathBasedRouting"
    http_listener_name = local.http_listener_name
    url_path_map_name  = local.url_path_map_name
    priority           = 20

  }

  # URL Path Map - Define Path based Routing    
  url_path_map {
    name                                = local.url_path_map_name
    default_redirect_configuration_name = local.redirect_configuration_name

    path_rule {
      name                       = local.path_rule_name
      paths                      = ["/function*"]
      backend_address_pool_name  = local.backend_pool_name
      backend_http_settings_name = local.backend_http_settings_name
      firewall_policy_id         = azurerm_web_application_firewall_policy.waf_policy.id
    }

  }

  # Default Root Context (/ - Redirection Config)
  redirect_configuration {
    name          = local.redirect_configuration_name
    redirect_type = "Permanent"
    target_url    = "https://www.google.com"
  }
}

resource "azurerm_web_application_firewall_policy" "waf_policy" {
  name                = "wafpolicy"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  policy_settings {
    enabled                     = true
    mode                        = "Prevention"
    request_body_check          = false
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }
  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }

  // If X-Auth-Custom header is NOT present, block the request
  custom_rules {
    name      = "ExcludeServicesFromWAF"
    priority  = 14
    rule_type = "MatchRule"

    match_conditions {

      match_variables {
        variable_name = "RequestHeaders"
        selector      = "X-Auth-Custom"
      }

      operator           = "Any"
      negation_condition = true
    }

    action = "Block"
  }
}
