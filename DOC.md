# Terraform

> New `azurerm_linux_virtual_machine` is used.

## VM login

By password:

```
  # alternative login method
  computer_name  = "vm${count.index}"
  admin_username = "${var.vm.admin_username}"
  admin_password = "${var.vm.admin_password}"

  disable_password_authentication = false
```

By ssh public key:

```
  computer_name  = "vm${count.index}"
  admin_username = "${var.vm.admin_username}"

  disable_password_authentication = true

  admin_ssh_keys {
    username = "azureuser"
    key_data = file("~/.ssh/id_rsa.pub")
  }
```

## OS and data disk

To attach os disk size with >30GiB.

```
  os_disk {
    name                 = "${format("%s-app-%03d-osdisk", var.resource.prefix, count.index + 1)}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"

    disk_size_gb      = "64" # increase default os disk
  }
```

> Note: Some OSs do not automatically increase disk size. To increase os disk size, please refer: https://blogs.msdn.microsoft.com/linuxonazure/2017/04/03/how-to-resize-linux-osdisk-partition-on-azure/

Method of attaching data disk changed. See [azurerm_virtual_machine_data_disk_attachment](https://www.terraform.io/docs/providers/azurerm/r/virtual_machine_data_disk_attachment.html) for more information.

## OS image

For azure provided images,

```
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }
```

Note: getting az image list, `az vm image list --offer UbuntuServer --all --output table `

For custom/user image,

```
  source_image_id = "${var.vm.osimageuri}"
```  

Note: To get `id`, copy `uri id` from image

## Create multiple VMs

Use `count` and `${count.index}` to create repeatable resources

```
resource "azurerm_linux_virtual_machine" "tfwebvm" {
  count                 = var.vm.webcount
  name                  = "${var.resource.prefix}webvm${count.index}"
  location              = var.resource.location
  resource_group_name   = azurerm_resource_group.tfrg.name
  network_interface_ids = [azurerm_network_interface.tfwebnic[count.index].id]
  vm_size               = var.vmsize
  availability_set_id   = azurerm_availability_set.tfwebavset.id

  computer_name  = format("tfwebvm%03d", count.index + 1)
  admin_username = var.vm.admin_username
  admin_password = var.vm.admin_password
  disable_password_authentication = false

  ...
}
```

## Cloud-Init

__cloud-init__ is used instead of __custom script__ with VM Extension for this demo. Declare `custom_data` in `azurerm_linux_virtual_machine`/

```
  custom_data    = base64encode( file("./script/cloud-init.txt") )
```

## Load Balancer

To attach VM to lb, add `load_balancer_backend_address_pools_ids` in nic's `ip_configuration` like below

```
resource "azurerm_network_interface" "tfwebnic" {
  count                     = "${var.vm.webcount}"
  name                      = "${var.resource.prefix}-webnic${count.index}"
  location                  = "${var.resource.location}"
  resource_group_name       = "${azurerm_resource_group.tfrg.name}"
  network_security_group_id = "${azurerm_network_security_group.tfwebnsg.id}"

  ip_configuration {
    name                          = "${var.resource.prefix}-webnic-config${count.index}"
    subnet_id                     = "${azurerm_subnet.tfwebvnet.id}"
    private_ip_address_allocation = "dynamic"

    load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.tflbbackendpool.id}"]
    load_balancer_inbound_nat_rules_ids = ["${azurerm_lb_nat_rule.lbnatrule.*.id[count.index]}"]
  }
}
```

## NAT instance

NAT instance is no longer needed and use [NAT Gateway](https://docs.microsoft.com/en-us/azure/virtual-network/nat-overview).

## ASG

ASG is supported from terraform `azure provider 1.2` and you can create ASG resource.

Define ASG,

```
resource "azurerm_application_security_group" "tfappasg" {
  name                = "tf-appasg"
  location            = "${azurerm_resource_group.tfrg.location}"
  resource_group_name = "${azurerm_resource_group.tfrg.name}"
}
```

Add ASG to nics

```
resource "azurerm_network_interface" "tfwebnic" {
  ...

  ip_configuration {
    ...
    application_security_group_ids = ["${azurerm_application_security_group.tfwebasg.id}"]
  }
}

```

ASG rule feature added in azure prover 1.3. To allow only traffic between ASG tag you need to add both `DENY_VNET` and `ALLOW_LB` rules first then add ASG rule. `ALLOW_LB` rule is needed because LB won't work without health probing.

```
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
    name                   = "HTTP_VNET"
    priority               = 1000
    direction              = "Inbound"
    access                 = "Allow"
    protocol               = "Tcp"
    source_port_range      = "*"
    destination_port_range = "80"

    source_application_security_group_ids = ["${azurerm_application_security_group.tfwebasg.id}"]
    destination_application_security_group_ids = ["${azurerm_application_security_group.tfappasg.id}"]
  }
```

## Some issue

For availableset, default 3 not working in some regions like Korea, use 2 instead.

```
platform_fault_domain_count = 2
```
