# Installation instructions

## 1. Keycloak
Keycloak is the cornerstone of the Kathra factory.
It needs to be installed first to serve as the authentication and authorization platform for the other components.

## Installation
Option 1: Use an already existing 4.2.1 instance of Keycloak
- You will need to configure a Kathra realm with the clients available in `templates/keycloak-configuration-configmap` and the user federation of your choice.

Option 2: Use this chart to handle all the installation and configuration of a simple Keycloak instance
- First, udpate your parameters in the `extra-vars.yaml`, eventually adding keys to override what's available in the origival `values.yaml` (See [Configuration](#Configuration)).
- For a dry-run, you can use:  
`helm template keycloak/ --tiller-namespace <tiller_ns> --namespace <target_ns> -n <release_name> -f keycloak/extra-vars.yaml > dry-run-output.yaml`
- To install:  
`helm install keycloak/ --tiller-namespace <tiller_ns> --namespace <target_ns> -n <release_name> -f keycloak/extra-vars.yaml --wait`

## Configuration
Here is a list of the parameters overriden in the `extra-vars.yaml` file.  
For information about other available parameters, see https://github.com/helm/charts/blob/master/stable/keycloak/README.md#configuration.

 Parameter name | Description | Default value 
----------------|-------------|---------------
`keycloak.extraEnv` | Allows the specification of additional environment variables for Keycloak. Passed through the tpl function and thus to be configured a string | `""`
`keycloak.ingress.enabled` | If `true`, an ingress is created | `false`
`keycloak.ingress.annotations` | Annotations for the ingress | `{}`
`keycloak.ingress.hosts` | A list of ingress hosts | `[keycloak.example.com]`
`keycloak.persistence.deployPostgres` | If true, the PostgreSQL chart is installed | `false`
`keycloak.persistence.existingSecret` | Name of an existing secret to be used for the database password (if `keycloak.persistence.deployPostgres=false`). Otherwise a new secret is created | `"keycloak-postgres-kubedb-auth"`
`keycloak.persistence.existingSecretKey` | The key for the database password in the existing secret (if `keycloak.persistence.deployPostgres=false`) | `POSTGRES_PASSWORD`
`keycloak.persistence.dbVendor` | One of `h2`, `postgres`, `mysql`, or `mariadb` (if `deployPostgres=false`) | `postgres`
`keycloak.persistence.dbName` | The name of the database to connect to (if `deployPostgres=false`) | `keycloak`
`keycloak.persistence.dbHost` | The database host name (if `deployPostgres=false`) | `keycloak-postgres-kubedb`
`keycloak.persistence.dbUser` | The database user (if `deployPostgres=false`) | `postgres`
`configuration.realm` | The name of the realm to create | `kathra`
`configuration.ingress.labels` | A map of key-value pairs injected into the ingress labels | `ingress: tls`
`configuration.clientsDomain` | The domain name suffixing the services name for the Keycloak clients | `my.domain.com`
`configuration.ldapPasswordService` | The name of the secret used to store the LDAP service account password | `"ldap-service-password"`
`configuration.ldapPassword` | The LDAP service account password | `""`
`configuration.ldapServiceAccount` |  The LDAP service account name | `""`
`configuration.configurationShellScript` | The name of the script used for post-install configuration | `keycloak-configuration.sh`
`configuration.configurationConfigmap` | The name of the configmap storing the configuration script | `keycloak-configuration`

# 2. Gitlab CE
Because Gitlab will be interfaced in many ways by Jenkins and other services, it's best to install it before the other components.

## Installation
Option 1: Use an already existing 11.2.3+ instance of Gitlab CE
- You will need to configure an OIDC authentication method to use with Keycloak in your `gitlab.rb`.

