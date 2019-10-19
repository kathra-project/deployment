# How to install KATHRA
## Requirements
 - Kubernetes : between v1.9.11 and v1.15.1
 - Kubernetes client with full access
 - Kubernetes features :
    - Traefik Ingress Controller (v1.7.9 or later) with SSL
    - KubeDB v0.8.0
 - Domains names pointing to your public k8s :
    - dashboard.your-domain.xyz
    - appmanager.your-domain.xyz
    - plateform.your-domain.xyz
    - keycloak.your-domain.xyz
    - gitlab.your-domain.xyz
    - jenkins.your-domain.xyz
    - harbor.your-domain.xyz
    - nexus.your-domain.xyz

## Quickstart

To install KATHRA from scratch, execute :

> install.sh --interactive --verbose

The procedure asks arguments bellow :
 - K8S namespace for factory (Gitlab, Jenkins, Nexus, Harbor)
 - K8S namespace for KATHRA's services
 - Domain name exposing factory and KATHRA's services
 - LDAP configuration
 - Username, password and ssh public key for KATHRA's user
 - JQ is required : if it is not installed, sudo password will be asked to install with APT


Your output console should display this :

```
KATHRA INSTALLER (VERSION : stable)
 Factory's namespace [default:factory-kathra] ?
 Kathra's namespace [default:kathra] ?
 Domain name [default:kathra-opensourcing.irtsystemx.org] ?
 your-domain.xyz
 Username to first user [default:user] ?
 Password [default:123] ?
 SSH PublicKey file [default:/home/jboubechtoula/.ssh/id_rsa.pub] ?
 Do you want configure LDAP authentication ? [Y/N] ?
 N

[                                                                                ]   0 % Download Helm v2.13.1-linux-amd64 ... OK
[####                                                                            ]   5 % Check Helm Tiller...
 Tiller namespace [default:tiller] ?
 Tiller existing into namespace tiller
 OK
[########                                                                        ]  10 % Check KubeDB... OK
[############                                                                    ]  15 % Check Treafik... OK
[################                                                                ]  20 % Clone Charts from version 'stable'... OK
[###################                                                             ]  24 % Generating password... Use existing passwords from file '/home/jboubechtoula/.kathra_pwd' or generated....
 OK
[####################                                                            ]  25 % Install Keycloak... OK
[####################                                                            ]  30 % Install Harbor... OK
[########################                                                        ]  35 % Install NFS-Server... OK
 Install Jenkins... Pending
 Install GitLab-CE... Pending
 Install Nexus... Pending
 Install DeployManager... Pending
 Install DeployManager... OK
 Install Jenkins... OK
 Install Nexus... OK
 Install GitLab-CE... OK
[########################################################################        ]  90 % Install KATHRA services... OK
[################################################################################] 100 % Done... Kathra is installed in 515 secondes
```

