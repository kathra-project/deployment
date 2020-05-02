variable "version_chart" {
    default = "v0.12.0"
}
variable "kube_config" {
}
variable "namespace" {
}
variable "issuer_name" {
    default =  "letsencrypt-prod"
}
variable "email" {
    default =  "contact@kathra.org"
}

data "template_file" "clusterIssuer" {
  template = file("${path.module}/clusterIssuer.yaml.tpl")
  vars = {
    clusterIssuerName = var.issuer_name
    email = var.email
  }
}
resource "local_file" "clusterIssuer" {
    content     = data.template_file.clusterIssuer.rendered
    filename    = "${path.module}/clusterIssuer.yaml"
}

data "helm_repository" "jetstack" {
  name = "jetstack"
  url  = "https://charts.jetstack.io"
}

resource "null_resource" "preConfigure" {
    triggers = {
        timestamp        = timestamp()
    }
  provisioner "local-exec" {
    command = <<EOT
      echo "
apiVersion: v1
kind: Config
preferences:
  colors: true
current-context: tf-k8s
contexts:
- context:
    cluster: kathra
    namespace: default
    user: local
  name: tf-k8s
clusters:
- cluster:
    server: ${var.kube_config.host}
    certificate-authority-data: ${var.kube_config.cluster_ca_certificate}
  name: kathra
users:
- name: local
  user:
    client-certificate-data: ${var.kube_config.client_certificate}
    client-key-data: ${var.kube_config.client_key}" > /tmp/kathra_kube_config
    
kubectl --kubeconfig=/tmp/kathra_kube_config apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.12/deploy/manifests/00-crds.yaml --namespace ${var.namespace}
    EOT
  }
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = data.helm_repository.jetstack.metadata[0].name
  chart      = "jetstack/cert-manager"
  version    = var.version_chart
  namespace  = var.namespace
  set {
    name  = "ingressShim.defaultIssuerKind"
    value = "ClusterIssuer"
  }
  set {
    name  = "ingressShim.defaultIssuerName"
    value = var.issuer_name
  }
  depends_on = [null_resource.preConfigure]
}

resource "null_resource" "postInstall" {
  triggers = {
    timestamp        = timestamp()
  }
  provisioner "local-exec" {
    command = <<EOT
      echo "
apiVersion: v1
kind: Config
preferences:
  colors: true
current-context: tf-k8s
contexts:
- context:
    cluster: kathra
    namespace: default
    user: local
  name: tf-k8s
clusters:
- cluster:
    server: ${var.kube_config.host}
    certificate-authority-data: ${var.kube_config.cluster_ca_certificate}
  name: kathra
users:
- name: local
  user:
    client-certificate-data: ${var.kube_config.client_certificate}
    client-key-data: ${var.kube_config.client_key}" > /tmp/kathra_kube_config

kubectl --kubeconfig=/tmp/kathra_kube_config apply -f ${local_file.clusterIssuer.filename} --namespace ${var.namespace} --validate=false --overwrite || exit 1
kubectl --kubeconfig=/tmp/kathra_kube_config label namespace ${var.namespace} certmanager.k8s.io/disable-validation=true --overwrite || exit 1
   EOT
    environment = {
      MANIFEST = local_file.clusterIssuer.filename
    }
  }
  depends_on = [helm_release.cert_manager]
}


output "namespace" {
  value = helm_release.cert_manager.namespace
}
output "issuer" {
  value = yamldecode(helm_release.cert_manager.metadata[0].values).ingressShim.defaultIssuerName
}

