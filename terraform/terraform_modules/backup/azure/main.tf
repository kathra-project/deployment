variable "group" {}
variable location {}
variable "tenant_id" {}
variable "subscribtion_id" {}
variable "velero_client_id" {}
variable "velero_client_secret" {}
variable "namespace" {}
variable "kubernetes_azure_group_name" {
  default = "MC_kathra6_k8s-instance_francecentral"
}


data "helm_repository" "vmware-tanzu" {
    name = "vmware-tanzu"
    url  = "https://vmware-tanzu.github.io/helm-charts"
}


resource "kubernetes_namespace" "kathra_backup" {
    metadata {
        name = var.namespace
    }
}

resource "azurerm_storage_account" "kathra_backup" {
    name                     = "kathrabackupaccountname"
    resource_group_name      = var.group
    location                 = var.location
    account_tier             = "Standard"
    account_replication_type = "LRS"
}

resource "azurerm_storage_container" "kathra_backup" {
    name                  = "kathrabackupcontainer"
    storage_account_name  = azurerm_storage_account.kathra_backup.name
    container_access_type = "private"
}

resource "helm_release" "velero" {
  name       = "velero"
  repository = data.helm_repository.vmware-tanzu.metadata[0].name
  chart      = "vmware-tanzu/velero"
  version    = "2.12.0"
  namespace  = kubernetes_namespace.kathra_backup.metadata[0].name

  values     = [<<EOF
configuration:
  provider: azure
  backupStorageLocation:
    bucket: ${azurerm_storage_container.kathra_backup.name}
    config:
      resourceGroup: ${var.group}
      subscriptionId: ${var.subscribtion_id}
      storageAccount: ${azurerm_storage_account.kathra_backup.name}
  volumeSnapshotLocation:
    config:
      apiTimeout: "600s"
      resourceGroup: ${var.group}
      subscriptionId: ${var.subscribtion_id}
credentials:
    secretContents:
        cloud: |
            AZURE_SUBSCRIPTION_ID=${var.subscribtion_id}
            AZURE_TENANT_ID=${var.tenant_id}
            AZURE_CLIENT_ID=${var.velero_client_id}
            AZURE_CLIENT_SECRET=${var.velero_client_secret}
            AZURE_RESOURCE_GROUP=${var.kubernetes_azure_group_name}
            AZURE_CLOUD_NAME=AzurePublicCloud


initContainers:
  - name: velero-plugin-for-azure
    image: velero/velero-plugin-for-microsoft-azure:v1.1.0
    imagePullPolicy: IfNotPresent
    volumeMounts:
      - mountPath: /target
        name: plugins

EOF
]
/*
  set {
    name  = "configuration.provider"
    value = "azure"
  }
  set {
    name  = "configuration.backupStorageLocation.name"
    value = "azure-backup"
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
  /*
  set {
    name  = "configuration.volumeSnapshotLocation.name"
    value = "azure-snapshot"
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
    value = "v1.4.0"
  }
  set {
    name  = "initContainers[0].name"
    value = "velero-plugin-for-microsoft-azure"
  }
  set {
    name  = "initContainers[0].image"
    value = "velero/velero-plugin-for-microsoft-azure:v1.1.0"
  }
  set {
    name  = "initContainers[0].volumeMounts[0].mountPath"
    value = "/target"
  }
  set {
    name  = "initContainers[0].volumeMounts[0].name"
    value = "plugins"
  }
  */

}