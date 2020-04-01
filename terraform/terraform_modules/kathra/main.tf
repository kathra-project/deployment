
variable "charts_version" {
}
variable "images_tag" {
}
variable "domain" {
}
variable "kube_config_file" {
}
variable "ingress_controller" {
  default = "traefik"
}

resource "null_resource" "kathraInstaller" {
  provisioner "local-exec" {
    command = <<EOT
      echo "CONFIG:$CONFIG"
      echo "DOMAIN:$DOMAIN"
      echo "CHARTS_VERSION:$CHARTS_VERSION"
      echo "IMAGES_TAG:$IMAGES_TAG"
      export KUBECONFIG="$(pwd)/$CONFIG"

      [ -d /tmp/kathra-deployment-tf ] && rm -rf /tmp/kathra-deployment-tf
      git clone https://gitlab.com/kathra/deployment.git /tmp/kathra-deployment-tf || exit 1
      cd /tmp/kathra-deployment-tf && git checkout $CHARTS_VERSION || exit 1
      /tmp/kathra-deployment-tf/install.sh --domain=$DOMAIN --chart-version=$CHARTS_VERSION --kathra-image-tag=$IMAGES_TAG --enable-tls-ingress --verbose || exit 1
   EOT
    environment = {
      CONFIG = var.kube_config_file
      CHARTS_VERSION = var.charts_version
      IMAGES_TAG = var.images_tag
      DOMAIN = var.domain
    }
  }
}

