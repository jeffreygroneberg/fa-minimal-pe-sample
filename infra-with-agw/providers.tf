# Configure the Azure provider
provider "azurerm" {
  features {
    application_insights {
      disable_generated_rule = true
    }

    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  use_cli = true

}
