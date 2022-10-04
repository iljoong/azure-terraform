# Create Network Security Group and rule
resource "azurerm_network_security_group" "tfwebnsg" {
  name                = "${var.resource.prefix}-webnsg"
  location            = var.resource.location
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
    environment = var.resource.tag
  }
}

# Create network interface
resource "azurerm_network_interface" "tfwebnic" {
  count                     = var.vm.webcount
  name                      = "${var.resource.prefix}-webnic${count.index}"
  location                  = var.resource.location
  resource_group_name       = azurerm_resource_group.tfrg.name
  #-network_security_group_id = azurerm_network_security_group.tfwebnsg.id

  ip_configuration {
    name      = "${var.resource.prefix}-webnic-config${count.index}"
    subnet_id = azurerm_subnet.tfwebvnet.id

    #private_ip_address_allocation = "dynamic"
    private_ip_address_allocation = "Static"
    private_ip_address            = format("10.0.1.%d", count.index + 4)
  }

  tags = {
    environment = var.resource.tag
  }
}

resource "azurerm_network_interface_security_group_association" "tfwebnic" {
  count                     = var.vm.webcount
  network_interface_id      = azurerm_network_interface.tfwebnic[count.index].id
  network_security_group_id = azurerm_network_security_group.tfwebnsg.id
}

resource "azurerm_network_interface_backend_address_pool_association" "tfwebpoolassc" {
  count                   = var.vm.webcount
  network_interface_id    = element(azurerm_network_interface.tfwebnic.*.id, count.index)
  ip_configuration_name   = "${var.resource.prefix}-webnic-config${count.index}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.tflbbackendpool.id
}

resource "azurerm_network_interface_nat_rule_association" "tfnatruleassc" {
  count                 = var.vm.webcount
  network_interface_id  = element(azurerm_network_interface.tfwebnic.*.id, count.index)
  ip_configuration_name = "${var.resource.prefix}-webnic-config${count.index}"
  nat_rule_id           = element(azurerm_lb_nat_rule.lbnatrule.*.id, count.index)
}

resource "azurerm_network_interface_application_security_group_association" "tfwebsecassc" {
  count                         = var.vm.webcount
  network_interface_id          = element(azurerm_network_interface.tfwebnic.*.id, count.index)
  #-ip_configuration_name         = "${var.resource.prefix}-webnic-config${count.index}"
  application_security_group_id = azurerm_application_security_group.tfwebasg.id
}

resource "azurerm_availability_set" "tfwebavset" {
  name                        = "${var.resource.prefix}-webavset"
  location                    = var.resource.location
  resource_group_name         = azurerm_resource_group.tfrg.name
  managed                     = "true"
  platform_fault_domain_count = 2 # default 3 not working in some regions like Korea

  tags = {
    environment = var.resource.tag
  }
}

# Create virtual machine
# https://www.terraform.io/docs/providers/azurerm/r/linux_virtual_machine.html
resource "azurerm_linux_virtual_machine" "tfwebvm" {
  count                 = var.vm.webcount
  name                  = "${var.resource.prefix}webvm${count.index}"
  location              = var.resource.location
  resource_group_name   = azurerm_resource_group.tfrg.name
  network_interface_ids = [azurerm_network_interface.tfwebnic[count.index].id]
  size                  = var.vm.size
  availability_set_id   = azurerm_availability_set.tfwebavset.id

  computer_name  = format("tfwebvm%03d", count.index + 1)
  admin_username = var.vm.admin_username
  admin_password = var.vm.admin_password
  disable_password_authentication = false

  custom_data    = base64encode( file("./script/cloud-init.txt") )

  os_disk {
    name                 = format("%s-web-%03d-osdisk", var.resource.prefix, count.index + 1)
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
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

resource "azurerm_public_ip" "tflbpip" {
  name                = "${var.resource.prefix}-flbpip"
  location            = var.resource.location
  resource_group_name = azurerm_resource_group.tfrg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  #zones               = ["1"]
}

resource "azurerm_lb" "tflb" {
  name                = "${var.resource.prefix}lb"
  location            = var.resource.location
  resource_group_name = azurerm_resource_group.tfrg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.tflbpip.id
  }
}

resource "azurerm_lb_backend_address_pool" "tflbbackendpool" {
  ##resource_group_name = azurerm_resource_group.tfrg.name
  loadbalancer_id     = azurerm_lb.tflb.id
  name                = "BackEndAddressPool"
}

resource "azurerm_lb_nat_rule" "lbnatrule" {
  count                          = var.vm.webcount
  resource_group_name            = azurerm_resource_group.tfrg.name
  loadbalancer_id                = azurerm_lb.tflb.id
  name                           = "ssh-${count.index}"
  protocol                       = "Tcp"
  frontend_port                  = "5000${count.index + 1}"
  backend_port                   = 22
  frontend_ip_configuration_name = "PublicIPAddress" # "${azurerm_lb.tflb.frontend_ip_configuration.name}" not working
}

resource "azurerm_lb_rule" "lb_rule" {
  loadbalancer_id                = azurerm_lb.tflb.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  enable_floating_ip             = false
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.tflbbackendpool.id]
  idle_timeout_in_minutes        = 5
  probe_id                       = azurerm_lb_probe.lb_probe.id
  depends_on                     = [azurerm_lb_probe.lb_probe]
}

resource "azurerm_lb_probe" "lb_probe" {
  loadbalancer_id     = azurerm_lb.tflb.id
  name                = "tcpProbe"
  protocol            = "Tcp"
  port                = 80
  interval_in_seconds = 5
  number_of_probes    = 2
}

output "weblb_pip" {
  value = azurerm_public_ip.tflbpip.*.ip_address
}
