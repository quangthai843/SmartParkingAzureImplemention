# Smart Parking Azure Infrastructure

Terraform configuration for deploying the Smart Parking platform to Microsoft Azure.

## What it creates

- Resource group and virtual network with dedicated subnets
- Private Azure Database for MySQL Flexible Server
- Azure IoT Hub for device messaging
- Azure Container App for the ASP.NET Core API
- Azure Functions Flex Consumption app for IoT processing
- Azure Static Web App for the frontend
- Log Analytics workspace and supporting storage resources

## Requirements

- Terraform 1.5 or newer
- An Azure subscription
- Azure CLI authenticated with an account that can create the resources
- A published backend Docker image

## Usage

1. Authenticate with Azure:

   ```powershell
   az login
   az account set --subscription "<subscription-id>"
   ```

2. Create a local variables file:

   ```powershell
   Copy-Item terraform.tfvars.example terraform.tfvars
   ```

   Replace every placeholder with the appropriate value. Keep this file local; it contains secrets.

3. Initialize and review the deployment:

   ```powershell
   terraform init
   terraform fmt -check
   terraform validate
   terraform plan
   ```

4. Apply the infrastructure:

   ```powershell
   terraform apply
   ```

5. View the deployed endpoints:

   ```powershell
   terraform output
   ```

To remove the resources created by this configuration:

```powershell
terraform destroy
```

## Security

Do not commit `terraform.tfvars`, Terraform state, plan files, or Azure credentials. State can contain infrastructure secrets and is ignored by this repository's `.gitignore`. Use a remote, encrypted Terraform backend for shared or production deployments.
