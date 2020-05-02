

variable "namespace" {
}
variable "host" {
}
variable "username" {
}
variable "password" {
}


data "template_file" "docker_config" {
  template = file("${path.module}/docker.config.tpl.json")

  vars = {
    registry            = var.host
    docker_auth_as_b64  = base64encode("${var.username}:${var.password}")
  }
}


resource "kubernetes_secret" "docker_config" {
  metadata {
    name        = "jenkins-docker-config-json"
    namespace   = var.namespace
  }
  data = {
    "config.json"   = data.template_file.docker_config.rendered
  }
}

output "namespace" {
  value = kubernetes_secret.docker_config.metadata[0].namespace
}
output "name" {
  value = kubernetes_secret.docker_config.metadata[0].name
}
