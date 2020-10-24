variable "ingress_host" {
}
variable "ingress_class" {
}
variable "ingress_cert_manager_issuer" {
}
variable "ingress_tls_secret_name" {
    default = "jenkins-cert"
}
variable "namespace" { 
}
variable "password" {
}
variable "oidc" {
    default = null
}
variable "binaries" {
}
variable "git_ssh" {
    default = null
}

variable "image_builder_version" {
  default = "latest"
}
variable "storage_class" {
  default = "default"
}


variable "deploymanager_url" {
}
variable "sonar" {
  default = {
    url       = null
    username  =  null
    password  =  null
  }
}
variable "resources" {
  default = {
    cpu     = "3"
    memory  = "4Gi"
  }
}



data "helm_repository" "codecentric" {
    name = "codecentric"
    url  = "https://codecentric.github.io/helm-charts"
}

module "registry_config" {
    source                  = "./registry_config"
    namespace               = var.namespace
    host                    = var.binaries.registry.host
    username                = var.binaries.registry.username
    password                = var.binaries.registry.password
}

module "sonar_scanner_config" {
    source                  = "./sonar_scanner_config"
    namespace               = var.namespace
    host                    = var.sonar.url
    username                = var.sonar.username
    password                = var.sonar.password
}


module "maven_config" {
    source                  = "./maven_settings"
    namespace               = var.namespace
    repository_url          = var.binaries.maven.url
    repository_username     = var.binaries.maven.username
    repository_password     = var.binaries.maven.password
    sonar_url               = var.sonar.url
    sonar_username          = var.sonar.username
    sonar_password          = var.sonar.password
}

module "pypi_config" {
    source                  = "./pypi_config"
    namespace               = var.namespace
    url                     = var.binaries.pypi.url
    username                = var.binaries.pypi.username
    password                = var.binaries.pypi.password
}

module "gitlab_ssh_config" {
    source                  = "./sshconfig"
    namespace               = var.namespace
    ssh_host                = var.git_ssh.host
    ssh_service             = var.git_ssh.service
    ssh_user                = "git"
    ssh_service_port        = "22"
}

module "nfs-server" {
    source                  = "./nfs-cache"
    namespace               = var.namespace
    name                    = "jenkins-nfs-server"
    storage_class           = var.storage_class
}

resource "kubernetes_storage_class" "nfs" {
    metadata {
        name = "nfs"
    }
    storage_provisioner = "nfs"
    reclaim_policy      = "Retain"
}

resource "kubernetes_persistent_volume" "jenkins_mvn_cache_pv" {
    metadata {
        name                    = "jenkins-mvn-local-repo-pv"
    }
    spec {
        capacity = {
            storage               = "5Gi"
        }
        access_modes            = ["ReadWriteMany"]
        storage_class_name      = kubernetes_storage_class.nfs.metadata[0].name
        persistent_volume_source {
            nfs {
                path                = "/"
                server              = module.nfs-server.service_cluster_ip
            }
        }
        persistent_volume_reclaim_policy = "Retain"
    }

    lifecycle {
      prevent_destroy = true
      ignore_changes  = [ spec[0].persistent_volume_source[0].nfs[0].server ]
    }
}

resource "kubernetes_persistent_volume_claim" "jenkins_mvn_cache_pvc" {
    metadata {
        name                    = "jenkins-mvn-local-repo-pvc"
        namespace               = var.namespace
    }
    spec {
        access_modes            = ["ReadWriteMany"]
        storage_class_name      = kubernetes_storage_class.nfs.metadata[0].name
        resources {
            requests = {
                storage = "5Gi"
            }
        }
        volume_name = kubernetes_persistent_volume.jenkins_mvn_cache_pv.metadata.0.name
    }
}

data "external" "get_host_ip" {
    program = ["bash", "-c", "${path.module}/resolv_host.sh"]
    query = {
       host  = regex("^(?:(?P<scheme>[^:/?#]+):)?(?://(?P<host>[^/?#]*))?", var.binaries.pypi.url).host
    }
}

