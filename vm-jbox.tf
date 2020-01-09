# Create Network Security Group and rule
resource "azurerm_network_security_group" "tfjboxnsg" {
  name                = "${var.prefix}-jboxnsg"
  location            = var.location
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
    environment = var.tag
  }
}

# Create public IPs
resource "azurerm_public_ip" "tfjboxip" {
  name                = "${var.prefix}-jboxip"
  location            = var.location
  resource_group_name = azurerm_resource_group.tfrg.name
  allocation_method   = "Static"

  tags = {
    environment = var.tag
  }
}

# Create network interface
resource "azurerm_network_interface" "tfjboxnic" {
  name                      = "${var.prefix}-jboxnic"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.tfrg.name
  network_security_group_id = azurerm_network_security_group.tfjboxnsg.id

  ip_configuration {
    name                          = "${var.prefix}-jboxnic-conf"
    subnet_id                     = azurerm_subnet.tfjboxvnet.id
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = azurerm_public_ip.tfjboxip.id
  }

  tags = {
    environment = var.tag
  }
}

# Create virtual machine
resource "azurerm_virtual_machine" "tfjboxvm" {
  name                  = "${var.prefix}jboxvm"
  location              = var.location
  resource_group_name   = azurerm_resource_group.tfrg.name
  network_interface_ids = [azurerm_network_interface.tfjboxnic.id]
  vm_size               = "Standard_DS1_v2"

  storage_os_disk {
    name              = "${var.prefix}-ftosdisk-jbox"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }

  /*
  # alternative login method
  os_profile {
    computer_name  = "tfjboxvm${count.index}"
    admin_username = "${var.admin_username}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = "${var.admin_keydata}"
    }
  }
  */
  os_profile {
    computer_name  = "tfjobxvm"
    admin_username = var.admin_username
    admin_password = var.admin_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    environment = var.tag
  }
}

# public_ip must be 'static' in order to print output properly 
output "jumphost_ip" {
  value = azurerm_public_ip.tfjboxip.ip_address
}

