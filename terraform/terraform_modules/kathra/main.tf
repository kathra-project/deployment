
variable "kathra_version" {
    default = "1.0.0"
}
variable "kathra_domain" {
}
variable "kube_config_file" {
    default =  ""
}

resource "null_resource" "kathraInstaller" {
  provisioner "local-exec" {
    command = <<EOT
      export KUBECONFIG=$CONFIG
      [ -d /tmp/kathra-deployment-tf ] && rm -rf /tmp/kathra-deployment-tf
      git clone https://gitlab.com/kathra/deployment.git /tmp/kathra-deployment-tf || exit 1
      cd /tmp/kathra-deployment-tf && git checkout $VERSION || exit 1
      /tmp/kathra-deployment-tf/install.sh --domain=$DOMAIN --chart-version=$VERSION --enable-tls-ingress --verbose || exit 1
   EOT
    environment = {
      CONFIG = var.kube_config_file
      VERSION = var.kathra_version
      DOMAIN = var.kathra_domain
    }
  }
}

