# VMSS
#https://www.terraform.io/docs/providers/azurerm/r/linux_virtual_machine_scale_set.html

resource "azurerm_linux_virtual_machine_scale_set" "tfrg" {

  name                = "${var.resource.prefix}webvm"
  location            = var.resource.location
  resource_group_name = azurerm_resource_group.tfrg.name

  upgrade_mode        = "Automatic"
  /*automatic_os_upgrade_policy = {
    disable_automatic_rollback  = true
    enable_automatic_os_upgrade = false
  }*/

  overprovision        = false

  sku                  = var.vm.size
  instances            = var.vm.webcount

  computer_name_prefix  = "${var.resource.prefix}webvm"
  admin_username        = var.vm.admin_username
  admin_password        = var.vm.admin_password
  disable_password_authentication = false

  custom_data    = base64encode( file("../script/cloud-init.txt") )

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    //disk_size_gb    = 128
  }

  //source_image_id = var.vm.osimageuri
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  network_interface {
    name                      = "networkinterface"
    primary                   = true
    network_security_group_id = azurerm_network_security_group.tfwebnsg.id

    ip_configuration {
      name                                   = "ipconfig"
      primary                                = true
      subnet_id                              = azurerm_subnet.tfwebvnet.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.vmss.id]
      load_balancer_inbound_nat_rules_ids    = [azurerm_lb_nat_pool.vmss.id]
    }
  }
}

# Public LB
resource "azurerm_public_ip" "vmss" {
  name                = "vmss-pip"
  location            = var.resource.location
  resource_group_name = azurerm_resource_group.tfrg.name
  allocation_method   = "Static"

  sku                 = "Standard"
}

resource "azurerm_lb" "vmss" {
  name                = "vmss-lb"
  location            = var.resource.location
  resource_group_name = azurerm_resource_group.tfrg.name

  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "vmss-ipconfig"
    public_ip_address_id = azurerm_public_ip.vmss.id
  }
}

resource "azurerm_lb_rule" "vmss" {
  loadbalancer_id                = azurerm_lb.vmss.id
  name                           = "vmss-lbrule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "vmss-ipconfig"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.vmss.id]
  probe_id                       = azurerm_lb_probe.vmss.id
}

resource "azurerm_lb_backend_address_pool" "vmss" {
  loadbalancer_id     = azurerm_lb.vmss.id
  name                = "vmss-bepool"
}

resource "azurerm_lb_nat_pool" "vmss" {
  resource_group_name            = azurerm_resource_group.tfrg.name
  name                           = "SSH"
  loadbalancer_id                = azurerm_lb.vmss.id
  protocol                       = "Tcp"
  frontend_port_start            = 50000
  frontend_port_end              = 50119
  backend_port                   = 22
  frontend_ip_configuration_name = "vmss-ipconfig"
}

resource "azurerm_lb_probe" "vmss" {
  loadbalancer_id     = azurerm_lb.vmss.id
  name                = "healthprobe"
  protocol            = "Tcp"
  port                = 80
}


output "vmss_ip_address" {
  value = azurerm_public_ip.vmss.ip_address
}