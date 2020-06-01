variable "group" {}
variable location {}
variable "tenant_id" {}
variable "subscribtion_id" {}
variable "velero_client_id" {}
variable "velero_client_secret" {}
variable "namespace" {}


data "helm_repository" "vmware-tanzu" {
    name = "vmware-tanzu"
    url  = "https://vmware-tanzu.github.io/helm-charts"
}


resource "kubernetes_namespace" "kathra_backup" {
    metadata {
        name = var.namespace
    }
}

resource "azurerm_resource_group" "kathra_backup" {
    name      = var.group
    location  = var.location
}

resource "azurerm_storage_account" "kathra_backup" {
    name                     = "kathrabackupaccountname"
    resource_group_name      = azurerm_resource_group.kathra_backup.name
    location                 = azurerm_resource_group.kathra_backup.location
    account_tier             = "Standard"
    account_replication_type = "LRS"
}

resource "azurerm_storage_container" "kathra_backup" {
    name                  = "kathrabackupcontainer"
    storage_account_name  = azurerm_storage_account.kathra_backup.name
    container_access_type = "private"
}

data "template_file" "credential" {
    template = file("${path.module}/velero.credential.tpl")
    
    vars = {
        ARM_SUBSCRIPTION_ID = var.subscribtion_id
        ARM_TENANT_ID = var.tenant_id
        ARM_CLIENT_ID = var.velero_client_id
        ARM_CLIENT_SECRET = var.velero_client_secret
        AKS_RESOURCE_GROUP = azurerm_resource_group.kathra_backup.name
    }
}

resource "helm_release" "velero" {
  name       = "velero"
  repository = data.helm_repository.vmware-tanzu.metadata[0].name
  chart      = "vmware-tanzu/velero"
  version    = "2.7.4"
  namespace  = kubernetes_namespace.kathra_backup.metadata[0].name

  values  = ["${data.template_file.credential.rendered}"]

  set {
    name  = "configuration.provider"
    value = "azure"
  }
  set {
    name  = "configuration.backupStorageLocation.name"
    value = "azure"
  }
  set {
    name  = "configuration.backupStorageLocation.bucket"
    value = azurerm_storage_container.kathra_backup.name
  }
  set {
    name  = "configuration.backupStorageLocation.config.storageAccount"
    value = azurerm_storage_account.kathra_backup.name
  }
  set {
    name  = "configuration.backupStorageLocation.config.resourceGroup"
    value = azurerm_resource_group.kathra_backup.name
  }
  set {
    name  = "configuration.volumeSnapshotLocation.name"
    value = "azure"
  }
  set {
    name  = "configuration.volumeSnapshotLocation.bucket"
    value = azurerm_storage_container.kathra_backup.name
  }
  set {
    name  = "configuration.volumeSnapshotLocation.config.storageAccount"
    value = azurerm_storage_account.kathra_backup.name
  }
  set {
    name  = "configuration.volumeSnapshotLocation.config.resourceGroup"
    value = azurerm_resource_group.kathra_backup.name
  }
  set {
    name  = "image.repository"
    value = "velero/velero"
  }
  set {
    name  = "image.tag"
    value = "v1.2.0"
  }
  set {
    name  = "image.pullPolicy"
    value = "IfNotPresent"
  }
  set {
    name  = "initContainers[0].name"
    value = "velero-plugin-for-microsoft-azure"
  }
  set {
    name  = "initContainers[0].image"
    value = "velero/velero-plugin-for-microsoft-azure:v1.0.0"
  }
  set {
    name  = "initContainers[0].volumeMounts[0].mountPath"
    value = "/target"
  }
  set {
    name  = "initContainers[0].volumeMounts[0].name"
    value = "plugins"
  }

}