Installed, you can check if all services are available.
```
> kubectl -n factory-kathra get pods
NAME                                                            READY     STATUS        RESTARTS   AGE
factory-kathra-harbor-harbor-adminserver-5bcfdfc765-hkb6k     1/1       Running       1          13m
factory-kathra-harbor-harbor-clair-74598bd478-qkx9b           1/1       Running       2          13m
factory-kathra-harbor-harbor-core-998fc7bb4-qbjkp             1/1       Running       3          13m
factory-kathra-harbor-harbor-database-0                       1/1       Running       0          12m
factory-kathra-harbor-harbor-jobservice-754c45697d-lt8th      1/1       Running       2          13m
factory-kathra-harbor-harbor-notary-server-d8cf9b979-wxrl7    1/1       Running       0          13m
factory-kathra-harbor-harbor-notary-signer-54678d564d-45gqm   1/1       Running       0          13m
factory-kathra-harbor-harbor-portal-85767589cb-8twkq          1/1       Running       0          13m
factory-kathra-harbor-harbor-redis-0                          1/1       Running       0          13m
factory-kathra-harbor-harbor-registry-69958f665c-pl6fm        2/2       Running       0          13m
factory-kathra-jenkins-869fb9b7c6-xzv2b                       1/1       Running       0          13m
factory-kathra-key-0                                          1/1       Running       0          14m
factory-kathra-nexus-sonatype-nexus-bf77f7b8b-hpnmn           2/2       Running       0          13m
gitlab-7fcc7cdf86-cxvs4                                         1/1       Running       0          13m
keycloak-configuration-sr864                                    0/1       Completed     0          15m
keycloak-postgres-kubedb-0                                      1/1       Running       0          16m
maven-33hgv                                                     0/3       Terminating   0          15d
nfs-server-775bd89bdd-wpj8r                                     1/1       Running       0          13m
rabbitmq-deploymanager-6fbd9f86d-h424c                          1/1       Running       0          13m
kathra-deploymanager-k8s-77f989bb5c-696jq                        1/1       Running       0          13m

> kubectl -n kathra services
NAME                                            READY     STATUS      RESTARTS   AGE
appmanager-swagger-679b646789-9r6s2             1/1       Running     0          8m
binaryrepositorymanager-harbor-5f6fff8d-kzxnj   1/1       Running     0          8m
catalog-icons-nginx-5cb765c7f4-rzgxs            1/1       Running     0          8m
dashboard-angular-5ffc4549b7-kvmtc              1/1       Running     0          8m
pipelinemanager-jenkins-55cdbf8d9c-4qbrl        1/1       Running     0          8m
resource-arangodb-69656fd7fd-dhxtw              1/1       Running     0          8m
resourcemanager-arangodb-775bbbb856-bvsjz       1/1       Running     0          8m
kathra-catalog-updater-qngst                     0/1       Completed   0          8m
kathra-catalogmanager-kube-77fff58f75-srvms      1/1       Running     0          8m
kathra-codegen-swagger-d7c4c5f65-x7kht           1/1       Running     0          8m
kathra-platformmanager-java-8564ffcdd-26x8f      1/1       Running     0          8m
kathra-synchro-1564671300-mtzg2                  0/1       Completed   0          3m
kathra-synchro-1564671360-q6pm2                  0/1       Completed   0          2m
kathra-synchro-1564671420-gnldt                  0/1       Completed   0          1m
kathra-synchro-1564671480-gz64x                  1/1       Running     0          12s
sourcemanager-gitlab-685f59c5b4-rcfgg           1/1       Running     0          8m
usermanager-keycloak-6b5749df67-wnxfc           1/1       Running     0          8m

> kubectl -n factory-kathra get ingress
NAME                                     HOSTS                                                                                      ADDRESS   PORTS     AGE
kathra-factory-harbor-harbor-ingress   harbor.your-domain.xyz,harbor-notary.your-domain.xyz             80        14m
kathra-factory-jenkins                 jenkins.your-domain.xyz                                                            80        14m
kathra-factory-key                     keycloak.your-domain.xyz                                                           80        18m
kathra-factory-nexus-sonatype-nexus    nexus.your-domain.xyz,nexus.your-domain.xyz                      80        14m
gitlab                                   gitlab.your-domain.xyz                                                             80        14m

> kubectl -n kathra get ingress
NAME                   HOSTS                                               ADDRESS   PORTS     AGE
appmanager             appmanager.your-domain.xyz                  80        8m
codegen                codegen.your-domain.xyz                     80        8m
dashboard              dashboard.your-domain.xyz                   80        8m
icons                  icons.your-domain.xyz                       80        8m
pipelinemanager        pipelinemanager.your-domain.xyz             80        8m
platformmanager       platformmanager.your-domain.xyz             80        8m
resourcemanager        resourcemanager.your-domain.xyz             80        8m
kathra-catalogmanager   catalogmanager.your-domain.xyz              80        8m
sourcemanager          sourcemanager.your-domain.xyz               80        8m
usermanager            usermanager.your-domain.xyz                 80        8m
```

For the first use, you have to connect into gitlab with your user : https://gitlab.your-domain.xyz . 

Once the GitLab have been aware your existence, you can connect to https://dashboard.your-domain.xyz

Each user created into Keycloak have to connect GitLab before any operation with KATHRA.



You can retreive generated passwords : 
```
cat ~/.kathra_pwd 
{
  "KEYCLOAK_ADMIN_PASSWORD": "PYmYiRiNH209EgXiKauK",
  "JENKINS_PASSWORD": "wFftO1FUrKKdHzN7dK4P",
  "SYNCMANAGER_PASSWORD": "oDLp8Cj2P8AzOJ9bagGo",
  "ARANGODB_PASSWORD": "jSd65QX6DqcKSlLUVJyN",
  "HARBOR_ADMIN_PASSWORD": "6yNQ9HvL5IrTJXvhadQc",
  "HARBOR_USER_PASSWORD": "NeVA7IiFhIKcd559rlwV",
  "JENKINS_API_TOKEN": "11ffda2d769a7c407f3fcda2e6be7a12f1",
  "GITLAB_API_TOKEN": "pspxnsFs9zG1Ttg3G7qc",
  "NEXUS_ADMIN_PASSWORD": "2GeRbAZVX1jtBM2RMENl",
  "USER_LOGIN": "user",
  "USER_PASSWORD": "123",
  "GITLAB_API_TOKEN_USER": "QwJ9j6v1f7noQKSoxXqL"
}
```

