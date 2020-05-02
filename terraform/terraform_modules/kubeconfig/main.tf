
variable "kube_config" {
  
}

data "template_file" "kube_config" {
  template = file("${path.module}/kubeconfig-template.yaml")

  vars = {
    cluster_name    = kube_config.name
    user_name       = kube_config.username
    user_password   = kube_config.password
    endpoint        = kube_config.host
    cluster_ca      = kube_config.cluster_ca_certificate
    client_cert     = kube_config.client_certificate
    client_cert_key = kube_config.client_key
  }
}

output "kube_config_raw" {
  value = data.template_file.kube_config.rendered
}
