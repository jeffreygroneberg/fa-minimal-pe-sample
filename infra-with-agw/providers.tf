# Configure the Azure provider
provider "azurerm" {
  features {
    application_insights {
      disable_generated_rule = true
    }
  }
  use_cli         = true
}
