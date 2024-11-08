# Configure the Azure provider
provider "azurerm" {
  features {
    application_insights {
      disable_generated_rule = true
    }
  }
  use_cli         = true
  subscription_id = "dd495a0b-53f9-4af3-bfe4-b9845e58d010"


}
