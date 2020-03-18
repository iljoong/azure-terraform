# Configure the Microsoft Azure Provider
provider "azurerm" {
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id

  features {}
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "tfrg" {
  name     = "${var.prefix}-rg"
  location = var.location

  tags = {
    environment = var.tag
  }
}

# Create virtual network
resource "azurerm_virtual_network" "tfvnet" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.1.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.tfrg.name

  tags = {
    environment = var.tag
  }
}

resource "azurerm_subnet" "tfaksvnet" {
  name                 = "aks-net"
  virtual_network_name = azurerm_virtual_network.tfvnet.name
  resource_group_name  = azurerm_resource_group.tfrg.name

  # 10.1.0.1 ~ 10.1.15.254
  address_prefix = "10.1.0.0/20"
}

resource "azurerm_subnet_network_security_group_association" "tfaksvnet" {
  subnet_id                 = azurerm_subnet.tfaksvnet.id
  network_security_group_id =  azurerm_network_security_group.tfaksnsg.id
}

resource "azurerm_subnet_route_table_association" "tfaksvnet" {
  subnet_id            = azurerm_subnet.tfaksvnet.id
  route_table_id       = azurerm_route_table.nattable.id
}

resource "azurerm_subnet" "tfjboxvnet" {
  name                 = "jbox-subnet"
  virtual_network_name = azurerm_virtual_network.tfvnet.name
  resource_group_name  = azurerm_resource_group.tfrg.name
  address_prefix       = "10.1.200.0/24"
}

# NSG
resource "azurerm_network_security_group" "tfaksnsg" {
  name                = "${var.prefix}-aksnsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.tfrg.name

  security_rule {
    name                       = "HTTP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.tag
  }
}

# UDR
resource "azurerm_route_table" "nattable" {
  name                = "${var.prefix}-natroutetable"
  location            = var.location
  resource_group_name = azurerm_resource_group.tfrg.name
  
  route {
    name                   = "natrule1"
    address_prefix         = "10.100.0.0/14"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.10.1.1"
  }
}