Option 2: Use this chart to handle all the installation and configuration of a simple Gitlab CE instance
- First, udpate your parameters in the `values.yaml` (See [Configuration](#Configuration)).
- For a dry-run, you can use:  
`helm template gitlab-ce/ --tiller-namespace <tiller_ns> --namespace <target_ns> -n <release_name> > dry-run-output.yaml`
- To install:  
`helm install gitlab-ce/ --tiller-namespace <tiller_ns> --namespace <target_ns> -n <release_name> --wait`

## Configuration

 Parameter name | Description | Default value 
----------------|-------------|---------------
`fqdn` | The fully qualified domain name used by the Gilab CE instance | `gitlab.my-domain.com`
`externalUrl` | The URL that will be used by Gitlab | `https://gitlab.my-domain.com`
`oidc.providerUrl` | The URL of the OIDC provider | `https://keycloak.my-domain.com`
`oidc.clientName` | The OIDC client used to authenticate users on Gitlab | `gitlab`
`oidc.clientSecret` | The OIDC client secret | `<oidc_client_secret>`
`oidc.authorizeUrl` | The relative URL used for authorization | `/auth/realms/kathra/protocol/openid-connect/auth`
`oidc.userInfoUrl` | The relative URL used for user info | `/auth/realms/kathra/protocol/openid-connect/userinfo`
`oidc.tokenUrl` | The relative URL used for token management | `/auth/realms/kathra/protocol/openid-connect/token`
`oidc.redirectUrl` | The redirect URL used by the OIDC login process | `https://gitlab.my-domain.com/users/auth/KATHRA/callback` 
`oidc.omniauthEnabled` | Use OmniAuth to mutualize user accounts between multiple authentication methods | `true`
`oidc.omniauthStrategyClass` | The OmniAuth stategy to use for OIDC | `OmniAuth::Strategies::OAuth2Generic`
`oidc.omniauthAutoSignInWithProvider` | Default provider for authentication | `KATHRA`
`oidc.omniauthAllowSingleSignOn` | The provider used to automatically create an account | `KATHRA`
`oidc.omniauthBlockAutoCreatedUsers` | Block auto crated accounts and require an administrator action to unlock | `false`
`ldap.enabled` | Enable ldap authentication. Must be `true` if legacy users exist and created their accounts while the LDAP authentication was active. For a clean, OIDC authenticating, instance, set it to `false`  | `false`
`ldap.host` | LDAP host | `127.0.0.1`
`ldap.port` | LDAP port | `636`
`ldap.method` | LDAP method | `ssl`
`ldap.baseDn` | LDAP base DN | `DC=my-domain,DC=local`
`ldap.userUID` | LDAP user UID | `sAMAccountName`
`ldap.bindDn` | LDAP bind DN | `fake@my-domain.local`
`smtp.enabled` | Enable SMTP | `true`
`smtp.address` | SMTP server adress | `gitlab-noreply@my-domain.com`
`smtp.port` | SMTP server port | `587`
`smtp.username` | SMTP user | `gitlab-noreply@my-domain.com`
`smtp.password` | SMTP password | `<smtp_password>`
`smtp.domain` | SMTP domain | `my-domain.com`
`smtp.authentication` | SMTP authentication | `login`
`smtp.enableStartTlsAuto` | SMTP enable startTls | `true`
`smtp.opensslVerifyMode` | SMTP openssl verify mode | `peer`
`nginx.port` | Reverse proxy port | `80`
`nginx.listenHttps` | Reverse proxy listen HTTPS | `false`
`nginx.setHeaders` | Reverse proxy headers | `{ "X-Forwarded-Proto" => "https", "X-Forwarded-Ssl" => "on" }`
`storage.gitlabDataSize` | Storage size for Gitlab data | `100Gi`
`storage.gitlabConfigSize` | Storage size for Gitlab config | `1Gi`
`storage.gitlabLogsSize` | Storage size for Gitlab logs | `10Gi`
`storage.gitlabBackupSize` | Storage size for Gitlab backup | `200Gi`
`backup.cron` | Backup cron expression | `@daily`
`backup.keepTime` | Backup keep time in seconds | `259200`
`backup.kubectl.image` | kubectl image used for the backup job | `roffe/kubectl`
`backup.kubectl.tag` | kubectl image version used for the backup job | `v1.9.7`
`configuration.prometheusState` | Use prometheus | `false`
`configuration.serviceType` | Gitlab service type | `NodePort`
`configuration.ssh.containerPort` | Gitlab ssh port | `22`
`configuration.ssh.nodePort` | Nodeport used by Gitlab | `31848`

# 3. Harbor
Harbor is a containers repository laoded with image signature and vulnerabilities scan.  
The implementation and Helm chart being under heavy development, this custom chart uses a stabilized version (v1.6.0).

## Installation
Option 1: Use an already existing Harbor instance.

Option 2: Use this chart to handle all the installation and configuration of a simple Harbor instance
- First, udpate your parameters in the `values.yaml` (See [Configuration](#Configuration)).
- For a dry-run, you can use:  
`helm template harbor/ --tiller-namespace <tiller_ns> --namespace <target_ns> -n <release_name> > dry-run-output.yaml`
- To install:  
`helm install harbor/ --tiller-namespace <tiller_ns> --namespace <target_ns> -n <release_name> --wait`

## Configuration

| Parameter name | Description | Default value |
| -------------- | ----------- | ------------- |
| **Harbor** |
| `persistence.enabled`     | Persistent data | `true` |
| `persistence.resourcePolicy`     | Setting it to "keep" to avoid removing PVCs during a helm delete operation. Leaving it empty will delete PVCs after the chart deleted | `keep` |
| `externalURL`       | Ther external URL for Harbor core service | `https://core.harbor.domain` |
| `harborAdminPassword`  | The password of system admin | `Harbor12345` |
| `secretkey` | The key used for encryption. Must be a string of 16 chars | `not-a-secure-key` |
| `imagePullPolicy` | The image pull policy | `IfNotPresent` |
| `logLevel` | The log level used by Harbor | `debug` |
| **Post-install configuration** |
| `postInstallConfig.enabled` | Enable usage of a postinstall hook that configures Harbor (LDAP, repositories and membership) | `true` |
| **Authentication** |
| `auth.mode` | The type of authentication that is used | `db_auth` |
| `auth.self_registration` | Enable / Disable the ability for a user to register himself/herself. When disabled, new users can only be created by the Admin user. When auth.mode is set to ldap_auth, self-registration feature is always disabled, and this flag is ignored | `off` |
| `auth.ldap.url` | The LDAP endpoint URL | `ldaps://ldap.domain` |
| `auth.ldap.searchDn` | The DN of a user who has the permission to search an LDAP/AD server | `uid=admin,ou=people,dc=mydomain,dc=com` |
| `auth.ldap.searchPassword` | The password of the user specified by ldap.search_dn | `search_password` |
| `auth.ldap.baseDn` | The base DN to look up a user | `ou=people,dc=mydomain,dc=com` |
| `auth.ldap.filter` | The search filter for looking up a user | `objectClass=person` |
| `auth.ldap.userUid` | The attribute used to match a user during a LDAP search | `sAMAccountName` |
| `auth.ldap.searchScope` | The scope to search for a user, 0-LDAP_SCOPE_BASE, 1-LDAP_SCOPE_ONELEVEL, 2-LDAP_SCOPE_SUBTREE | `2` |
| `auth.ldap.timeout` | The timeout limit when requesting the LDAP | `5` |
| `auth.ldap.verifyCert` | Whether the LDAP certificate should be verified or not| `true` |
| `auth.ldap.groupGid` | The attribute used to match a group during a LDAP search | `cn` |
| `auth.ldap.groupBaseDn` | The base DN to look up a group | `""`
| `auth.ldap.groupSearchFilter` | The search filter for looking up a group | `objectclass=group` |
| `auth.ldap.groupSearchScope` | The scope to search for a group, 0-LDAP_SCOPE_BASE, 1-LDAP_SCOPE_ONELEVEL, 2-LDAP_SCOPE_SUBTREE | `2` |
| `auth.ldap.groupAdminDn` | The DN of the group who will be granted harbor administration privilege | `""` |
| **Email** |
| `email.enabled` | Enable SMTP | `true` |
| `email.host` | The hostname of email server | `smtp.mydomain.com` |
| `email.port` | The port of email server | `25` |
| `email.username` | The username of email server | `sample_admin@mydomain.com` |
| `email.password` | The password for email server | `unsecure_password` |
| `email.ssl` | Whether use TLS | `false` |
| `email.from` | The from address shown when sending emails | `admin <sample_admin@mydomain.com>` |
| `email.identity` | The identidy associated to the from adress used | `""` |
| `email.insecure` | Whether the connection with email server is insecure | `false` |
| **Ingress** |
| `ingress.enabled` | Enable ingress objects | `true` |
| `ingress.hosts.core` | The host of Harbor core service in ingress rule | `core.harbor.domain` |
| `ingress.hosts.notary` | The host of Harbor notary service in ingress rule | `notary.harbor.domain` |
| `ingress.annotations` | The annotations used in ingress | `true` |
| `ingress.labels` | The custom labels to use in ingress | `true` |
| `ingress.tls.enabled` | Enable TLS | `true` |
| `ingress.tls.secretName` | Fill the secretName if you want to use the certificate of yourself when Harbor serves with HTTPS. A certificate will be generated automatically by the chart if leave it empty |
| `ingress.tls.notarySecretName` | Fill the notarySecretName if you want to use the certificate of yourself when Notary serves with HTTPS. if left empty, it uses the `ingress.tls.secretName` value |
| **Service** |
| `name` | The service name | `harbor` |
| `type` | The service type | `ClusterIP` |
| `ports.http.port` | The container port used for HTTP | `80` |
| `ports.http.nodePort` | The nodePort used for HTTP (only used if serviceType is `NodePort`)| `30002` |
| `ports.https.port` | The container port used for HTTPS | `443` |
| `ports.https.nodePort` | The nodePort used for HTTPS (only used if serviceType is `NodePort`)| `30003` |
| `ports.notary.port` | The container port used by the Notary service | `4443` |
| `ports.notary.nodePort` | The nodePort used by the Notary service (only used if serviceType is `NodePort`)| `30004` |
| **Portal** |
| `portal.image.repository` | Repository for portal image | `pierredadt/harbor-portal` |
| `portal.image.tag` | Tag for portal image | `stable` |
| `portal.replicas` | The replica count | `1` |
| `portal.resources` | [resources](https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/) to allocate for container   | undefined |
| `portal.nodeSelector` | Node labels for pod assignment | `{}` |
| `portal.tolerations` | Tolerations for pod assignment | `[]` |
| `portal.affinity` | Node/Pod affinities | `{}` |
| **nginx (reverse proxy used in place of a TLS ingress)** |
| `image.repository` | Repository for nginx-photon image | `pierredadt/nginx-photon` |
| `image.tag` | Tag for nginx-photon image | `stable` |
| `replicas` | The replica count | `1` |
| `tls.enabled` | Whether to enable TLS for the nginx reverse proxy | `true` |
| `tls.usesSecret` | Whether the TLS nginx reverse proxy uses a secret | `false` |
| `tls.secretName` | The name of the secret used by the TLS nginx reverse proxy | `""` |
| `tls.commonName` | The CN used for the certificate construction | `""` |
| `nodeSelector` | Node labels for pod assignment | `{}` |
| `tolerations` | Tolerations for pod assignment | `[]` |
| `affinity` | Node/Pod affinities | `{}` |
| **Adminserver** |
| `adminserver.image.repository` | Repository for adminserver image | `pierredadt/harbor-adminserver` |
| `adminserver.image.tag` | Tag for adminserver image | `stable` |
| `adminserver.replicas` | The replica count | `1` |
| `adminserver.resources` | [resources](https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/) to allocate for container   | undefined |
| `adminserver.nodeSelector` | Node labels for pod assignment | `{}` |
| `adminserver.tolerations` | Tolerations for pod assignment | `[]` |
| `adminserver.affinity` | Node/Pod affinities | `{}` |
| **Jobservice** |
| `jobservice.image.repository` | Repository for jobservice image | `pierredadt/harbor-jobservice` |
| `jobservice.image.tag` | Tag for jobservice image | `stable` |
| `jobservice.replicas` | The replica count | `1` |
| `jobservice.maxWorkers` | The maximum amount of workers | `50` |
| `jobservice.volumes.data.existingClaim` | The already existing PVC to use. If not set a new PVC will be created | `""` |
| `jobservice.volumes.data.storageClass` | The storageClass to use for the PVC if not default | `""` |
| `jobservice.volumes.data.subPath` | The volume mount subPath | `jobservice` |
| `jobservice.volumes.data.accessMode` | The volume mount access mode | `ReadWriteOnce` |
| `jobservice.volumes.data.size` | The storage available to the volume | `1Gi` |
| `jobservice.resources` | [resources](https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/) to allocate for container   | undefined |
| `jobservice.nodeSelector` | Node labels for pod assignment | `{}` |
| `jobservice.tolerations` | Tolerations for pod assignment | `[]` |
| `jobservice.affinity` | Node/Pod affinities | `{}` |
| **Core** |
| `core.image.repository` | Repository for Harbor core image | `pierredadt/harbor-core` |
| `core.image.tag` | Tag for Harbor core image | `stable` |
| `core.replicas` | The replica count | `1` |
| `core.resources` | [resources](https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/) to allocate for container   | undefined |
| `core.nodeSelector` | Node labels for pod assignment | `{}` |
| `core.tolerations` | Tolerations for pod assignment | `[]` |
| `core.affinity` | Node/Pod affinities | `{}` |
| **Database** |
| `database.type` | If external database is used, set it to `external` | `internal` |
| `database.internal.image.repository` | Repository for database image | `pierredadt/harbor-db` |
| `database.internal.image.tag` | Tag for database image | `stable` |
| `database.internal.password` | The password for database | `changeit` |
| `database.internal.resources` | [resources](https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/) to allocate for container   | undefined |
| `database.internal.volumes.data.existingClaim` | The already existing PVC to use. If not set a new PVC will be created | `""` |
| `database.internal.volumes.data.storageClass` | The storageClass to use for the PVC if not default | `""` |
| `database.internal.volumes.data.subPath` | The volume mount subPath | `database` |
| `database.internal.volumes.data.accessMode` | The volume mount access mode | `ReadWriteOnce` |
| `database.internal.volumes.data.size` | The storage available to the volume | `1Gi` |
| `database.internal.nodeSelector` | Node labels for pod assignment | `{}` |
| `database.internal.tolerations` | Tolerations for pod assignment | `[]` |
| `database.internal.affinity` | Node/Pod affinities | `{}` |
| `database.external.host` | The hostname of external database | `192.168.0.1` |
| `database.external.port` | The port of external database | `5432` |
| `database.external.username` | The username of external database | `user` |
| `database.external.password` | The password of external database | `password` |
| `database.external.coreDatabase` | The database used by core service | `registry` |
| `database.external.clairDatabase` | The database used by clair | `clair` |
| `database.external.notaryServerDatabase` | The database used by Notary server | `notary_server` |
| `database.external.notarySignerDatabase` | The database used by Notary signer | `notary_signer` |
| `database.external.sslmode` | Connection method of external database (require|prefer|disable) | `disable`|
| **Registry** |
| `registry.registry.image.repository` | Repository for registry image | `pierredadt/registry-photon` |
| `registry.registry.image.tag` | Tag for registry image | `stable` |
| `registry.controller.image.repository` | Repository for registry controller image | `pierredadt/harbor-registryctl` |
| `registry.controller.image.tag` | Tag for registry controller image | `stable` |
| `registry.replicas` | The replica count | `1` |
| `registry.resources` | [resources](https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/) to allocate for container   | undefined |
| `registry.volumes.data.existingClaim` | The already existing PVC to use. If not set a new PVC will be created | `""` |
| `registry.volumes.data.storageClass` | The storageClass to use for the PVC if not default | `""` |
| `registry.volumes.data.subPath` | The volume mount subPath | `registry` |
| `registry.volumes.data.accessMode` | The volume mount access mode | `ReadWriteOnce` |
| `registry.volumes.data.size` | The storage available to the volume | `100Gi` |
| `registry.nodeSelector` | Node labels for pod assignment | `{}` |
| `registry.tolerations` | Tolerations for pod assignment | `[]` |
| `registry.affinity` | Node/Pod affinities | `{}` |
| **Chartmuseum** |
| `chartmuseum.enabled` | Enable chartmusuem to store chart | `true` |
| `chartmuseum.image.repository` | Repository for chartmuseum image | `pierredadt/chartmuseum-photon` |
| `chartmuseum.image.tag` | Tag for chartmuseum image | `stable` |
| `chartmuseum.replicas` | The replica count | `1` |
| `chartmuseum.resources` | [resources](https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/) to allocate for container   | undefined |
| `chartmuseum.volumes.data.existingClaim` | The already existing PVC to use. If not set a new PVC will be created | `""` |
| `chartmuseum.volumes.data.storageClass` | The storageClass to use for the PVC if not default | `""` |
| `chartmuseum.volumes.data.subPath` | The volume mount subPath | `chartmuseum` |
| `chartmuseum.volumes.data.accessMode` | The volume mount access mode | `ReadWriteOnce` |
| `chartmuseum.volumes.data.size` | The storage available to the volume | `100Gi` |
| `chartmuseum.nodeSelector` | Node labels for pod assignment | `{}` |
| `chartmuseum.tolerations` | Tolerations for pod assignment | `[]` |
| `chartmuseum.affinity` | Node/Pod affinities | `{}` |
| **Storage For Registry And Chartmuseum** |
| `storage.type` | The storage backend used for registry and chartmuseum: `filesystem`, `azure`, `gcs`, `s3`, `swift`, `oss` | `filesystem` |
| `other values` | The other values please refer to https://github.com/docker/distribution/blob/master/docs/configuration.md#storage |  |
| **Clair** |
| `clair.enabled` | Enable Clair? | `true` |
| `clair.image.repository` | Repository for clair image | `pierredadt/clair-photon` |
| `clair.image.tag` | Tag for clair image | `stable`
| `clair.replicas` | The replica count | `1` |
| `clair.updatersInterval` | The interval of clair updaters in hours. `0` disables the updaters | `12` |
| `clair.resources` | [resources](https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/) to allocate for container   | undefined
| `clair.nodeSelector` | Node labels for pod assignment | `{}` |
| `clair.tolerations` | Tolerations for pod assignment | `[]` |
| `clair.affinity` | Node/Pod affinities | `{}` |
| **Redis** |
| `redis.type` | If external redis is used, set it to `external` | `internal` |
| `redis.internal.image.repository` | Repository for redis image | `pierredadt/redis-photon` |
| `redis.internal.image.tag` | Tag for redis image | `stable` |
| `redis.internal.resources` | [resources](https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/) to allocate for container   | undefined |
| `redis.internal.volumes.data.existingClaim` | The already existing PVC to use. If not set a new PVC will be created | `""` |
| `redis.internal.volumes.data.storageClass` | The storageClass to use for the PVC if not default | `""` |
| `redis.internal.volumes.data.subPath` | The volume mount subPath | `redis` |
| `redis.internal.volumes.data.accessMode` | The volume mount access mode | `ReadWriteOnce` |
| `redis.internal.volumes.data.size` | The storage available to the volume | `100Gi` |
| `redis.internal.nodeSelector` | Node labels for pod assignment | `{}` |
| `redis.internal.tolerations` | Tolerations for pod assignment | `[]` |
| `redis.internal.affinity` | Node/Pod affinities | `{}` |
| `redis.external.host` | The hostname of external Redis | `192.168.0.2` |
| `redis.external.port` | The port of external Redis | `6379` |
| `redis.external.coreDatabaseIndex` | The database index for core | `0` |
| `redis.external.jobserviceDatabaseIndex` | The database index for jobservice | `1` |
| `redis.external.registryDatabaseIndex` | The database index for registry | `2` |
| `redis.external.chartmuseumDatabaseIndex` | The database index for chartmuseum | `3` |
| `redis.external.password` | The password of external Redis | `""` |
| **Notary** |
| `notary.enabled` | Enable Notary? | `true` |
| `notary.server.image.repository` | Repository for notary server image | `pierredadt/notary-server-photon` |
| `notary.server.image.tag` | Tag for notary server image | `stable`
| `notary.server.replicas` | The replica count | `1` |
| `notary.signer.image.repository` | Repository for notary signer image | `pierredadt/notary-signer-photon` |
| `notary.signer.image.tag` | Tag for notary signer image | `stable`
| `notary.signer.replicas` | The replica count | `1` |
| `notary.nodeSelector` | Node labels for pod assignment | `{}` |
| `notary.tolerations` | Tolerations for pod assignment | `[]` |
| `notary.affinity` | Node/Pod affinities | `{}` |

# 4. Nexus
## Installation
Nexus is the artifacts repository chosen in Kathra to store Java libraries and pip and npm packages.

Option 1: Use an already existing instance of Nexus

Option 2: Install a fresh Nexus instance from the [official Helm chart](https://github.com/helm/charts/tree/master/stable/sonatype-nexus)
- You may need to configure the admin account and eventually a LDAP integration

# 5. DeployManager
The DeployManager is a simple backend pluged on a message broker used to delegate CI deployments. It gives the possibility to route deployments to other clusters having an instance of the DeployManager.

A master instance of the DeployManager will be called by the factory and can handle deployments locally or delegate them to slaves, while a slave instance will listen for messages containing resources to  deploy to its cluster.

Disclaimer: in order to handle the creation of any k8s resources, the  DeployManager has full rights on the cluster, as Tiller would.

## Installation
Use this chart to handle all the installation and configuration of a DeployManager instance
- First, udpate your parameters in the `values.yaml` (See [Configuration](#Configuration)).
- For a dry-run, you can use:  
`helm template kathra-deploymanager/ --tiller-namespace <tiller_ns> --namespace <target_ns> -n <release_name> > dry-run-output.yaml`
- To install:  
`helm install kathra-deploymanager/ --tiller-namespace <tiller_ns> --namespace <target_ns> -n <release_name> --wait`

## Configuration

Parameter name | Description | Default value
-------------- | ----------- | -------------
`image` | The image name | `registry.hub.docker.com/kathra/kathra-services/kathra-deploymanager/java/kathra-deploymanager-k8s`
`tag` | The image tag | `1.0.0-RC-SNAPSHOT-b3b530f-46`
`mode` | The starting mode of the DeployManager (`master` or `slave`) | `master`
`targetCluster` | The default target cluster to use for deployments. The name is defined by the respective `.kube/config` cluster values | `dev`
`dockerSecret` | The `dockerconfigjson` secret used by deployments to pull their images from Harbor | `<dockerconfigjson_secret>`
`resources` | [resources](https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/) to allocate for container | `{}`
`rabbitmq.image` | Image of the rabbitMQ broker | `rabbitmq`
`rabbitmq.version` | Tag  of the rabbitMQ broker image | `3.7.4-management-alpine`
`rabbitmq.url` | The URL of the rabbitMQ service | `rabbitmq`
`rabbitmq.serviceType` | The rabbitMQ service type | `ClsuterIP`
`rabbitmq.username` | The rabbitMQ username | `<rabbitmq_username>`
`rabbitmq.password` | The rabbitMQ password | `<rabbitmq_password>`
`rabbitmq.nodePort` | The rabbitMQ nodePort used by a NodePort service | `31965`
`rabbitmq.resources` | [resources](https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/) to allocate for the rabbitMQ container  | `{}`

# 6. Jenkins
Jenkins is the CI tool used on Kathra.

## Installation
Option 1: Use an already existing Jenkins instance.

Option 2: Use this chart to handle all the installation and configuration of a simple Jenkins instance
- First, udpate your parameters in the `extra-vars.yaml` (See [Configuration](#Configuration)).
- For a dry-run, you can use:  
`helm template jenkins/ --tiller-namespace <tiller_ns> --namespace <target_ns> -n <release_name> -f jenkins/extra-vars.yaml > dry-run-output.yaml`
- To install:  
`helm install jenkins/ --tiller-namespace <tiller_ns> --namespace <target_ns> -n <release_name> -f jenkins/extra-vars.yaml --wait`

## Configuration

| Parameter name | Description | Default value |
| -------------- | ----------- | ------------- |

