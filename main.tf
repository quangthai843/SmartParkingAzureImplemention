terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "core"
}

# Generate a random suffix so globally unique names (MySQL, IoT Hub, Storage) don't collide
resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

# ---------------------------------------------------------
# 1. RESOURCE GROUP
# ---------------------------------------------------------
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.project_name}-${random_string.suffix.result}"
  location = var.location
}

# ---------------------------------------------------------
# 2. VIRTUAL NETWORK (Replaces AWS VPC)
# ---------------------------------------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.project_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# Subnet for Azure Container Apps (Requires at least /23)
resource "azurerm_subnet" "aca_subnet" {
  name                 = "snet-container-apps"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/23"]

  delegation {
    name = "aca-delegation"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Subnet for MySQL Flexible Server
resource "azurerm_subnet" "mysql_subnet" {
  name                 = "snet-mysql"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "mysql-delegation"
    service_delegation {
      name    = "Microsoft.DBforMySQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Subnet for Azure Functions VNet Integration
resource "azurerm_subnet" "func_subnet" {
  name                 = "snet-functions"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]

  delegation {
    name = "func-delegation"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# ---------------------------------------------------------
# 3. DATABASE: Azure Database for MySQL (Replaces AWS RDS)
# ---------------------------------------------------------
resource "azurerm_private_dns_zone" "mysql_dns" {
  name                = "${var.project_name}${random_string.suffix.result}.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql_dns_link" {
  name                  = "mysql-dns-link"
  private_dns_zone_name = azurerm_private_dns_zone.mysql_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  resource_group_name   = azurerm_resource_group.rg.name
}

resource "azurerm_mysql_flexible_server" "mysql" {
  name                   = "mysql-${var.project_name}-${random_string.suffix.result}"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  administrator_login    = var.mysql_admin_login
  administrator_password = var.mysql_admin_password

  # Cheapest Burstable tier for student credits
  sku_name = "B_Standard_B1ms"
  version  = "8.0.21"

  delegated_subnet_id = azurerm_subnet.mysql_subnet.id
  private_dns_zone_id = azurerm_private_dns_zone.mysql_dns.id

  storage {
    size_gb = 20
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.mysql_dns_link]
}

resource "azurerm_mysql_flexible_database" "parking_db" {
  name                = "smartparkingdb"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_flexible_server.mysql.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}

locals {
  mysql_conn_string = "Server=${azurerm_mysql_flexible_server.mysql.fqdn};Port=3306;Database=${azurerm_mysql_flexible_database.parking_db.name};Uid=${var.mysql_admin_login};Pwd=${var.mysql_admin_password};SslMode=Required;"
}

# ---------------------------------------------------------
# 4. MQTT BROKER: Azure IoT Hub (Replaces AWS IoT Core)
# ---------------------------------------------------------
resource "azurerm_iothub" "iothub" {
  name                      = "iot-${var.project_name}-${random_string.suffix.result}"
  resource_group_name       = azurerm_resource_group.rg.name
  location                  = azurerm_resource_group.rg.location
  event_hub_partition_count = 2

  # Free Tier (F1): $0/month, up to 8,000 messages/day
  sku {
    name     = "F1"
    capacity = 1
  }
}

# ---------------------------------------------------------
# 5. BACKEND API: Azure Container Apps (Replaces Fargate/App Runner)
# ---------------------------------------------------------
resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-${var.project_name}-${random_string.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "aca_env" {
  name                       = "cae-${var.project_name}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  infrastructure_subnet_id   = azurerm_subnet.aca_subnet.id
}

resource "azurerm_container_app" "backend_api" {
  name                         = "ca-${var.project_name}-api"
  container_app_environment_id = azurerm_container_app_environment.aca_env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  secret {
    name  = "mysql-conn-string"
    value = local.mysql_conn_string
  }
  secret {
    name  = "gemini-api-key"
    value = var.gemini_api_key
  }
  secret {
    name  = "vnpay-hash-secret"
    value = var.vnpay_hash_secret
  }

  template {
    min_replicas = 0 # Scales to zero when idle to save your $100 student credits
    max_replicas = 2

    container {
      name   = "aspnet-core-api"
      image  = var.docker_image
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name        = "ConnectionStrings__DefaultConnection"
        secret_name = "mysql-conn-string"
      }
      env {
        name        = "Gemini__ApiKey"
        secret_name = "gemini-api-key"
      }
      env {
        name  = "VnPay__TmnCode"
        value = var.vnpay_tmn_code
      }
      env {
        name        = "VnPay__HashSecret"
        secret_name = "vnpay-hash-secret"
      }
    }
  }

  # Public HTTPS Ingress for Frontend REST API & VNPay Webhooks
  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 80
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

# ---------------------------------------------------------
# 6. SERVERLESS: Azure Functions (Replaces AWS Lambda)
# ---------------------------------------------------------
resource "azurerm_storage_account" "func_storage" {
  name                     = "st${var.project_name}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# FC1 requires a dedicated Blob Container inside the Storage Account to store your deployed code
resource "azurerm_storage_container" "func_deployment" {
  name                  = "deploymentpackage"
  storage_account_id    = azurerm_storage_account.func_storage.id
  container_access_type = "private"
}

resource "azurerm_service_plan" "func_plan" {
  name                = "asp-${var.project_name}-func"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "FC1"
}

resource "azurerm_function_app_flex_consumption" "iot_processor" {
  name                = "func-${var.project_name}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.func_plan.id

  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.func_storage.primary_blob_endpoint}${azurerm_storage_container.func_deployment.name}"
  storage_authentication_type = "StorageAccountConnectionString"
  storage_access_key          = azurerm_storage_account.func_storage.primary_access_key

  runtime_name           = "dotnet-isolated"
  runtime_version        = "8.0"
  instance_memory_in_mb  = 2048 # Default memory allocation for FC1
  maximum_instance_count = 40

  # Connects Function to the VNet so it can update the private MySQL DB
  virtual_network_subnet_id = azurerm_subnet.func_subnet.id

  site_config {}

  app_settings = {
    "IoTHubConnectionString"               = azurerm_iothub.iothub.event_hub_events_endpoint
    "ConnectionStrings__DefaultConnection" = local.mysql_conn_string
  }
}

# ---------------------------------------------------------
# 7. FRONTEND: Azure Static Web Apps (Replaces S3 + CloudFront)
# ---------------------------------------------------------
resource "azurerm_static_web_app" "frontend" {
  name                = "swa-${var.project_name}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.static_web_app_location
  sku_tier            = "Free"
  sku_size            = "Free"
}