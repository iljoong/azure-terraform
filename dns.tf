resource "azurerm_dns_a_record" "webappdns" {
  count               = "${var.dnscount}"
  name                = "${var.prefix}"
  zone_name           = "${var.dnszone}"
  resource_group_name = "${var.dnszonerg}"
  ttl                 = 3600
  records             = ["${azurerm_public_ip.tflbpip.ip_address}"]

  depends_on = ["azurerm_public_ip.tflbpip"]
}

output "dns_name" {
  value = "${var.prefix}.${var.dnszone}"
}
