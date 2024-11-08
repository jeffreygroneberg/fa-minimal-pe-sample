# Azure Function App with Terraform Infrastructure

This project contains an Azure Function App and associated infrastructure deployed using Terraform. The project is organized into several directories, each containing code and configurations for different components.

## Project Structure

- [`function/`](function/): Contains the Azure Function App code and configurations.
- [`infra-simple/`](infra-simple/): Terraform scripts for deploying a simple infrastructure.
- [`infra-with-agw/`](infra-with-agw/): Terraform scripts for deploying infrastructure with an Application Gateway (AGW).

### `function/`

This directory contains the code for the Azure Function App.

**Contents:**

- [`function_app.py`](function/function_app.py): The main Python code for the Function App.
- [`requirements.txt`](function/requirements.txt): Python package dependencies.
- [`host.json`](function/host.json) and [`local.settings.json`](function/local.settings.json): Configuration files for the Function App.
- [`.funcignore`](function/.funcignore): Specifies files to ignore when deploying.

### `infra-simple/`

This directory contains Terraform scripts to deploy a simple infrastructure for the Function App.

**Contents:**

- [`main.tf`](infra-simple/main.tf): Defines the infrastructure resources.
- [`providers.tf`](infra-simple/providers.tf): Specifies the Terraform providers.
- [`variables.tf`](infra-simple/variables.tf): Input variables for the Terraform scripts.
- [`versions.tf`](infra-simple/versions.tf): Required Terraform version.

### `infra-with-agw/`

This directory contains Terraform scripts to deploy an advanced infrastructure with an Application Gateway (AGW) and Web Application Firewall (WAF). The application gateway acts as a reverse proxy for the Function App and allows to add addtional path routing options for further functions. One custom rule is available to customize the firewall behaviour on each path. 

**Contents:**

- [`main.tf`](infra-with-agw/main.tf): Defines the infrastructure resources, including the Application Gateway.
- [`outputs.tf`](infra-with-agw/outputs.tf): Outputs from the Terraform scripts.
- [`providers.tf`](infra-with-agw/providers.tf): Specifies the Terraform providers.
- [`variables.tf`](infra-with-agw/variables.tf): Input variables for the Terraform scripts.
- [`versions.tf`](infra-with-agw/versions.tf): Required Terraform version.