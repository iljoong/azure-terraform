# azure service principal info
variable "subscription_id" {
  default = "add_here"
}

# client_id or app_id
variable "client_id" {
  default = "add_here"
}

variable "client_secret" {
  default = "add_here"
}

# tenant_id or directory_id
variable "tenant_id" {
  default = "add_here"
}

# admin password
variable "admin_username" {
  default = "azureuser"
}

variable "admin_password" {
  default = "_add_here_"
}

# service variables
variable "prefix" {
  default = "tfaksdemo"
}

variable "location" {
  default = "westus2"
}

variable "tag" {
  default = "demo"
}