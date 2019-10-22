resource "azurerm_kubernetes_cluster" "tfaks" {
  name                = "${var.prefix}-aks"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.tfrg.name}"
  dns_prefix          = "${var.prefix}dns"

  #kubernetes_version = "1.13.11"
  
  agent_pool_profile {
    name            = "default"
    count           = 2
    min_count       = 2
    max_count       = 3
    vm_size         = "Standard_DS1_v2"
    os_type         = "Linux"
    os_disk_size_gb = 128

    # Autoscale
    type            = "VirtualMachineScaleSets"
    enable_auto_scaling = true

    # AZ
    availability_zones = [1, 2]

    vnet_subnet_id = "${azurerm_subnet.tfaksvnet.id}"
  }

  agent_pool_profile {
    name            = "gpu"
    count           = 1
    min_count       = 1
    max_count       = 2
    vm_size         = "Standard_DS1_v2" #"Standard_NC6"
    os_type         = "Linux"
    os_disk_size_gb = 128

    # Autoscale
    type            = "VirtualMachineScaleSets"
    enable_auto_scaling = true

    vnet_subnet_id = "${azurerm_subnet.tfaksvnet.id}"
  }

  network_profile {
    network_plugin = "azure"
    load_balancer_sku = "standard"
  }

  service_principal {
    client_id       = "${var.client_id}"
    client_secret   = "${var.client_secret}"
  }

  tags = {
    environment = "${var.tag}"
  }
}

output "client_certificate" {
  value = "${azurerm_kubernetes_cluster.tfaks.kube_config.0.client_certificate}"
}

output "kube_config" {
  value = "${azurerm_kubernetes_cluster.tfaks.kube_config_raw}"
}