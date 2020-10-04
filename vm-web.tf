# Create Network Security Group and rule
resource "azurerm_network_security_group" "tfwebnsg" {
  name                = "${var.prefix}-webnsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.tfrg.name

  security_rule {
    name                       = "web"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.tag
  }
}

# Create network interface
resource "azurerm_network_interface" "tfwebnic" {
  count                     = var.webcount
  name                      = "${var.prefix}-webnic${count.index}"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.tfrg.name
  #-network_security_group_id = azurerm_network_security_group.tfwebnsg.id

  ip_configuration {
    name      = "${var.prefix}-webnic-config${count.index}"
    subnet_id = azurerm_subnet.tfwebvnet.id

    #private_ip_address_allocation = "dynamic"
    private_ip_address_allocation = "Static"
    private_ip_address            = format("10.0.1.%d", count.index + 4)
  }

  tags = {
    environment = var.tag
  }
}

resource "azurerm_network_interface_security_group_association" "tfwebnic" {
  count                     = var.webcount
  network_interface_id      = azurerm_network_interface.tfwebnic[count.index].id
  network_security_group_id = azurerm_network_security_group.tfwebnsg.id
}

resource "azurerm_network_interface_backend_address_pool_association" "tfwebpoolassc" {
  count                   = var.webcount
  network_interface_id    = element(azurerm_network_interface.tfwebnic.*.id, count.index)
  ip_configuration_name   = "${var.prefix}-webnic-config${count.index}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.tflbbackendpool.id
}

resource "azurerm_network_interface_nat_rule_association" "tfnatruleassc" {
  count                 = var.webcount
  network_interface_id  = element(azurerm_network_interface.tfwebnic.*.id, count.index)
  ip_configuration_name = "${var.prefix}-webnic-config${count.index}"
  nat_rule_id           = element(azurerm_lb_nat_rule.lbnatrule.*.id, count.index)
}

resource "azurerm_network_interface_application_security_group_association" "tfwebsecassc" {
  count                         = var.webcount
  network_interface_id          = element(azurerm_network_interface.tfwebnic.*.id, count.index)
  #-ip_configuration_name         = "${var.prefix}-webnic-config${count.index}"
  application_security_group_id = azurerm_application_security_group.tfwebasg.id
}

resource "azurerm_availability_set" "tfwebavset" {
  name                        = "${var.prefix}-webavset"
  location                    = var.location
  resource_group_name         = azurerm_resource_group.tfrg.name
  managed                     = "true"
  platform_fault_domain_count = 2 # default 3 not working in some regions like Korea

  tags = {
    environment = var.tag
  }
}

# Create virtual machine
resource "azurerm_virtual_machine" "tfwebvm" {
  count                 = var.webcount
  name                  = "${var.prefix}webvm${count.index}"
  location              = var.location
  resource_group_name   = azurerm_resource_group.tfrg.name
  network_interface_ids = [azurerm_network_interface.tfwebnic[count.index].id]
  vm_size               = var.vmsize
  availability_set_id   = azurerm_availability_set.tfwebavset.id

  storage_os_disk {
    name              = format("%s-web-%03d-osdisk", var.prefix, count.index + 1)
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  /*
  # custom image
  storage_image_reference {
    id = "${var.osimageuri}"
  }
  */

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = format("tfwebvm%03d", count.index + 1)
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

resource "azurerm_virtual_machine_extension" "webvmext" {
  count                = var.webcount
  name                 = "webvmext"
  virtual_machine_id   = azurerm_virtual_machine.tfwebvm[count.index].id
  #-location             = var.location
  #-resource_group_name  = azurerm_resource_group.tfrg.name
  #-virtual_machine_name = azurerm_virtual_machine.tfwebvm[count.index].name
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "script": "IyEvYmluL3NoCgpzdWRvIGFwdC1nZXQgdXBkYXRlCnN1ZG8gYXB0LWdldCAteSBpbnN0YWxsIG5naW54Cg=="
    }
    SETTINGS


  tags = {
    environment = var.tag
  }
}

resource "azurerm_public_ip" "tflbpip" {
  name                = "${var.prefix}-flbpip"
  location            = var.location
  resource_group_name = azurerm_resource_group.tfrg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "tflb" {
  name                = "${var.prefix}lb"
  location            = var.location
  resource_group_name = azurerm_resource_group.tfrg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.tflbpip.id
  }
}

resource "azurerm_lb_backend_address_pool" "tflbbackendpool" {
  resource_group_name = azurerm_resource_group.tfrg.name
  loadbalancer_id     = azurerm_lb.tflb.id
  name                = "BackEndAddressPool"
}

resource "azurerm_lb_nat_rule" "lbnatrule" {
  count                          = var.webcount
  resource_group_name            = azurerm_resource_group.tfrg.name
  loadbalancer_id                = azurerm_lb.tflb.id
  name                           = "ssh-${count.index}"
  protocol                       = "tcp"
  frontend_port                  = "5000${count.index + 1}"
  backend_port                   = 22
  frontend_ip_configuration_name = "PublicIPAddress" # "${azurerm_lb.tflb.frontend_ip_configuration.name}" not working
}

resource "azurerm_lb_rule" "lb_rule" {
  resource_group_name            = azurerm_resource_group.tfrg.name
  loadbalancer_id                = azurerm_lb.tflb.id
  name                           = "LBRule"
  protocol                       = "tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  enable_floating_ip             = false
  backend_address_pool_id        = azurerm_lb_backend_address_pool.tflbbackendpool.id
  idle_timeout_in_minutes        = 5
  probe_id                       = azurerm_lb_probe.lb_probe.id
  depends_on                     = [azurerm_lb_probe.lb_probe]
}

resource "azurerm_lb_probe" "lb_probe" {
  resource_group_name = azurerm_resource_group.tfrg.name
  loadbalancer_id     = azurerm_lb.tflb.id
  name                = "tcpProbe"
  protocol            = "tcp"
  port                = 80
  interval_in_seconds = 5
  number_of_probes    = 2
}

output "weblb_pip" {
  value = azurerm_public_ip.tflbpip.*.ip_address
}