resource "helm_release" "jenkins" {
    name          = "jenkins"
    repository    = data.helm_repository.codecentric.metadata[0].name
    chart         = "codecentric/jenkins"
    version       = "1.6.1"
    namespace     = var.namespace
    timeout       = 800
    values = [<<EOF

ingress:
  enabled: true
  hosts:
  - ${var.ingress_host}
  tls:
  - hosts:
    - ${var.ingress_host}
    secretName: ${var.ingress_tls_secret_name == null ? "jenkins-cert" : var.ingress_tls_secret_name}
  paths: 
  - /
  hostName: ${var.ingress_host}
  labels:
    ingress: tls
  annotations:
    kubernetes.io/ingress.class: ${var.ingress_class}
    cert-manager.io/cluster-issuer: "${var.ingress_cert_manager_issuer}"
    
resources:
  requests:
    cpu: 1
    memory: 1Gi
  limits:
    cpu: 2
    memory: 2Gi

casc:
  secrets:
    ADMIN_USER: admin
    ADMIN_PASSWORD: ${var.password}

referenceContent:
  - relativeDir: init.groovy.d
    data:
      - fileName: init.groovy
        fileContent: |
          import jenkins.model.*
          import hudson.util.*;
          import jenkins.install.*;

          def instance = Jenkins.getInstance()

          instance.setInstallState(InstallState.INITIAL_SETUP_COMPLETED)
  - data:
    - fileName: plugins.txt
      fileContent: |
        credentials
        kubernetes
        kubernetes-credentials
        workflow-aggregator
        workflow-job
        credentials-binding
        git
        oic-auth
        matrix-auth
        pipeline-utility-steps
        configuration-as-code

    - fileName: jenkins.yaml
      fileContent: |
        jenkins:
          agentProtocols:
          - "JNLP4-connect"
          - "Ping"
          securityRealm:
            oic:
              clientId: "${var.oidc.client_id}"
              clientSecret: "${var.oidc.client_secret}"
              wellKnownOpenIDConfigurationUrl: "${var.oidc.well_known_url}"
              userInfoServerUrl: ""
              tokenFieldToCheckKey: ""
              tokenFieldToCheckValue: ""
              fullNameFieldName: ""
              groupsFieldName: "groups"
              disableSslVerification: false
              logoutFromOpenidProvider: ""
              postLogoutRedirectUrl: ""
              escapeHatchEnabled: false
              escapeHatchUsername: ""
              escapeHatchSecret: ""
              escapeHatchGroup: ""
              automanualconfigure: ""
              emailFieldName: "email"
              userNameField: "preferred_username"
              tokenServerUrl: "${var.oidc.token_url}"
              authorizationServerUrl: "${var.oidc.auth_url}"
              scopes: "openid profile email"
          authorizationStrategy:
            projectMatrix:
              permissions:
              - "Overall/Read:authenticated"
              - "Overall/Read:${var.oidc.group_admin}"
              - "Overall/Administer:${var.oidc.group_admin}"
              - "Overall/Read:/${var.oidc.group_admin}"
              - "Overall/Administer:/${var.oidc.group_admin}"
              - "Overall/Read:${var.oidc.user_admin}"
              - "Overall/Administer:${var.oidc.user_admin}"
          clouds:
          - kubernetes:
              jenkinsTunnel: "jenkins-agent:50000"
              jenkinsUrl: "http://jenkins-master:8080"
              name: "kubernetes"
              namespace: "${var.namespace}"
              serverUrl: "https://kubernetes.default"
              templates:
              - containers:
                - args: "^$${computer.jnlpmac} ^$${computer.name}"
                  envVars:
                  - containerEnvVar:
                      key: "JENKINS_URL"
                      value: "http://jenkins-master.${var.namespace}.svc.cluster.local:8080"
                  image: "jenkins/jnlp-slave:3.40-1"
                  name: "jnlp"
                  resourceLimitCpu: "512m"
                  resourceLimitMemory: "512Mi"
                  resourceRequestCpu: "512m"
                  resourceRequestMemory: "512Mi"
                  workingDir: ""
                label: "jenkins-jenkins-slave "
                name: "default"
                nodeUsageMode: "NORMAL"
                podRetention: "never"
                serviceAccount: "jenkins-master"
              - containers:
                - args: "cat"
                  command: "/bin/sh -c"
                  envVars:
                  - envVar:
                      key: "DOCKER_CONFIG"
                      value: "/home/jenkins/.docker/"
                  - envVar:
                      key: "KUBERNETES_MASTER"
                      value: "kubernetes.default"
                  image: "docker:latest"
                  name: "docker"
                  resourceLimitCpu: "200m"
                  resourceLimitMemory: "256Mi"
                  resourceRequestCpu: "200m"
                  resourceRequestMemory: "256Mi"
                  ttyEnabled: true
                  workingDir: ""
                label: "docker"
                name: "docker"
                namespace: "${var.namespace}"
                serviceAccount: "jenkins-master"
                volumes:
                - secretVolume:
                    mountPath: "/home/jenkins/.docker"
                    secretName: "${module.registry_config.name}"
                - hostPathVolume:
                    hostPath: "/var/run/docker.sock"
                    mountPath: "/var/run/docker.sock"
              - containers:
                - args: "cat"
                  command: "/bin/sh -c"
                  image: "kathra/helm-builder:${var.image_builder_version}"
                  name: "helm"
                  resourceLimitCpu: "1250m"
                  resourceLimitMemory: "128Mi"
                  resourceRequestCpu: "1250m"
                  resourceRequestMemory: "128Mi"
                  ttyEnabled: true
                  workingDir: ""
                inheritFrom: "docker"
                label: "helm"
                name: "helm"
                namespace: "${var.namespace}"
                serviceAccount: "jenkins-master"
                volumes:
                - secretVolume:
                    mountPath: "/etc/ssh"
                    secretName: "${module.gitlab_ssh_config.name}"
              - containers:
                - args: "cat"
                  command: "/bin/sh -c"
                  envVars:
                  - envVar:
                      key: "DOCKER_CONFIG"
                      value: "/home/jenkins/.docker/"
                  - envVar:
                      key: "MAVEN_OPTS"
                      value: "-Duser.home=/home/jenkins/"
                  - envVar:
                      key: "KUBERNETES_MASTER"
                      value: "kubernetes.default"
                  image: "registry.hub.docker.com/kathra/maven-builder:${var.image_builder_version}"
                  name: "maven"
                  resourceLimitCpu: "1"
                  resourceLimitMemory: "1024Mi"
                  resourceRequestCpu: "400m"
                  resourceRequestMemory: "512Mi"
                  ttyEnabled: true
                  workingDir: ""
                inheritFrom: "docker"
                label: "maven"
                name: "maven"
                namespace: "${var.namespace}"
                serviceAccount: "jenkins-master"
                volumes:
                - persistentVolumeClaim:
                    claimName: "${kubernetes_persistent_volume_claim.jenkins_mvn_cache_pvc.metadata[0].name}"
                    mountPath: "/home/jenkins/.mvnrepository"
                    readOnly: false
                - secretVolume:
                    mountPath: "/home/jenkins/.m2/"
                    secretName: "${module.maven_config.name}"
                - secretVolume:
                    mountPath: "/etc/ssh"
                    secretName: "${module.gitlab_ssh_config.name}"
                - hostPathVolume:
                    hostPath: "/var/run/docker.sock"
                    mountPath: "/var/run/docker.sock"
              - containers:
                - args: "cat"
                  command: "/bin/sh -c"
                  image: "registry.hub.docker.com/kathra/pip-builder:${var.image_builder_version}"
                  name: "pip"
                  resourceLimitCpu: "1"
                  resourceLimitMemory: "1024Mi"
                  resourceRequestCpu: "400m"
                  resourceRequestMemory: "512Mi"
                  ttyEnabled: true
                  workingDir: ""
                - args: "cat"
                  command: "/bin/sh -c"
                  image: "registry.hub.docker.com/sonarsource/sonar-scanner-cli:latest"
                  name: "sonar-scanner"
                  resourceLimitCpu: "250m"
                  resourceLimitMemory: "512Mi"
                  resourceRequestCpu: "100m"
                  resourceRequestMemory: "64Mi"
                  ttyEnabled: true
                  workingDir: ""
                  envVars:
                  - envVar:
                      key: "SONAR_PROJECT_BASE_DIR"
                      value: "/home/jenkins/"
                  - envVar:
                      key: "SONAR_CONFIG_PATH"
                      value: "/home/jenkins/sonar/sonar-project.properties"
                inheritFrom: "docker"
                label: "pip"
                name: "pip"
                namespace: "${var.namespace}"
                serviceAccount: "jenkins-master"
                volumes:
                - secretVolume:
                    mountPath: "/etc/ssh"
                    secretName: "${module.gitlab_ssh_config.name}"
                - secretVolume:
                    mountPath: "/home/jenkins/sonar"
                    secretName: "${module.sonar_scanner_config.name}"
                yaml: |
                  apiVersion: v1
                  kind: Pod
                  spec:
                    containers:
                    - name: pip
                      image: registry.hub.docker.com/kathra/pip-builder:${var.image_builder_version}
                      volumeMounts:
                      - mountPath: /home/jenkins/.pypirc
                        name: pypi-config
                        subPath: .pypirc
                      - mountPath: /root/.pypirc
                        name: pypi-config
                        subPath: .pypirc
                    volumes:
                    - name: pypi-config
                      secret:
                        secretName: ${module.pypi_config.name}
          globalNodeProperties:
          - envVars:
              env:
              - key: "DEPLOYMANAGER_URL"
                value: "${var.deploymanager_url}"
              - key: "DOCKER_BUILD_EXTRA_ARGS"
                value: "--add-host=${data.external.get_host_ip.result.host}:${data.external.get_host_ip.result.ip}"

        security:
          scriptApproval:
            approvedSignatures:
            - "method groovy.lang.GroovyObject invokeMethod java.lang.String java.lang.Object"
            - "staticMethod org.codehaus.groovy.runtime.DefaultGroovyMethods invokeMethod\
              \ java.lang.Object java.lang.String java.lang.Object"
        unclassified:
          globalLibraries:
            libraries:
            - defaultVersion: "master"
              implicit: true
              includeInChangesets: false
              name: "kathra-pipeline-library"
              retriever:
                modernSCM:
                  scm:
                    git:
                      id: "278451db-b355-48c8-82c1-7fa0c0d1f9cb"
                      remote: "https://gitlab.com/kathra/factory/jenkins/pipeline-library.git"

persistence:
  enabled: true


serviceAccount:
  master:
    create: true
    name: jenkins-master

rbac:
  master:
    create: true
    rules:
    - apiGroups: [""]
      resources: ["pods"]
      verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
    - apiGroups: [""]
      resources: ["pods/exec"]
      verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
    - apiGroups: [""]
      resources: ["pods/log"]
      verbs: ["get", "list", "watch"]
    - apiGroups: [""]
      resources: ["secrets"]
      verbs: ["get", "list", "watch"]



EOF
]
}

output "namespace" {
    value = helm_release.jenkins.namespace
}
output "name" {
    value = helm_release.jenkins.name
}

output "admin" {
  value = {
    username = "admin"
    password = yamldecode(helm_release.jenkins.metadata[0].values).casc.secrets.ADMIN_PASSWORD
  }
}

output "host" {
    value = yamldecode(helm_release.jenkins.metadata[0].values).ingress.hostName
}
output "url" {
    value = "https://${yamldecode(helm_release.jenkins.metadata[0].values).ingress.hostName}"
}