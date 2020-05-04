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
variable "deploymanager_url" {
}

data "helm_repository" "stable" {
  name = "stable"
  url  = "https://codecentric.github.io/helm-charts"
}

module "registry_config" {
    source                  = "./registry_config"
    namespace               = var.namespace
    host                    = var.binaries.registry.host
    username                = var.binaries.registry.username
    password                = var.binaries.registry.password
}

module "maven_config" {
    source                  = "./maven_settings"
    namespace               = var.namespace
    url                     = var.binaries.maven.url
    username                = var.binaries.maven.username
    password                = var.binaries.maven.password
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
        server              = module.nfs-server.service_host
      }
    }
    persistent_volume_reclaim_policy = "Retain"
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


resource "helm_release" "jenkins" {
  name          = "jenkins"
  repository    = data.helm_repository.stable.metadata[0].name
  chart         = "jenkins"
  namespace     = var.namespace
  timeout       = 800
  values = [<<EOF

master:
  adminUser: ${var.password}
  securityRealm: |
    <securityRealm class="org.jenkinsci.plugins.oic.OicSecurityRealm" plugin="oic-auth@1.0">
        <clientId>${var.oidc.client_id}</clientId>
        <clientSecret>${var.oidc.client_secret}</clientSecret>
        <tokenServerUrl>${var.oidc.token_url}</tokenServerUrl>
        <authorizationServerUrl>${var.oidc.auth_url}</authorizationServerUrl>
        <userNameField>email</userNameField>
        <scopes>openid email</scopes>
        <automanualconfigure>none</automanualconfigure>
    </securityRealm>

  ingress:
    enabled: true
    tls:
    - hosts:
      - ${var.ingress_host}
      secretName: ${var.ingress_tls_secret_name == null ? "jenkins-cert" : var.ingress_tls_secret_name}
    path: /
    hostName: ${var.ingress_host}
    labels:
      ingress: tls
    annotations:
      kubernetes.io/ingress.class: ${var.ingress_class}
      cert-manager.io/issuer: "${var.ingress_cert_manager_issuer}"
  
  HostName: https://${var.ingress_host}/
  
  overwritePlugins: true
  installPlugins:
  - kubernetes:1.25.3
  - kubernetes-credentials:0.6.2
  - workflow-aggregator:2.6
  - workflow-job:2.33
  - credentials-binding:1.18
  - git:4.2.2
  - oic-auth:1.6
  - matrix-auth:2.4.2
  - pipeline-utility-steps:2.3.0
  - configuration-as-code:1.35
  - configuration-as-code-support:1.18

  JCasC:
    defaultConfig: true
    enabled: true
    PluginVersion: 1.35
    SupportPluginVersion: 1.18
    configScripts:
      welcome-message: |
        jenkins:
          agentProtocols:
          - "JNLP4-connect"
          - "Ping"
          authorizationStrategy:
            loggedInUsersCanDoAnything:
              allowAnonymousRead: false
          clouds:
          - kubernetes:
              containerCap: 10
              containerCapStr: "10"
              jenkinsTunnel: "jenkins-agent:50000"
              jenkinsUrl: "http://jenkins:8080"
              maxRequestsPerHost: 32
              maxRequestsPerHostStr: "32"
              name: "kubernetes"
              namespace: "${var.namespace}"
              podLabels:
              - key: "jenkins/jenkins-jenkins-slave"
                value: "true"
              serverUrl: "https://kubernetes.default"
              templates:
              - containers:
                - args: "^$${computer.jnlpmac} ^$${computer.name}"
                  envVars:
                  - containerEnvVar:
                      key: "JENKINS_URL"
                      value: "http://jenkins.${var.namespace}.svc.cluster.local:8080"
                  image: "jenkins/jnlp-slave:3.40-1"
                  name: "jnlp"
                  resourceLimitCpu: "512m"
                  resourceLimitMemory: "512Mi"
                  resourceRequestCpu: "512m"
                  resourceRequestMemory: "512Mi"
                  workingDir: "/home/jenkins"
                label: "jenkins-jenkins-slave "
                name: "default"
                nodeUsageMode: "NORMAL"
                podRetention: "never"
                serviceAccount: "default"
                yamlMergeStrategy: "override"
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
                  workingDir: "/home/jenkins"
                label: "docker"
                name: "docker"
                namespace: "${var.namespace}"
                serviceAccount: "docker"
                volumes:
                - secretVolume:
                    mountPath: "/home/jenkins/.docker"
                    secretName: "${module.registry_config.name}"
                - hostPathVolume:
                    hostPath: "/var/run/docker.sock"
                    mountPath: "/var/run/docker.sock"
                yamlMergeStrategy: "override"
              - containers:
                - args: "cat"
                  command: "/bin/sh -c"
                  image: "kathra/helm-builder:latest"
                  name: "helm"
                  resourceLimitCpu: "1250m"
                  resourceLimitMemory: "128Mi"
                  resourceRequestCpu: "1250m"
                  resourceRequestMemory: "128Mi"
                  ttyEnabled: true
                  workingDir: "/home/jenkins"
                inheritFrom: "docker"
                label: "helm"
                name: "helm"
                namespace: "${var.namespace}"
                serviceAccount: "helm"
                volumes:
                - secretVolume:
                    mountPath: "/etc/ssh"
                    secretName: "${module.maven_config.name}"
                yamlMergeStrategy: "override"
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
                  image: "registry.hub.docker.com/kathra/maven-builder:dev"
                  name: "maven"
                  resourceLimitCpu: "1"
                  resourceLimitMemory: "1024Mi"
                  resourceRequestCpu: "400m"
                  resourceRequestMemory: "512Mi"
                  ttyEnabled: true
                  workingDir: "/home/jenkins"
                inheritFrom: "docker"
                label: "maven"
                name: "maven"
                namespace: "${var.namespace}"
                serviceAccount: "maven"
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
                yamlMergeStrategy: "override"
              - containers:
                - args: "cat"
                  command: "/bin/sh -c"
                  image: "registry.hub.docker.com/kathra/pip-builder:1.0.1"
                  name: "pip"
                  resourceLimitCpu: "1"
                  resourceLimitMemory: "1024Mi"
                  resourceRequestCpu: "400m"
                  resourceRequestMemory: "512Mi"
                  ttyEnabled: true
                  workingDir: "/home/jenkins"
                inheritFrom: "docker"
                label: "pip"
                name: "pip"
                namespace: "${var.namespace}"
                serviceAccount: "pip"
                volumes:
                - secretVolume:
                    mountPath: "/etc/ssh"
                    secretName: "${module.gitlab_ssh_config.name}"
                yaml: |
                  apiVersion: v1
                  kind: Pod
                  spec:
                    containers:
                    - name: pip
                      image: registry.hub.docker.com/kathra/pip-builder:1.0.1
                      volumeMounts:
                      - mountPath: /home/jenkins/.pypirc
                        name: pypi-config
                        subPath: .pypirc
                    volumes:
                    - name: pypi-config
                      secret:
                        secretName: ${module.pypi_config.name}
                yamlMergeStrategy: "override"
                yamls:
                - |
                  apiVersion: v1
                  kind: Pod
                  spec:
                    containers:
                    - name: pip
                      image: registry.hub.docker.com/kathra/pip-builder:1.0.1
                      volumeMounts:
                      - mountPath: /home/jenkins/.pypirc
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

        security:
          scriptApproval:
            approvedSignatures:
            - "method groovy.lang.GroovyObject invokeMethod java.lang.String java.lang.Object"
            - "staticMethod org.codehaus.groovy.runtime.DefaultGroovyMethods invokeMethod\
              \ java.lang.Object java.lang.String java.lang.Object"
        unclassified:
          globalLibraries:
            libraries:
            - defaultVersion: "dev"
              implicit: true
              includeInChangesets: false
              name: "kathra-pipeline-library"
              retriever:
                modernSCM:
                  scm:
                    git:
                      id: "278451db-b355-48c8-82c1-7fa0c0d1f9cb"
                      remote: "https://gitlab.com/kathra/factory/jenkins/pipeline-library.git"


  sidecars:
    configAutoReload:
      enabled: true


persistence:
  enabled: true

rbac:
  create: true

EOF
]
}

output "namespace" {
  value = helm_release.jenkins.namespace
}
output "name" {
  value = helm_release.jenkins.name
}
output "username" {
  value = "admin"
}
output "password" {
  value = yamldecode(helm_release.jenkins.metadata[0].values).master.adminUser
}
output "host" {
  value = yamldecode(helm_release.jenkins.metadata[0].values).master.ingress.hostName
}
output "url" {
  value = "https://${yamldecode(helm_release.jenkins.metadata[0].values).master.ingress.hostName}"
}