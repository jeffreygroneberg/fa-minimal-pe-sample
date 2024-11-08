variable "environment" {

  description = "Environment (e.g., dev, test, prod)"
  type        = string
  default     = "prod"
  # validation of dev test prod
  validation {
    condition     = var.environment == "dev" || var.environment == "test" || var.environment == "prod"
    error_message = "Environment must be dev, test, or prod"
  }
}

# location, but only allow valid Azure regions
variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "GermanyWestCentral"

}

# workload project name
variable "workload_name" {
  description = "Name of the workload project"
  type        = string
  default     = "agwtest"
}

# to further access the private storage account and function app for testing purposes it makes sense to enter your own public IP address
variable "client_ip" {
  description = "The public IP address of the client machine"
  type        = string
  default     = ""
}
