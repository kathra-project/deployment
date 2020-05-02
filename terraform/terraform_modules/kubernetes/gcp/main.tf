variable "project_name" {
}
variable location {
}
variable "node_count" {
    default = 4
}
variable "kubernetes_version" {
    default = "1.15.10"
}

resource "random_id" "username" {
    byte_length = 14
}

resource "random_id" "password" {
    byte_length = 16
}

resource "google_container_cluster" "kubernetes" {
    name               = "kathra-cluster"
    initial_node_count = var.node_count

    master_auth {
        username = random_id.username.hex
        password = random_id.password.hex
        client_certificate_config {
            issue_client_certificate = true
        }
    }

    node_config {
        machine_type = "n1-standard-4"

        oauth_scopes = [
            "https://www.googleapis.com/auth/compute",
            "https://www.googleapis.com/auth/devstorage.read_only",
            "https://www.googleapis.com/auth/logging.write",
            "https://www.googleapis.com/auth/monitoring",
        ]

        tags = ["kathra-cluster"]
    }
}


resource "kubernetes_storage_class" "default" {
    metadata {
        name = "default"
    }
    storage_provisioner = "kubernetes.io/gce-pd"
    reclaim_policy      = "Retain"
    parameters = {
        type = "pd-standard"
    }
}

provider "kubernetes" {
    load_config_file       = "false"
    host                   = google_container_cluster.kubernetes.endpoint
    client_certificate     = base64decode(google_container_cluster.kubernetes.master_auth[0].client_certificate)
    client_key             = base64decode(google_container_cluster.kubernetes.master_auth[0].client_key)
    cluster_ca_certificate = base64decode(google_container_cluster.kubernetes.master_auth[0].cluster_ca_certificate)
}



/*********************
    HELM INIT
************************/

provider "helm" {
    install_tiller  = true
    version         = "0.10.4"
    service_account = kubernetes_service_account.tiller.metadata.0.name
    namespace       = kubernetes_service_account.tiller.metadata.0.namespace
    kubernetes {
        load_config_file       = "false"
        host                   = google_container_cluster.kubernetes.endpoint
        client_certificate     = base64decode(google_container_cluster.kubernetes.master_auth[0].client_certificate)
        client_key             = base64decode(google_container_cluster.kubernetes.master_auth[0].client_key)
        cluster_ca_certificate = base64decode(google_container_cluster.kubernetes.master_auth[0].cluster_ca_certificate)
    }
}

resource "kubernetes_service_account" "tiller" {
    metadata {
        name      = "tiller"
        namespace = "kube-system"
    }
    automount_service_account_token = true
}

resource "kubernetes_cluster_role_binding" "tiller" {
    metadata {
        name = "tiller"
    }

    role_ref {
        kind      = "ClusterRole"
        name      = "cluster-admin"
        api_group = "rbac.authorization.k8s.io"
    }

    subject {
        kind      = "ServiceAccount"
        name      = "default"
        namespace = "kube-system"
    }
    subject {
        kind      = "ServiceAccount"
        name      = kubernetes_service_account.tiller.metadata[0].name
        namespace = "kube-system"
    }
}

output "tiller_ns" {
    value = kubernetes_service_account.tiller.metadata.0.namespace
}

output "kubeconfig" {
    value = {
        cluster_name              =  google_container_cluster.kubernetes.name
        host                      =  google_container_cluster.kubernetes.endpoint
        username                  =  google_container_cluster.kubernetes.master_auth[0].username
        password                  =  google_container_cluster.kubernetes.master_auth[0].password
        client_certificate        =  google_container_cluster.kubernetes.master_auth[0].client_certificate
        client_key                =  google_container_cluster.kubernetes.master_auth[0].client_key
        cluster_ca_certificate    =  google_container_cluster.kubernetes.master_auth[0].cluster_ca_certificate
    }
}