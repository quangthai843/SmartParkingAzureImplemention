variable "project_name" {
  description = "Prefix for all resources (lowercase letters and numbers only)"
  type        = string
  default     = "smartparking"
}

variable "location" {
  description = "Azure Region (Southeast Asia = Singapore, best latency for Vietnam)"
  type        = string
  default     = "southeastasia"
}

variable "static_web_app_location" {
  description = " Azure Static Web Apps only supports specific regions (eastasia = Hong Kong)"
  type        = string
  default     = "eastasia"
}

variable "docker_image" {
  description = "Your ASP.NET Core Docker image (starts with a quickstart placeholder until your image is pushed)"
  type        = string
  default     = "mcr.microsoft.com/k8se/quickstart:latest"
}

variable "mysql_admin_login" {
  description = "MySQL Administrator Username"
  type        = string
  default     = "parkingadmin"
}

variable "mysql_admin_password" {
  description = "MySQL Administrator Password"
  type        = string
  sensitive   = true
}

variable "gemini_api_key" {
  description = "Google Gemini API Key"
  type        = string
  sensitive   = true
}

variable "vnpay_tmn_code" {
  description = "VNPay Sandbox Terminal Code (vnp_TmnCode)"
  type        = string
}

variable "vnpay_hash_secret" {
  description = "VNPay Sandbox Hash Secret (vnp_HashSecret)"
  type        = string
  sensitive   = true
}