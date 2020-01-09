# Create Network Security Group and rule
resource "azurerm_network_security_group" "tfnatnsg" {
  name                = "${var.prefix}-natnsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.tfrg.name

  security_rule {
    name                       = "AllowAnyOutBoundInnerSubnet"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "Internet"
  }

  tags = {
    environment = var.tag
  }
}

# Create public IPs
resource "azurerm_public_ip" "tfnatip" {
  name                = "${var.prefix}-natip"
  location            = var.location
  resource_group_name = azurerm_resource_group.tfrg.name
  allocation_method   = "Static"

  tags = {
    environment = var.tag
  }
}

# Create network interface
resource "azurerm_network_interface" "tfnatnic" {
  name                      = "${var.prefix}-natnic"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.tfrg.name
  network_security_group_id = azurerm_network_security_group.tfnatnsg.id
  enable_ip_forwarding      = "true"

  ip_configuration {
    name                          = "${var.prefix}-natnic-conf"
    subnet_id                     = azurerm_subnet.tfnatvnet.id
    private_ip_address_allocation = "static"
    private_ip_address            = "10.0.0.10"
    public_ip_address_id          = azurerm_public_ip.tfnatip.id
  }

  tags = {
    environment = var.tag
  }
}

# Create virtual machine
resource "azurerm_virtual_machine" "tfnatvm" {
  name                  = "${var.prefix}natvm"
  location              = var.location
  resource_group_name   = azurerm_resource_group.tfrg.name
  network_interface_ids = [azurerm_network_interface.tfnatnic.id]
  vm_size               = var.vmsize

  storage_os_disk {
    name              = "${var.prefix}-ftosdisk-nat"
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

  os_profile {
    computer_name  = "tfnatvm"
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

resource "azurerm_virtual_machine_extension" "natvmext" {
  name                 = "natvmext"
  location             = var.location
  resource_group_name  = azurerm_resource_group.tfrg.name
  virtual_machine_name = azurerm_virtual_machine.tfnatvm.name
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "script": "IyEvYmluL3NoCnN1ZG8gYXB0LWdldCB1cGRhdGUKCiMgbmV0LmlwdjQuaXBfZm9yd2FyZCA9IDEKY3AgL2V0Yy9zeXNjdGwuY29uZiAvdG1wL3N5c2N0bC5jb25mCmVjaG8gIm5ldC5pcHY0LmlwX2ZvcndhcmQgPSAxIiA+PiAvdG1wL3N5c2N0bC5jb25mCnN1ZG8gY3AgL3RtcC9zeXNjdGwuY29uZiAvZXRjL3N5c2N0bC5jb25mCgojIGZpcmV3YWxsZApzdWRvIC9ldGMvaW5pdC5kL25ldHdvcmtpbmcgcmVzdGFydApzdWRvIGFwdC1nZXQgaW5zdGFsbCAteSBmaXJld2FsbGQKc3VkbyBzeXN0ZW1jdGwgZW5hYmxlIGZpcmV3YWxsZApzdWRvIHN5c3RlbWN0bCBzdGFydCBmaXJld2FsbGQKc3VkbyBmaXJld2FsbC1jbWQgLS1zdGF0ZQpzdWRvIGZpcmV3YWxsLWNtZCAtLXNldC1kZWZhdWx0LXpvbmU9ZXh0ZXJuYWwKc3VkbyBmaXJld2FsbC1jbWQgLS1yZWxvYWQ="
    }
    SETTINGS


  tags = {
    environment = var.tag
  }
}

output "nat_ip" {
  value = azurerm_public_ip.tfnatip.ip_address
}
