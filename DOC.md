# Terraform

## VM login

By password:

```
  # alternative login method
  os_profile {
      computer_name  = "tfjobxvm${count.index}"
      admin_username = "${var.admin_username}"
      admin_password = "${var.admin_password}"
  }

  os_profile_linux_config {
      disable_password_authentication = false
  }
```

By ssh public key:

```
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
```

## OS and data disk

To attach os disk size with >30GiB and attach data disk,

```
  storage_os_disk {
    name              = "${format("%s-app-%03d-osdisk", var.prefix, count.index + 1)}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"

    disk_size_gb      = "64" # increase default os disk
  }


 # add extra data disk
  storage_data_disk {
	name              = "${format("%s-app-%03d-datadisk", var.prefix, count.index + 1)}"
	managed_disk_type = "Premium_LRS"
	create_option     = "Empty"
	lun               = 0
	disk_size_gb      = "128"        
  }
```

Note: Some OSs do not automatically increase disk size. To increase os disk size, please refer: https://blogs.msdn.microsoft.com/linuxonazure/2017/04/03/how-to-resize-linux-osdisk-partition-on-azure/

## OS image

For azure provided images,

```
  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }
```

Note: getting az image list, `az vm image list --offer UbuntuServer --all --output table `

For custom/user image,

```
  storage_image_reference {
    id = "${var.osimageuri}"
  }
```  

Note: To get `id`, copy `uri id` from image

## Create multiple VMs

Use `count` and `${count.index}` to create repeatable resources

```
resource "azurerm_virtual_machine" "tfwebvm" {
  count                 = "${var.webcount}"
  name                  = "${var.prefix}webvm${count.index}"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.tfrg.name}"
  network_interface_ids = ["${azurerm_network_interface.tfwebnic.*.id[count.index]}"]
  vm_size               = "${var.vmsize}"
  availability_set_id   = "${azurerm_availability_set.tfwebavset.id}"

  storage_os_disk {
    name              = "${format("%s-web-%03d-osdisk", var.prefix, count.index + 1)}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  # custom image
  storage_image_reference {
    id = "${var.osimageuri}"
  }

  ...
}
```

## Load Balancer

To attach VM to lb, add `load_balancer_backend_address_pools_ids` in nic's `ip_configuration` like below

```
resource "azurerm_network_interface" "tfwebnic" {
  count                     = "${var.webcount}"
  name                      = "${var.prefix}-webnic${count.index}"
  location                  = "${var.location}"
  resource_group_name       = "${azurerm_resource_group.tfrg.name}"
  network_security_group_id = "${azurerm_network_security_group.tfwebnsg.id}"

  ip_configuration {
    name                          = "${var.prefix}-webnic-config${count.index}"
    subnet_id                     = "${azurerm_subnet.tfwebvnet.id}"
    private_ip_address_allocation = "dynamic"

    load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.tflbbackendpool.id}"]
    load_balancer_inbound_nat_rules_ids = ["${azurerm_lb_nat_rule.lbnatrule.*.id[count.index]}"]
  }
}
```

## NAT instance

> NAT instance is no longer needed and use [NAT Gateway](https://docs.microsoft.com/en-us/azure/virtual-network/nat-overview).

For NAT Instance VM, enable `enable_ip_forwarding` in VM's nic

```
resource "azurerm_network_interface" "tfnatnic" {
  name                      = "${var.prefix}-natnic"
  location                  = "${var.location}"
  resource_group_name       = "${azurerm_resource_group.tfrg.name}"
  network_security_group_id = "${azurerm_network_security_group.tfnatnsg.id}"
  enable_ip_forwarding      = "true"
}
```

Also, configure routetable and set UDR in subnet

```
resource "azurerm_subnet" "tfappvnet" {
  name                 = "app-subnet"
  virtual_network_name = "${azurerm_virtual_network.tfvnet.name}"
  resource_group_name  = "${azurerm_resource_group.tfrg.name}"
  address_prefix       = "10.0.2.0/24"
  route_table_id       = "${azurerm_route_table.nattable.id}"

  depends_on = ["azurerm_route_table.nattable"]
}
```

Lastly, add vm extension to install/configure NAT

```
resource "azurerm_virtual_machine_extension" "vmext" {
  name                 = "vmext"
  location             = "${var.location}"
  resource_group_name  = "${azurerm_resource_group.tfrg.name}"
  virtual_machine_name = "${azurerm_virtual_machine.tfnatvm.name}"
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "script": "cHY0LmlwX2ZvcndhcmQgPSAxCmNwIC9ldGMvc3lzY3RsLmNvbmYgL3RtcC9zeXNjdGwuY29uZgplY2hvICJuZXQuaXB2NC5pcF9mb3J3YXJkID0gMSIgPj4gL3RtcC9zeXNjdGwuY29uZgpzdWRvIGNwIC90bXAvc3lzY3RsLmNvbmYgL2V0Yy9zeXNjdGwuY29uZgoKIyBmaXJld2FsbGQKc3VkbyAvZXRjL2luaXQuZC9uZXR3b3JraW5nIHJlc3RhcnQKc3VkbyBhcHQtZ2V0IGluc3RhbGwgLXkgZmlyZXdhbGxkCnN1ZG8gc3lzdGVtY3RsIGVuYWJsZSBmaXJld2FsbGQKc3VkbyBzeXN0ZW1jdGwgc3RhcnQgZmlyZXdhbGxkCnN1ZG8gZmlyZXdhbGwtY21kIC0tc3RhdGUKc3VkbyBmaXJld2FsbC1jbWQgLS1zZXQtZGVmYXVsdC16b25lPWV4dGVybmFsCnN1ZG8gZmlyZXdhbGwtY21kIC0tcmVsb2FkCg=="
    }
    SETTINGS
}
```

For NAT script, see [script](./script)

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
