# Create Network Security Group and rule
resource "azurerm_network_security_group" "tfappnsg" {
  name                = "${var.prefix}-appnsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.tfrg.name

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
    name                       = "ALLOW_LB"
    priority                   = 4095
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
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

    source_application_security_group_ids      = [azurerm_application_security_group.tfwebasg.id]
    destination_application_security_group_ids = [azurerm_application_security_group.tfappasg.id]
  }

  tags = {
    environment = var.tag
  }
}

# Create network interface
resource "azurerm_network_interface" "tfappnic" {
  count               = var.appcount
  name                = "${var.prefix}-appnic${count.index}"
  location            = var.location
  resource_group_name = azurerm_resource_group.tfrg.name

  #-network_security_group_id = azurerm_network_security_group.tfappnsg.id

  ip_configuration {
    name      = "${var.prefix}-appnic-conf${count.index}"
    subnet_id = azurerm_subnet.tfappvnet.id

    #private_ip_address_allocation = "dynamic"
    private_ip_address_allocation = "Static"
    private_ip_address            = format("10.0.2.%d", count.index + 4)
  }

  tags = {
    environment = var.tag
  }
}

resource "azurerm_network_interface_security_group_association" "tfappnic" {
  count                     = var.appcount
  network_interface_id      = azurerm_network_interface.tfappnic[count.index].id
  network_security_group_id = azurerm_network_security_group.tfappnsg.id
}

resource "azurerm_network_interface_backend_address_pool_association" "tfapppoolassc" {
  count                   = var.appcount
  network_interface_id    = element(azurerm_network_interface.tfappnic.*.id, count.index)
  ip_configuration_name   = "${var.prefix}-appnic-conf${count.index}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.tfapplbbackendpool.id
}

resource "azurerm_network_interface_application_security_group_association" "tfappsecassc" {
  count                         = var.appcount
  network_interface_id          = element(azurerm_network_interface.tfappnic.*.id, count.index)
  #-ip_configuration_name         = "${var.prefix}-appnic-conf${count.index}"
  application_security_group_id = azurerm_application_security_group.tfappasg.id
}

resource "azurerm_availability_set" "tfappavset" {
  name                        = "${var.prefix}-appavset"
  location                    = var.location
  resource_group_name         = azurerm_resource_group.tfrg.name
  managed                     = "true"
  platform_fault_domain_count = 2 # default 3 cannot be used

  tags = {
    environment = var.tag
  }
}

# Create virtual machine
resource "azurerm_virtual_machine" "tfappvm" {
  count                 = var.appcount
  name                  = "${var.prefix}appvm${count.index}"
  location              = var.location
  resource_group_name   = azurerm_resource_group.tfrg.name
  network_interface_ids = [azurerm_network_interface.tfappnic[count.index].id]
  vm_size               = var.vmsize
  availability_set_id   = azurerm_availability_set.tfappavset.id

  storage_os_disk {
    name              = format("%s-app-%03d-osdisk", var.prefix, count.index + 1)
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
    computer_name  = format("tfappvm%03d", count.index + 1)
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

resource "azurerm_virtual_machine_extension" "appvmext" {
  count                = var.appcount
  name                 = "appvmext"
  virtual_machine_id   = azurerm_virtual_machine.tfappvm[count.index].id
  #-location             = var.location
  #-resource_group_name  = azurerm_resource_group.tfrg.name
  #-virtual_machine_name = azurerm_virtual_machine.tfappvm[count.index].name
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

resource "azurerm_lb" "tfapplb" {
  name                = "${var.prefix}applb"
  location            = var.location
  resource_group_name = azurerm_resource_group.tfrg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "ApplbIPAddress"
    subnet_id                     = azurerm_subnet.tfappvnet.id
    private_ip_address            = "10.0.2.100"
    private_ip_address_allocation = "Static"
  }
}

resource "azurerm_lb_backend_address_pool" "tfapplbbackendpool" {
  resource_group_name = azurerm_resource_group.tfrg.name
  loadbalancer_id     = azurerm_lb.tfapplb.id
  name                = "AppLBBackEndAddressPool"
}

resource "azurerm_lb_rule" "applb_rule" {
  resource_group_name            = azurerm_resource_group.tfrg.name
  loadbalancer_id                = azurerm_lb.tfapplb.id
  name                           = "LBRule"
  protocol                       = "tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "ApplbIPAddress"
  enable_floating_ip             = false
  backend_address_pool_id        = azurerm_lb_backend_address_pool.tfapplbbackendpool.id
  idle_timeout_in_minutes        = 5
  probe_id                       = azurerm_lb_probe.applb_probe.id
  depends_on                     = [azurerm_lb_probe.applb_probe]
}

resource "azurerm_lb_probe" "applb_probe" {
  resource_group_name = azurerm_resource_group.tfrg.name
  loadbalancer_id     = azurerm_lb.tfapplb.id
  name                = "tcpProbe"
  protocol            = "tcp"
  port                = 80
  interval_in_seconds = 5
  number_of_probes    = 2
}
