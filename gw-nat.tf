# Reference:
#   https://docs.microsoft.com/en-us/azure/virtual-network/nat-overview
#   https://www.terraform.io/docs/providers/azurerm/r/nat_gateway.html

# Create outbound public IP
resource "azurerm_public_ip" "tfnatip" {
  name                = "${var.resource.prefix}-natip"
  location            = var.resource.location
  resource_group_name = azurerm_resource_group.tfrg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  availability_zone   = "No-Zone"
}

resource "azurerm_nat_gateway" "tfnatgw" {
  name                    = "${var.resource.prefix}-natgw"
  location                = var.resource.location
  resource_group_name     = azurerm_resource_group.tfrg.name
  ##public_ip_address_ids   = [azurerm_public_ip.tfnatip.id]
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10

  depends_on              = [azurerm_public_ip.tfnatip]
}

resource "azurerm_subnet_nat_gateway_association" "tfnatgw" {
  subnet_id      = azurerm_subnet.tfappvnet.id
  nat_gateway_id = azurerm_nat_gateway.tfnatgw.id
}

resource "azurerm_nat_gateway_public_ip_association" "tfnatgw" {
  nat_gateway_id       = azurerm_nat_gateway.tfnatgw.id
  public_ip_address_id = azurerm_public_ip.tfnatip.id
}

# natgw_public_ip_prefix 
output "natgw_public_ip" {
  value = azurerm_public_ip.tfnatip.ip_address
}

