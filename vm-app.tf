# Create Network Security Group and rule
resource "azurerm_network_security_group" "tfappnsg" {
  name                = "${var.resource.prefix}-appnsg"
  location            = var.resource.location
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
    environment = var.resource.tag
  }
}

# Create network interface
resource "azurerm_network_interface" "tfappnic" {
  count               = var.vm.appcount
  name                = "${var.resource.prefix}-appnic${count.index}"
  location            = var.resource.location
  resource_group_name = azurerm_resource_group.tfrg.name

  #-network_security_group_id = azurerm_network_security_group.tfappnsg.id

  ip_configuration {
    name      = "${var.resource.prefix}-appnic-conf${count.index}"
    subnet_id = azurerm_subnet.tfappvnet.id

    #private_ip_address_allocation = "dynamic"
    private_ip_address_allocation = "Static"
    private_ip_address            = format("10.0.2.%d", count.index + 4)
  }

  tags = {
    environment = var.resource.tag
  }
}

resource "azurerm_network_interface_security_group_association" "tfappnic" {
  count                     = var.vm.appcount
  network_interface_id      = azurerm_network_interface.tfappnic[count.index].id
  network_security_group_id = azurerm_network_security_group.tfappnsg.id
}

resource "azurerm_network_interface_backend_address_pool_association" "tfapppoolassc" {
  count                   = var.vm.appcount
  network_interface_id    = element(azurerm_network_interface.tfappnic.*.id, count.index)
  ip_configuration_name   = "${var.resource.prefix}-appnic-conf${count.index}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.tfapplbbackendpool.id
}

resource "azurerm_network_interface_application_security_group_association" "tfappsecassc" {
  count                         = var.vm.appcount
  network_interface_id          = element(azurerm_network_interface.tfappnic.*.id, count.index)
  #-ip_configuration_name         = "${var.resource.prefix}-appnic-conf${count.index}"
  application_security_group_id = azurerm_application_security_group.tfappasg.id
}

resource "azurerm_availability_set" "tfappavset" {
  name                        = "${var.resource.prefix}-appavset"
  location                    = var.resource.location
  resource_group_name         = azurerm_resource_group.tfrg.name
  managed                     = "true"
  platform_fault_domain_count = 2 # default 3 cannot be used

  tags = {
    environment = var.resource.tag
  }
}

# Create virtual machine
# https://www.terraform.io/docs/providers/azurerm/r/linux_virtual_machine.html
resource "azurerm_linux_virtual_machine" "tfappvm" {
  count                 = var.vm.appcount
  name                  = "${var.resource.prefix}appvm${count.index}"
  location              = var.resource.location
  resource_group_name   = azurerm_resource_group.tfrg.name
  network_interface_ids = [azurerm_network_interface.tfappnic[count.index].id]
  size                  = var.vm.size
  availability_set_id   = azurerm_availability_set.tfappavset.id

  computer_name  = format("tfappvm%03d", count.index + 1)
  admin_username = var.vm.admin_username
  admin_password = var.vm.admin_password
  disable_password_authentication = false

  custom_data    = base64encode( file("./script/cloud-init.txt") )

  os_disk {
    name                 = format("%s-app-%03d-osdisk", var.resource.prefix, count.index + 1)
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"

    disk_size_gb = "64" # increase default os disk
  }

  //source_image_id = "${var.vm.osimageuri}"
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

resource "azurerm_lb" "tfapplb" {
  name                = "${var.resource.prefix}applb"
  location            = var.resource.location
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
  ##resource_group_name = azurerm_resource_group.tfrg.name
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
