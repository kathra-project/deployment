
variable "kube_config" {
  
}

data "template_file" "kube_config" {
  template = file("${path.module}/kubeconfig-template.yaml")

  vars = {
    cluster_name    = var.kube_config.name
    user_name       = var.kube_config.username
    user_password   = var.kube_config.password
    host            = var.kube_config.host
    cluster_ca      = var.kube_config.cluster_ca_certificate
    client_cert     = var.kube_config.client_certificate
    client_cert_key = var.kube_config.client_key
  }
}

output "kube_config_raw" {
  value = data.template_file.kube_config.rendered
}
