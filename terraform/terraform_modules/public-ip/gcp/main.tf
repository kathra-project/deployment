
variable domain {
}

resource "google_compute_address" "static" {
<<<<<<< HEAD
    name = "kathra-ipv4-static-address"
=======
    name = "kathra-ipv4-static"
>>>>>>> feature/factory_tf
}

resource "null_resource" "check_dns_resolution" {
    provisioner "local-exec" {
      command = <<EOT
          echo "Trying to resolv DNS test.$DOMAIN  -> $IP"
<<<<<<< HEAD
          for attempt in $(seq 1 100); do sleep 5 && nslookup test.$DOMAIN | grep "$IP" && exit 0 || echo "Unable to resolv DNS *.$DOMAIN -> $IP ($attempt/100)"; done
=======
          for attempt in $(seq 1 100); do sleep 5 && nslookup test-$attempt.$DOMAIN | grep "$IP" && exit 0 || echo "Unable to resolv DNS *.$DOMAIN -> $IP ($attempt/100)"; done
>>>>>>> feature/factory_tf
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

