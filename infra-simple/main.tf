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
        bypass = ["AzureServices"]        
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

    name                = azurerm_private_dns_zone_virtual_network_link.blob_dns_link.name
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
    name                = azurerm_private_dns_zone_virtual_network_link.file_dns_link.name
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
  name                       = "fa-${var.workload_name}-${var.environment}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  service_plan_id            = azurerm_service_plan.asp.id
  storage_account_name       = azurerm_storage_account.sa.name
  storage_uses_managed_identity = true
  public_network_access_enabled = true
  functions_extension_version = "~4"    
  virtual_network_subnet_id = azurerm_subnet.subnet-fa.id


  site_config {    

    vnet_route_all_enabled = true    

      application_stack {
        python_version = "3.11"
      }

  }

  app_settings = {
    # needed for the function app to be able to access the storage account for blob creation and triggers etc 
    WEBSITE_CONTENTOVERVNET = "1"
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = azurerm_storage_account.sa.primary_connection_string
    WEBSITE_CONTENTSHARE                     = azurerm_storage_share.function.name
  }

  identity {
    type = "SystemAssigned"
  }

  depends_on = [ azurerm_private_endpoint.storage_pe_blob, azurerm_private_endpoint.storage_pe_file ]
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