### Client setup
#### GitLab - SSH Agent
To pull source repositories, you have to configure your SSH client to connect throught gitlab's NodePort.
```
kubectl -n kathra-factory get svc gitlab
NAME      TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)                     AGE
gitlab    NodePort   10.233.23.197   <none>        80:32739/TCP,22:30000/TCP   5m

kubectl describe nodes | grep InternalIP
InternalIP:  192.168.208.52
```

Add settings to ssh's config
```
cat <<EOF >$FILE
Host gitlab.your-domain.xyz
        Port 30000
        HostName 192.168.208.52
EOF
```

#### For Java developers : Nexus - Maven Repository
You have to configure you maven setting if you want to pull artifacts from your Nexus.
You need to add "repository" section into your ~/.m2/settings.xml 

```
<repository>
   <id>nexus-kathra</id>
   <name>Nexus KATHRA</name>
   <url>https://nexus.your-domain.xyz/repository/maven-all/</url>
   <releases>
      <updatePolicy>always</updatePolicy>
      <enabled>true</enabled>
   </releases>
   <snapshots>
      <updatePolicy>always</updatePolicy>
      <enabled>true</enabled>
   </snapshots>
</repository>
```

#### For Docker users : Harbor - Images Repository
If you want to pull images from Harbor's repository, you have to configure your docker client (~/.docker/config).
You can use "jenkins.harbor" account to pull image with password generated into ~/.kathra_pwd.
But, we recommend to create specific account with read only access.
```
docker login --username "jenkins.harbor" --password "$(cat ~/.kathra_pwd | jq -r '.HARBOR_ADMIN_PASSWORD')" https://harbor.your-domain.xyz
```

## Troubleshootings tips

### To Reinstall 
Be careful, this command erases all services and storages (Kathra, Jenkins, Harbor, Nexus, GitLab, Keycloak)
> install.sh --purge

### GitLab-CE
#### Unable to init ApiKey

After GitLab-CE installation, somes operations are executed :
 - Confirm admin password
 - Enable kathra technical user as admin
 - Create API Key 

One of these operation can fails : the first cause, GitLab's initialization takes too long.
Your cluster can be undersized.
 

### Jenkins installation issues
#### Error: release factory-kathra-jenkins failed: timed out waiting for the condition


During Jenkins installation, init script downloads plugins required from updates.jenkins.io,  jenkins's servers can sometimes have somes troubles.

To verify this, you can check Jenkins's pod status :
> kubectl -n factory-kathra get pods -l app=factory-kathra-jenkins
```
NAME                                   READY     STATUS    RESTARTS   AGE
factory-kathra-jenkins-58d45655bd-9wcj6   0/1       Running   1          13m
```

And see logs during pod initialization
> kubectl -n factory-kathra logs -l app=factory-kathra-jenkins -c copy-default-config

```
curl: (56) Recv failure: Connection reset by peer
09:30:00 Failure (56) Retrying in 1 seconds...
09:30:01 Failed in the last attempt (curl -sSfL --connect-timeout 20 --retry 3 --retry-delay 0 --retry-max-time 60 https://updates.jenkins.io/download/plugins/ssh-credentials-plugin/latest/ssh-credentials-plugin.hpi -o /usr/share/jenkins/ref/plugins/ssh-credentials-plugin.jpi)
Failed to download plugin: ssh-credentials or ssh-credentials-plugin
curl: (52) Empty reply from server
09:30:39 Failure (52) Retrying in 1 seconds...
curl: (56) Recv failure: Connection reset by peer
09:31:10 Failure (56) Retrying in 1 seconds...
09:31:11 Failed in the last attempt (curl -sSfL --connect-timeout 20 --retry 3 --retry-delay 0 --retry-max-time 60 https://updates.jenkins.io/download/plugins/oic-auth/1.6/oic-auth.hpi -o /usr/share/jenkins/ref/plugins/oic-auth.jpi)
Downloading plugin: oic-auth-plugin from https://updates.jenkins.io/download/plugins/oic-auth-plugin/1.6/oic-auth-plugin.hpi
curl: (22) The requested URL returned error: 404 Not Found
09:32:01 Failure (22) Retrying in 1 seconds...
curl: (35) Unknown SSL protocol error in connection to updates.jenkins.io:443
09:32:42 Failure (35) Retrying in 1 seconds...
curl: (35) Unknown SSL protocol error in connection to updates.jenkins.io:443
09:33:02 Failure (35) Retrying in 1 seconds...
09:33:03 Failed in the last attempt (curl -sSfL --connect-timeout 20 --retry 3 --retry-delay 0 --retry-max-time 60 https://updates.jenkins.io/download/plugins/oic-auth-plugin/1.6/oic-auth-plugin.hpi -o /usr/share/jenkins/ref/plugins/oic-auth-plugin.jpi)
Failed to download plugin: oic-auth or oic-auth-plugin
```

