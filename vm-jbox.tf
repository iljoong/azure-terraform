# Create Network Security Group and rule
resource "azurerm_network_security_group" "tfjboxnsg" {
  name                = "${var.resource.prefix}-jboxnsg"
  location            = var.resource.location
  resource_group_name = azurerm_resource_group.tfrg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*" # add source addr
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.resource.tag
  }
}

# Create public IPs
resource "azurerm_public_ip" "tfjboxip" {
  name                = "${var.resource.prefix}-jboxip"
  location            = var.resource.location
  resource_group_name = azurerm_resource_group.tfrg.name
  allocation_method   = "Static"

  tags = {
    environment = var.resource.tag
  }
}

# Create network interface
resource "azurerm_network_interface" "tfjboxnic" {
  name                      = "${var.resource.prefix}-jboxnic"
  location                  = var.resource.location
  resource_group_name       = azurerm_resource_group.tfrg.name
  #-network_security_group_id = azurerm_network_security_group.tfjboxnsg.id

  ip_configuration {
    name                          = "${var.resource.prefix}-jboxnic-conf"
    subnet_id                     = azurerm_subnet.tfjboxvnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.tfjboxip.id
  }

  tags = {
    environment = var.resource.tag
  }
}

resource "azurerm_network_interface_security_group_association" "tfjboxnic" {
  network_interface_id      = azurerm_network_interface.tfjboxnic.id
  network_security_group_id = azurerm_network_security_group.tfjboxnsg.id
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "tfjboxvm" {
  name                  = "${var.resource.prefix}jboxvm"
  location              = var.resource.location
  resource_group_name   = azurerm_resource_group.tfrg.name
  network_interface_ids = [azurerm_network_interface.tfjboxnic.id]
  size                  = "Standard_DS1_v2"

  computer_name  = "tfjobxvm"
  admin_username = var.vm.admin_username
  admin_password = var.vm.admin_password
  disable_password_authentication = false

  os_disk {
    name                 = "${var.resource.prefix}-ftosdisk-jbox"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  tags = {
    environment = var.resource.tag
  }
}

# public_ip must be 'static' in order to print output properly 
output "jumphost_ip" {
  value = azurerm_public_ip.tfjboxip.ip_address
}

