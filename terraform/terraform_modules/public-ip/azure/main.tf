variable "group" {
}
variable location {
}
variable domain {
}

resource "azurerm_public_ip" "public_ip" {
  name                = "static-ip"
  location            = var.location
  resource_group_name = var.group
  allocation_method   = "Static"
}


resource "null_resource" "check_dns_resolution" {
    triggers = {
        timestamp        = timestamp()
    }
    provisioner "local-exec" {
      command = <<EOT
          echo "Trying to resolv DNS test.$DOMAIN  -> $IP"
          for attempt in $(seq 1 100); do sleep 5 && nslookup test.$DOMAIN | grep "$IP" && "DNS entry "$DOMAIN" has ip $IP" && exit 0 || echo "Unable to resolv DNS *.$DOMAIN -> $IP ($attempt/100)"; done
          exit 1
    EOT
      environment = {
        IP = azurerm_public_ip.public_ip.ip_address
        DOMAIN = var.domain
      }
    }
}

output "public_ip_address" {
  value = azurerm_public_ip.public_ip.ip_address
}