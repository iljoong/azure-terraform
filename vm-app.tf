# Create Network Security Group and rule
resource "azurerm_network_security_group" "tfappnsg" {
  name                = "${var.prefix}-appnsg"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.tfrg.name}"

  security_rule {
    name                       = "DENY_VNET"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "SSH_VNET"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                   = "HTTP_VNET"
    priority               = 1000
    direction              = "Inbound"
    access                 = "Allow"
    protocol               = "Tcp"
    source_port_range      = "*"
    destination_port_range = "80"

    source_application_security_group_ids      = ["${azurerm_application_security_group.tfwebasg.id}"]
    destination_application_security_group_ids = ["${azurerm_application_security_group.tfappasg.id}"]
  }

  tags {
    environment = "${var.tag}"
  }
}

# Create network interface
resource "azurerm_network_interface" "tfappnic" {
  count                     = "${var.appcount}"
  name                      = "${var.prefix}-appnic${count.index}"
  location                  = "${var.location}"
  resource_group_name       = "${azurerm_resource_group.tfrg.name}"
  network_security_group_id = "${azurerm_network_security_group.tfappnsg.id}"

  ip_configuration {
    name      = "${var.prefix}-appnic-conf${count.index}"
    subnet_id = "${azurerm_subnet.tfappvnet.id}"

    #private_ip_address_allocation = "dynamic"
    private_ip_address_allocation  = "Static"
    private_ip_address             = "${format("10.0.2.%d", count.index + 4)}"
    application_security_group_ids = ["${azurerm_application_security_group.tfappasg.id}"]
  }

  tags {
    environment = "${var.tag}"
  }
}

resource "azurerm_availability_set" "tfappavset" {
  name                        = "${var.prefix}-appavset"
  location                    = "${var.location}"
  resource_group_name         = "${azurerm_resource_group.tfrg.name}"
  managed                     = "true"
  platform_fault_domain_count = 2                                     # default 3 cannot be used

  tags {
    environment = "${var.tag}"
  }
}

# Create virtual machine
resource "azurerm_virtual_machine" "tfappvm" {
  count                 = "${var.appcount}"
  name                  = "${var.prefix}appvm${count.index}"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.tfrg.name}"
  network_interface_ids = ["${azurerm_network_interface.tfappnic.*.id[count.index]}"]
  vm_size               = "${var.vmsize}"
  availability_set_id   = "${azurerm_availability_set.tfappavset.id}"

  storage_os_disk {
    name              = "${format("%s-app-%03d-osdisk", var.prefix, count.index + 1)}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"

    disk_size_gb = "64" # increase default os disk
  }

  /*
    # add extra data disk
    storage_data_disk {
        name              = "${format("%s-app-%03d-datadisk", var.prefix, count.index + 1)}"
        managed_disk_type = "Premium_LRS"
        create_option     = "Empty"
        lun               = 0
        disk_size_gb      = "128"        
    }
  */

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }
  os_profile {
    computer_name  = "${format("tfappvm%03d", count.index + 1)}"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags {
    environment = "${var.tag}"
  }
}
