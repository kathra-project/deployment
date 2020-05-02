
variable domain {
}

resource "google_compute_address" "static" {
    name = "kathra-ipv4-static"
}

resource "null_resource" "check_dns_resolution" {
    triggers = {
        timestamp        = timestamp()
    }
    provisioner "local-exec" {
      command = <<EOT
          echo "Trying to resolv DNS test.$DOMAIN  -> $IP"
          for attempt in $(seq 1 100); do sleep 5 && nslookup test-$attempt.$DOMAIN | grep "$IP" && exit 0 || echo "Unable to resolv DNS *.$DOMAIN -> $IP ($attempt/100)"; done
          exit 1
    EOT
      environment = {
        IP = google_compute_address.static.address
        DOMAIN = var.domain
      }
    }
}

output "public_ip_address" {
  value = google_compute_address.static.address
}

