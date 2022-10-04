# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      # use latest
      #version = "=3.25.0"
    }
  }
}

provider "azurerm" {
  /*subscription_id = var.azure.subscription_id
  client_id       = var.azure.client_id
  client_secret   = var.azure.client_secret
  tenant_id       = var.azure.tenant_id*/

  features {}
}


# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "tfrg" {
  name     = "${var.resource.prefix}-rg"
  location = var.resource.location

  tags = {
    environment = var.resource.tag
  }
}

# Create virtual network
resource "azurerm_virtual_network" "tfvnet" {
  name                = "${var.resource.prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.resource.location
  resource_group_name = azurerm_resource_group.tfrg.name

  tags = {
    environment = var.resource.tag
  }
}

resource "azurerm_subnet" "tfwebvnet" {
  name                 = "web-subnet"
  virtual_network_name = azurerm_virtual_network.tfvnet.name
  resource_group_name  = azurerm_resource_group.tfrg.name
  address_prefixes     = ["10.0.1.0/24"]
}


resource "azurerm_network_security_group" "tfwebnsg" {
  name                = "${var.resource.prefix}-app-nsg"
  location            = var.resource.location
  resource_group_name = azurerm_resource_group.tfrg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
