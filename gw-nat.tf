# Reference:
#   https://docs.microsoft.com/en-us/azure/virtual-network/nat-overview
#   https://www.terraform.io/docs/providers/azurerm/r/nat_gateway.html

# Create outbound public IP
resource "azurerm_public_ip" "tfnatip" {
  name                = "${var.prefix}-natip"
  location            = var.location
  resource_group_name = azurerm_resource_group.tfrg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create outbound public IP-prefix
/*
resource "azurerm_public_ip_prefix" "tfnatgw" {
  name                = "${var.prefix}-natgw-ipprefix"
  location            = var.location
  resource_group_name = azurerm_resource_group.tfrg.name
  prefix_length       = 30
}
*/

resource "azurerm_nat_gateway" "tfnatgw" {
  name                    = "${var.prefix}-natgw"
  location                = var.location
  resource_group_name     = azurerm_resource_group.tfrg.name
  public_ip_address_ids   = [azurerm_public_ip.tfnatip.id]
  #public_ip_prefix_ids    = [azurerm_public_ip_prefix.tfnatgw.id]
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
}

resource "azurerm_subnet_nat_gateway_association" "tfnatgw" {
  subnet_id      = azurerm_subnet.tfappvnet.id
  nat_gateway_id = azurerm_nat_gateway.tfnatgw.id
}

# natgw_public_ip_prefix 
output "natgw_public_ip" {
  value = azurerm_public_ip.tfnatip.ip_address
}

/*
output "natgw_public_ip_prefix" {
  value = azurerm_public_ip_prefix.tfnatgw.ip_prefix
}
*/