Solution : To be patient until updates.jenkins.io is available and retry

#### Error: Unable to generate api token jenkins
This error can occured during api token generation
```
[########################################################################        ]  90 % Install KATHRA services...
jenkinsGenerateApiToken(login: kathra-pipelinemanager, password: LeIrLA9WqSIVuwAwDO3r, fileOut: /home/kathra/.kathra-tmp-install/jenkins.tokenValue)
 getHttpHeaderSetCookie(file: /home/kathra/.kathra-tmp-install/jenkins.configure.me.err, cookie: JSESSIONID)
 getHttpHeaderSetCookie(file: /home/kathra/.kathra-tmp-install/jenkins.commence.login.err, cookie: AUTH_SESSION_ID)
 getHttpHeaderSetCookie(file: /home/kathra/.kathra-tmp-install/jenkins.commence.login.err, cookie: KC_RESTART)
 getHttpHeaderLocation(file: /home/kathra/.kathra-tmp-install/jenkins.commence.login.err)
 getHttpHeaderLocation(file: /home/kathra/.kathra-tmp-install/jenkins.authenticate.err)
parse error: Invalid numeric literal at line 2, column 0
 Unable to generate api token jenkins
```

You can check Jenkins logs to verify its startup, some plugins can be not installed.
Jenkins is running but some errors occured during its first startup. 

This issue is caused by updates.jenkins.io

```
kubectl -n kathra-factory logs kathra-factory-jenkins-5798956669-blbqb

SEVERE: Failed Loading plugin Configuration as Code Support Plugin v1.15 (configuration-as-code-support)
java.io.IOException: Configuration as Code Support Plugin version 1.15 failed to load.
 - configuration-as-code version 1.15 is missing. To fix, install version 1.15 or later.
        at hudson.PluginWrapper.resolvePluginDependencies(PluginWrapper.java:821)
        at hudson.PluginManager$2$1$1.run(PluginManager.java:544)
        at org.jvnet.hudson.reactor.TaskGraphBuilder$TaskImpl.run(TaskGraphBuilder.java:169)
        at org.jvnet.hudson.reactor.Reactor.runTask(Reactor.java:296)
        at jenkins.model.Jenkins$5.runTask(Jenkins.java:1096)
        at org.jvnet.hudson.reactor.Reactor$2.run(Reactor.java:214)
        at org.jvnet.hudson.reactor.Reactor$Node.run(Reactor.java:117)
        at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1149)
        at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:624)
        at java.lang.Thread.run(Thread.java:748)

```



Solution: You have to retry later when updates.jenkins.io is avaliable


##  Factory products compatibilities

| Product 	      | Recommended version 	|
|--------------	|---------------------	|
| Kubernetes   	| 1.51.1             	|
| Treafik      	| 1.7.9               	|
| KubeDb       	| 0.8.0               	|
| Keycloak     	| 4.2.1               	|
| Gitlab-ci    	| 11.2.3              	|
| Nexus        	| 3.15.2              	|
| Harbor       	| 1.8.2               	|
| Jenkins      	| 2.164.3             	|

##  Jenkins plugins compatibilities

| Plugin            	      | Recommended version 	|
|------------------------	|---------------------	|
| Kubernetes             	| 1.14.9              	|
| Kubernetes credential  	| 0.4.0               	|
| Workflow aggregator    	| 2.6                 	|
| Workflow job           	| 2.32                	|
| Credential binding     	| 1.18                	|
| Docker Pipeline        	| 1.20                	|
| Git                    	| 3.9.3               	|
| OpenId connect auth    	| 1.6                 	|
| Pipeline utility steps 	| 2.3.0               	|
| Pipeline Job           	| 2.32                	|
| Matrix auth            	| 2.4.2               	|
