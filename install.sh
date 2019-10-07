#!/bin/bash
########################################################################
# KATHRA Install Wrapper
#
# @author Julien Boubechtoula
########################################################################

# Kathra version to install
export kathraVersion="factory-resources-limits"
export DEPLOYMENT_GIT_SSH="https://gitlab.com/kathra/deployment.git"
export KATHRA_CLI_GIT="https://git.kathra.org/KATHRA/kathra-cli"
export tmp=$HOME/.kathra-tmp-install
export localConfFile=$HOME/.kathra_pwd
export purge=0
export debug=0

# Helm to wrappe
export helmVersion=2.13.1
export helmPlateform=linux-amd64
export helmBin=$tmp/helm-local/$helmPlateform/helm
export tillerNs=kube-system
export helmInstallTimeout=900

# KubeDB to Install
export kubeDbVersion=0.8.0

# Namespace and App Name
export helmAppKathraName=kathra-services
export helmAppKathraNS=kathra-services
export helmFactoryKathraName=kathra-factory
export helmFactoryKathraNS=kathra-factory

# Domain's name
export BASE_DOMAIN
export NFS_SERVER

# Keycloak
export KEYCLOAK_ADMIN_LOGIN=keycloak
export KEYCLOAK_ADMIN_PASSWORD=keycloakadmin
export keycloakAdminToken

# LDAP Settings
export LDAP_ENABLED=false
export LDAP_DOMAIN="my-ldap-server.com"
export LDAP_SA="ldap_account_user"
export LDAP_PWD="ldap_account_password"
export LDAP_DN="OU=xx,DC=yy,DC=zz"
export LDAP_USER_DN="dc=xx,dc=zz"

# KATHRA's user settings for Keycloak
export USER_LOGIN=user
export USER_PASSWORD=123
export USER_PUBLIC_SSH_KEY=$HOME/.ssh/id_rsa.pub
export TEAM_NAME="my-team"

# Keycloak's user settings for Keycloak
export JENKINS_LOGIN=kathra-pipelinemanager
export JENKINS_PASSWORD=1196deae5bd111f7e0c2d5beb14c42be44
export JENKINS_API_TOKEN=

# SyncManager's user settings for Keycloak
export SYNCMANAGER_LOGIN=kathrausersynchronizer
export SYNCMANAGER_PASSWORD=q2Eewe9FjNF2JCfg

export ARANGODB_PASSWORD=VPDcYx5u6qamxTyV

# Admin's user settings for Harbor
export HARBOR_ADMIN_LOGIN=admin
export HARBOR_ADMIN_PASSWORD=

# Admin's user settings for Nexus
export NEXUS_ADMIN_PASSWORD=admin123

# Harbor's user settings for Keycloak
#export HARBOR_USER_LOGIN=jenkins.harbor
#export HARBOR_USER_PASSWORD=EwdcDEIKFJ8yiSCKx00Z
#export HARBOR_USER_SECRET_CLI

# Admin's user settings for GitLab
export GITLAB_NODEPORT=
export GITLAB_API_TOKEN=

export UA='user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/75.0.3770.80 Safari/537.36'
export headerAccept='accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3'
export headerAcceptLang="Accept-Language: fr,fr-FR;q=0.8,en-US;q=0.5,en;q=0.3"

export ASK_PARAMETERS=0

function showHelp() {
    printInfo "Usage: "
    printInfo "--domain=<my-domain.xyz>:        Base domain  [default: $BASE_DOMAIN]"
    printInfo "--user-login=<username>:         User's login [default: $USER_LOGIN]"
    printInfo "--user-password=<password>:      User's password [default: $USER_PASSWORD]"
    printInfo "--user-public-key=<file-path>:   User's public key [default: $USER_PUBLIC_SSH_KEY]"
    printInfo "--user-team=<name>:              User's team name [default: $TEAM_NAME]"
    printInfo "--factory-ns=<namespace>:        Factory K8S namespace [default: $helmFactoryKathraNS]"
    printInfo "--kathra-ns=<namespace>:          Kathra K8S namespace [default: $helmAppKathraNS]"
    printInfo "--interactive -i:                Interactive mode"
    printInfo "--purge -p:                      Clean previous install (delete all persistent data)"
    printInfo "--verbose:                       Enable DEBUG log level"
    printInfo "--tiller-ns:                     Tiller namespace"
    printInfo "--ldap-server=<value>:           LDAP server [default: $LDAP_DOMAIN]"
    printInfo "--ldap-sa=<value>:               LDAP service account [default: $LDAP_SA]"
    printInfo "--ldap-password=<value>:         LDAP password [default: $LDAP_PWD]"
    printInfo "--ldap-dn=<value>:               LDAP dn [default: $LDAP_DN]"
    printInfo "--ldap-user-dn=<value>:          LDAP user dn [default: $LDAP_USER_DN]"
    exit 0
}

function parseArgs() {
    for argument in "$@" 
    do
        local key=${argument%%=*}
        local value=${argument#*=}
        case "$key" in
            --domain)                       BASE_DOMAIN=$value;;
            --user-login)                   USER_LOGIN=$value;;
            --user-password)                USER_PASSWORD=$value;;
            --user-public-key)              USER_PUBLIC_SSH_KEY=$value;;
            --user-team)                    TEAM_NAME=$value;;
            --interactive|-i)               ASK_PARAMETERS=1;;
            --factory-ns)                   helmFactoryKathraNS=$value;;
            --kathra-ns)                     helmAppKathraNS=$value;;
            --help|-h)                      showHelp;;
            --verbose)                      debug=1;;
            --tiller-ns)                    tillerNs=$value;;
            --purge|-p)
                                            purge=1
                                            echo -e "\e[41m All existing data into PV and PVC will be deleted \033[0m" 1>&2
                                            askYesOrNo "Are you sure ?" || exit 0
                                            ;;
            --ldap-server)                  LDAP_DOMAIN=$value && export LDAP_ENABLED=true;;
            --ldap-sa)                      LDAP_SA=$value && export LDAP_ENABLED=true;;
            --ldap-password)                LDAP_PWD=$value && export LDAP_ENABLED=true;;
            --ldap-dn)                      LDAP_DN=$value && export LDAP_ENABLED=true;;
            --ldap-user-dn)                 LDAP_USER_DN=$value && export LDAP_ENABLED=true;;
        esac    
    done
}

###
### Main program
###     * Parse arguments
###     * Ask setup configuration (K8S namespaces, domain's name, user/password, ssh-key, ldap setting)
###     * Download specific Helm version
###     * Install KubeDb if not exists
###     * Check Treafik is installed
###     * Checkout Charts from repository
###     * Generate password
###     * Install factory (Keycloak, NFS, GitLab, Nexus, Harbor, Jenkins)
###     * Install KATHRA's services
###
function main() {
    printInfo "KATHRA INSTALLER (VERSION : $kathraVersion)"
    parseArgs $@
    local start=`date +%s`
    # Purge temp
    [ -d $tmp ] && rm -Rf $tmp
    mkdir $tmp
    # Install JQ if not exists
    command -v jq > /dev/null || installJq

    if [ $ASK_PARAMETERS -eq 1 ]
    then
        defineVar "helmFactoryKathraNS" "Factory's namespace"
        defineVar "helmAppKathraNS" "Kathra's namespace"
        defineVar "BASE_DOMAIN" "Domain name"    
        defineVar "USER_LOGIN" "Username to first user"
        defineSecretVar "USER_PASSWORD" "Password"
        defineVar "TEAM_NAME" "Group's name"
        writeEntryIntoFile "USER_LOGIN" "$USER_LOGIN"
        writeEntryIntoFile "USER_PASSWORD" "$USER_PASSWORD"
        defineVar "USER_PUBLIC_SSH_KEY" "SSH PublicKey file"

        askYesOrNo "Do you want to configure LDAP directory ?"
        if [ $? -eq 0 ]
        then
            export LDAP_ENABLED=true
            defineVar "LDAP_DOMAIN" "LDAP's host server"    
            defineVar "LDAP_SA" "LDAP's service account login"
            defineSecretVar "LDAP_PWD" "LDAP's service account password"
            defineVar "LDAP_DN" "LDAP's group DN"
            defineVar "LDAP_USER_DN" "LDAP's user group DN"
            
            writeEntryIntoFile "LDAP_DOMAIN" "$LDAP_DOMAIN"
            writeEntryIntoFile "LDAP_SA" "$LDAP_SA"
            writeEntryIntoFile "LDAP_PWD" "$LDAP_PWD"
            writeEntryIntoFile "LDAP_DN" "$LDAP_DN"
            writeEntryIntoFile "LDAP_USER_DN" "$LDAP_USER_DN"
        fi
    else
        [ ! -f "$USER_PUBLIC_SSH_KEY" ] && printWarn "Unable to find public key : $USER_PUBLIC_SSH_KEY"
    fi
    [ "$BASE_DOMAIN" == "" ] && printError "Base domain is undefined" && exit 1

    progressBar "0" "Download Helm v${helmVersion}-${helmPlateform} ..." && installHelm && printInfo "OK"
    progressBar "5" "Check Helm Tiller..." && checkTillerHelm && printInfo "OK"
    progressBar "10" "Check KubeDB..." && installKubeDBifNotPresent && printInfo "OK"
    progressBar "15" "Check Treafik..." && checkTreafikInstall && printInfo "OK"
    progressBar "20" "Clone Charts from version ${kathraVersion}..." && cloneCharts && printInfo "OK"
    progressBar "24" "Generating password..." && initPasswords && printInfo "OK"
    
    
    progressBar "25" "Install Keycloak..." && installKathraFactoryKeycloak && printInfo "OK"
    progressBar "30" "Install NFS-Server..." && installKathraFactoryChart "nfs" && printInfo "OK"
    progressBar "35" "Install Harbor..." && installKathraFactoryHarbor && printInfo "OK"

    #export HARBOR_USER_SECRET_CLI=$(readEntryIntoFile "HARBOR_USER_SECRET_CLI")

    cat > $tmp/commands_to_exec <<EOF
    printInfo "Install Jenkins... Pending" && installJenkins && printInfo "Install Jenkins... OK"
    printInfo "Install GitLab-CE... Pending" && installGitlab && printInfo "Install GitLab-CE... OK"
    printInfo "Install Nexus... Pending" && installKathraFactoryChart "nexus" && printInfo "Install Nexus... OK"
    printInfo "Install DeployManager... Pending" && installKathraFactoryChart "kathra-deploymanager" && printInfo "Install DeployManager... OK"
EOF
    cat $tmp/commands_to_exec | xargs -I{} -n 1 -P 5  bash -c {}
    
    progressBar "90" "Install KATHRA services..." && installKathraService && printInfo "OK"
    
    progressBar "100" "Done..."

    printInfo "Kathra is installed in $((`date +%s`-start)) secondes"
    printInfo "You can use Kathra from dashboard : https://dashboard.${BASE_DOMAIN} or from kathra-cli: $KATHRA_CLI_GIT"
    printInfo "Yours passwords are stored here : $localConfFile" 
    return 0
}

function askYesOrNo() {
    local question=$1
    while true; do
        read -p "$(printInfo $question [Y/N] \?)" yn  1>&2
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) printError "Please answer yes or no."  1>&2;;
        esac
    done
}

function initPasswords() {
    printInfo "Use existing passwords from file '$localConfFile' or generate new ones.... "
    generatePasswordIfNotExist "KEYCLOAK_ADMIN_PASSWORD"
    generatePasswordIfNotExist "JENKINS_PASSWORD"
    generatePasswordIfNotExist "SYNCMANAGER_PASSWORD"
    generatePasswordIfNotExist "ARANGODB_PASSWORD"
    generatePasswordIfNotExist "HARBOR_ADMIN_PASSWORD"
    #writeEntryIntoFile "HARBOR_USER_LOGIN" "$HARBOR_USER_LOGIN"
    #generatePasswordIfNotExist "HARBOR_USER_PASSWORD"
    generatePasswordIfNotExist "NEXUS_ADMIN_PASSWORD"
}
export -f initPasswords
function generatePasswordIfNotExist() {
    local key=$1
    local existingPassword=$(readEntryIntoFile "$key")
    [ "$existingPassword" == "null" ] && generatePassword "$key" || eval "export $key=\"$existingPassword\""
}
export -f generatePasswordIfNotExist
function generatePassword() {
    local key=$1
    local pwd="$(< /dev/urandom tr -dc A-Za-z0-9 | head -c20;echo;)"
    eval "export $key=\"$pwd\""
    writeEntryIntoFile "$key" "$pwd"
}
export -f generatePassword

function writeEntryIntoFile(){
    local key=$1
    local value=$2
    [ ! -f $localConfFile ] && echo "{}" > $localConfFile
    jq ".$key = \"$value\"" $localConfFile > $localConfFile.updated && mv $localConfFile.updated $localConfFile
}
export -f writeEntryIntoFile

function readEntryIntoFile() {
    local key=$1
    [ ! -f $localConfFile ] && echo "{}" > $localConfFile
    jq -r ".$key" < $localConfFile
}
export -f readEntryIntoFile


function progressBar() {
    local w=80 p=$1;  shift
    printf -v dots "%*s" "$(( $p*$w/100 ))" "" 1>&2; dots=${dots// /#};
    printf "\r\e[K\033[33;1m[%-*s] %3d %% %s\033[0m" "$w" "$dots" "$p" "$*"  1>&2; 
    return 0
}
export -f progressBar
function printError(){
    echo -e "\033[31;1m $* \033[0m" 1>&2
}
export -f printError
function printWarn(){
    echo -e "\033[33;1m $* \033[0m" 1>&2
}
export -f printWarn
function printInfo(){
    echo -e "\033[33;1m $* \033[0m" 1>&2
}
export -f printInfo
function printDebug(){
    [ $debug -eq 1 ] && echo -e "\033[94;1m $* \033[0m" 1>&2
}
export -f printDebug
###
### Download helm wrapper
###
function installHelm() {
    local uriHelm="https://storage.googleapis.com/kubernetes-helm/helm-v${helmVersion}-${helmPlateform}.tar.gz"
    curl ${uriHelm} > $tmp/helm-local.tar.gz 2> /dev/null
    [ $? -ne 0 ] && printError "Unable to get ${uriHelm}" && exit 1
    mkdir $tmp/helm-local/ && tar xvzf $tmp/helm-local.tar.gz -C $tmp/helm-local/ 2>&1 > /dev/null && chmod +x $tmp/helm-local/$helmPlateform/*
    return $?
}
export -f installHelm
###
### Check if Tiller Helm is installed
###
function checkTillerHelm() {
    $helmBin version --tiller-namespace=$tillerNs > /dev/null && printInfo "Tiller existing into namespace $tillerNs" && return 0
    echo ""
    while true; do
        read -p "$(printInfo Tiller namespace [default:$tillerNs] ?)" tillerNsDefined
        [ ! "$tillerNsDefined" == "" ] && tillerNs=$tillerNsDefined
        $helmBin version --tiller-namespace=$tillerNs > /dev/null && printInfo "Tiller existing into namespace $tillerNs" && return
        [ $? -ne 0 ] && printError "Unable to find tiller into namespace $tillerNs, please install helm's tiller before ($helmBin init)" && exit 1
    done
}
###
### Install JQ
###
function installJq() {
    sudo apt-get install jq -y 2>&1 > $tmp/log.installJq.$name
    [ $? -ne 0 ] && printError "Unable to install jq package $(cat cat $tmp/log.installJq.$name)" && exit 1
}
export -f installJq
###
### Install kubeDb
###
function installKubeDBifNotPresent() {
    [ $($helmBin --tiller-namespace=$tillerNs ls --output json | jq -c '.Releases[] | select((.Name=="kubedb-operator") and (.Chart|test("kubedb-.")))' | wc -l) -gt 0 ] && return
    #printInfo "KubeDB ${kubeDbVersion} is missing. Installing.." && curl -fsSL https://raw.githubusercontent.com/kubedb/cli/${kubeDbVersion}/hack/deploy/kubedb.sh 2> $tmp/log.installKubeDBifNotPresent | bash 2>&1 >> $tmp/log.installKubeDBifNotPresent
    [ $? -ne 0 ] && printError "Unable to install KubeDB ${kubeDbVersion} : $(cat $tmp/log.installKubeDBifNotPresent)" && exit 1
}
###
### Verify if Treafik is installed
###
function checkTreafikInstall() {
    [ $(kubectl get --all-namespaces deployments -o json | jq -c '.items[] | select((.metadata.name=="traefik-ingress-controller-http") or (.metadata.name=="traefik"))' | wc -l) -gt 0 ] && return
    printError "Treafik is missing. Please install.. ($helmBin install stable/traefik) and configure it DNS and SSL Challenge with your DNS provider and Let's Encrypt."
    exit 1
}
export -f checkTreafikInstall
###
### Install GitLab
###
function installGitlab() {
    [ $purge -eq 0 ] && checkChartDeployed "$helmFactoryKathraNS" "$helmFactoryKathraName-gitlab-ce" && printInfo "Gitlab-CE already deployed" && return 2
    [ -f $tmp/gitlab.nodePort ] && rm $tmp/gitlab.nodePort
    findNodePortAvailable > $tmp/gitlab.nodePort || return 1
    export GITLAB_NODEPORT=$(cat $tmp/gitlab.nodePort)
    installKathraFactoryChart "gitlab-ce"
    gitlabResetAdminPwd "$SYNCMANAGER_PASSWORD"
    
    gitlabGenerateApiToken "$USER_LOGIN" "$USER_PASSWORD" "$tmp/gitlab.user.tokenValue" 
    writeEntryIntoFile "GITLAB_API_TOKEN_USER" "$(cat $tmp/gitlab.user.tokenValue)"
    [ -f "$USER_PUBLIC_SSH_KEY" ] && gitlabImportPublicSshKey "$USER_LOGIN" "$(cat $tmp/gitlab.user.tokenValue)" "$USER_PUBLIC_SSH_KEY"
    
    local nodeIp=$(kubectl get nodes -o json | jq -r '.items[0] | .status.addresses[] | select(.type=="InternalIP") | .address ')
    configureSSHConfig "gitlab.${BASE_DOMAIN}" "$nodeIp" "$GITLAB_NODEPORT"

    return $?
}
export -f installGitlab

function findNodePortAvailable() {
    local portAvailable
    kubectl get services --all-namespaces -o json | jq '.items[] | select(.spec.type == "NodePort") | .spec.ports[] | .nodePort' > $tmp/findNodePortAvailable.nodePortsExistings
    for port in {30000..32767}; 
    do
        grep "^${port}$" < $tmp/findNodePortAvailable.nodePortsExistings 2> /dev/null > /dev/null || portAvailable=$port
        [ ! "$portAvailable" == "" ] && echo $portAvailable && return 0
    done
    printError "Unable to find NodePort available" && return 1
}
export -f findNodePortAvailable

function configureSSHConfig() {
    local hostName=$1
    local nodeIp=$2
    local nodePortSSH=$3
    printDebug "configureSSHConfig(hostName: $hostName, nodeIp: $nodeIp, nodePortSSH: $nodePortSSH)"
    cat > $tmp/.sshConfig <<EOF

Host ${hostName}
    Port ${nodePortSSH}
    HostName ${nodeIp}

EOF
    ## remove previous host config if exists
    [ -f ~/.ssh/config ] && cat ~/.ssh/config | sed ':a;N;$!ba;s/\n/#RC#/g' | sed "s#Host ${hostName}.*Host #Host #g" | sed 's/#RC#/\n/g' >> $tmp/.sshConfig
    cat $tmp/.sshConfig > ~/.ssh/config
    chmod 600 ~/.ssh/config
    return 0
}
export -f configureSSHConfig
###
### Install Jenkins
###
function installJenkins() {
    [ $purge -eq 0 ] && checkChartDeployed "$helmFactoryKathraNS" "$helmFactoryKathraName-jenkins" && printInfo "Jenkins already deployed" && return 2
    NFS_SERVER=$(kubectl -n $helmFactoryKathraNS get services nfs-server -o json 2> /dev/null | jq -r -c '.spec.clusterIP' 2> /dev/null)
    [ "${NFS_SERVER}" == "" ] && printError "Unable to find service nfs-server into namespace $helmFactoryKathraNS" && exit 1
    installKathraFactoryChart "jenkins"
    return $?
}
export -f installJenkins

function defineVar() {
    local varName=$1
    local msg=$2
    local override
    read -p "$(printInfo $msg [default:${!varName}] '?')" override
    [ ! "$override" == "" ] && eval "$varName=$override"
}
function defineSecretVar() {
    local varName=$1
    local msg=$2
    local override
    read -s -p "$(printInfo $msg [default:${!varName}] '?')" override
    [ ! "$override" == "" ] && eval "$varName=$override"
}
###
### Clone chart from repository
###
function cloneCharts() {
    git clone --single-branch --branch ${kathraVersion}  ${DEPLOYMENT_GIT_SSH} $tmp/deployment 2> /dev/null
    [ $? -ne 0 ] && printError "Unable to clone ${DEPLOYMENT_GIT_SSH}" && exit 1
    return 0
}
###
### Install Keycloak
###
function installKathraFactoryKeycloak() {
    [ $purge -eq 0 ] && checkChartDeployed "$helmFactoryKathraNS" "$helmFactoryKathraName-keycloak" && printInfo "Keycloak already deployed" && return 2
    
    kubectl -n $helmFactoryKathraNS patch postgres.kubedb.com keycloak-postgres-kubedb -p '{"spec":{"doNotPause":false}}' --type="merge" 2> /dev/null > /dev/null
    kubectl -n $helmFactoryKathraNS delete postgres.kubedb.com keycloak-postgres-kubedb 2> /dev/null > /dev/null
    kubectl -n $helmFactoryKathraNS delete pvc data-keycloak-postgres-kubedb-0 2> /dev/null > /dev/null
    installKathraFactoryChart "keycloak"
    keycloakInitToken
    keycloakCreateGroup "kathra-projects" $tmp/group.kathra-projects
    keycloakCreateGroup "${TEAM_NAME}" $tmp/group.default "$(cat $tmp/group.kathra-projects | tr -d '\r')"
    keycloakCreateUser "${USER_LOGIN}" "${USER_PASSWORD}" "$(cat $tmp/group.default | tr -d '\r')" $tmp/kathra.keycloak.firstUser
    keycloakCreateGroup "jenkins-admin" $tmp/group.jenkins-admin
    keycloakCreateUser "${JENKINS_LOGIN}" "$(readEntryIntoFile "JENKINS_PASSWORD")" "$(cat $tmp/group.jenkins-admin | tr -d '\r')" $tmp/kathra.keycloak.jenkins-admin
    #keycloakCreateUser "${HARBOR_USER_LOGIN}" "$(readEntryIntoFile "HARBOR_USER_PASSWORD")" "" $tmp/kathra.keycloak.harbor-admin
    keycloakCreateUser "${SYNCMANAGER_LOGIN}" "$(readEntryIntoFile "SYNCMANAGER_PASSWORD")" "" $tmp/kathra.keycloak.${SYNCMANAGER_LOGIN}
    keycloakInitPermission
    restartKeycloak
    return $?
}
export -f installKathraFactoryKeycloak

function restartKeycloak() {
    printDebug "restartKeycloak()"
    #Kill pod for restart updated BDD config
    kubectl -n $helmFactoryKathraNS delete pod $(kubectl -n $helmFactoryKathraNS get pods -l=app=keycloak -o json | jq -r -c '.items[0] | .metadata.name') 2> /dev/null > /dev/null
    checkCommandAndRetry "curl --output /dev/null --silent --head --fail https://keycloak.${BASE_DOMAIN}"
    [ $? -ne 0 ] && printError "https://keycloak.${BASE_DOMAIN} is not ready" && exit 1
    printDebug "Keycloak is ready"
}
export -f restartKeycloak

###
### Install Habor
###
function installKathraFactoryHarbor() {
    [ $purge -eq 0 ] && checkChartDeployed "$helmFactoryKathraNS" "$helmFactoryKathraName-harbor" && printInfo "Harbor already deployed" && return 2
    
    kubectl -n $helmFactoryKathraNS delete jobs harbor-database-init harbor-ldap-config harbor-oicd-config 2> /dev/null > /dev/null
    kubectl -n $helmFactoryKathraNS delete pvc $helmFactoryKathraName-harbor-harbor-chartmuseum $helmFactoryKathraName-harbor-harbor-jobservice $helmFactoryKathraName-harbor-harbor-registry $helmFactoryKathraName-harbor-harbor-redis-0 2> /dev/null > /dev/null
    
    local redisPVC=$(kubectl -n $helmFactoryKathraNS get pvc -o json | jq -r -c ".items[] | select(.metadata.name | test(\"harbor-harbor-redis-0\")) | .metadata.name ")
    local dbPVC=$(kubectl -n $helmFactoryKathraNS get pvc -o json | jq -r -c ".items[] | select(.metadata.name | test(\"harbor-harbor-database-0\")) | .metadata.name ")
    [ ! "$redisPVC" == "" ] && kubectl -n $helmFactoryKathraNS delete pvc $redisPVC 2> /dev/null > /dev/null
    [ ! "$dbPVC" == "" ] && kubectl -n $helmFactoryKathraNS delete pvc $dbPVC 2> /dev/null > /dev/null
    
    installKathraFactoryChart "harbor" || return 1
    #harborDefineAccountAsAdmin "$HARBOR_USER_LOGIN" "$HARBOR_USER_PASSWORD" "$HARBOR_ADMIN_LOGIN" "$HARBOR_ADMIN_PASSWORD" || return 1

    #harborInitCliSecret $HARBOR_ADMIN_LOGIN $HARBOR_ADMIN_PASSWORD $HARBOR_USER_LOGIN "$tmp/harbor.tokenValue"
    #export HARBOR_USER_SECRET_CLI=$(cat $tmp/harbor.tokenValue)
    #writeEntryIntoFile "HARBOR_USER_SECRET_CLI" "$HARBOR_USER_SECRET_CLI"

    return 0
}
export -f installKathraFactoryHarbor

function checkChartDeployed() {
    [ $($helmBin --tiller-namespace=$tillerNs --namespace $1 list -c $2 --output json 2> /dev/null  | jq -c '.Releases[] | select(.Status=="DEPLOYED")' | wc -l) -ne 0 ] && return 0 || return 1
}
export -f checkChartDeployed

function installKathraFactoryChart() {
    local name=$1
    printDebug "installKathraFactoryChart(name: $name)"

    [ $purge -eq 0 ] && checkChartDeployed "$helmFactoryKathraNS" "$helmFactoryKathraName-${name}" && printInfo "${name} already deployed" && return 2
    [ -f $tmp/deployment/kathra-factory/${name}/extra-vars-wrapper.yaml ] && overrideEnvVar $tmp/deployment/kathra-factory/${name}/extra-vars-wrapper.yaml $tmp/deployment/kathra-factory/${name}/extra-vars-wrapper-configured.yaml || touch $tmp/deployment/kathra-factory/${name}/extra-vars-wrapper-configured.yaml
    
    $helmBin --tiller-namespace=$tillerNs delete $helmFactoryKathraName-${name} --purge 2> /dev/null > /dev/null 
    $helmBin --tiller-namespace=$tillerNs install --namespace $helmFactoryKathraNS --timeout $helmInstallTimeout --name $helmFactoryKathraName-${name} $tmp/deployment/kathra-factory/${name}/ --wait -f $tmp/deployment/kathra-factory/${name}/extra-vars-wrapper-configured.yaml 2>&1 > $tmp/log.installKathraFactoryChart.$name

    [ $? -ne 0 ] && printError "Unable to install ${name} $(cat $tmp/log.installKathraFactoryChart.$name)" && exit 1
    return 0
}
export -f installKathraFactoryChart

function overrideEnvVar() {
    local vars=( 'BASE_DOMAIN' 'K8S_NAMESPACE_NAME' 'GITLAB_API_TOKEN' 'NFS_SERVER' 'ARANGODB_PASSWORD' 'JENKINS_LOGIN' 'JENKINS_API_TOKEN' 'SYNCMANAGER_LOGIN' 'SYNCMANAGER_PASSWORD' 'GITLAB_NODEPORT' 'HARBOR_ADMIN_LOGIN' 'HARBOR_ADMIN_PASSWORD' 'HARBOR_USER_LOGIN' 'HARBOR_USER_PASSWORD' 'NEXUS_ADMIN_PASSWORD' 'HARBOR_USER_SECRET_CLI' 'KEYCLOAK_ADMIN_LOGIN' 'KEYCLOAK_ADMIN_PASSWORD' 'LDAP_ENABLED' 'LDAP_SA' 'LDAP_DOMAIN' 'LDAP_PWD' 'LDAP_USER_DN' 'LDAP_USER_DN' 'LDAP_ADMIN_DN' 'LDAP_DN' )
    local cmd=""
    for i in "${vars[@]}"; do cmd="$cmd | replaceVarName $i"; done
    eval "cat $1 $cmd > $2"
    return $? 
}
export -f overrideEnvVar

function replaceVarName() {
    local varName=$1
    sed -e "s@\${${varName}}@${!varName}@ig"
}
export -f replaceVarName

function installKathraService() { 
    [ $purge -eq 0 ] && checkChartDeployed "$helmAppKathraNS" "$helmAppKathraName" && printInfo "KATHRA already deployed" && return 2
    
    gitlabGenerateApiToken "$SYNCMANAGER_LOGIN" "$(readEntryIntoFile "SYNCMANAGER_PASSWORD")" "$tmp/gitlab.tokenValue" 
    export GITLAB_API_TOKEN=$(cat $tmp/gitlab.tokenValue)
    writeEntryIntoFile "GITLAB_API_TOKEN" "$GITLAB_API_TOKEN"
    
    jenkinsGenerateApiToken "$JENKINS_LOGIN" "$(readEntryIntoFile "JENKINS_PASSWORD")" "$tmp/jenkins.tokenValue"
    export JENKINS_API_TOKEN=$(cat $tmp/jenkins.tokenValue)
    writeEntryIntoFile "JENKINS_API_TOKEN" "$JENKINS_API_TOKEN"
    
    #export HARBOR_USER_SECRET_CLI=$(readEntryIntoFile "HARBOR_USER_SECRET_CLI")

    [ "${JENKINS_API_TOKEN}" == "" ] && defineVar "JENKINS_API_TOKEN" "Please generate a Jenkins's Api Token from (https://jenkins.${BASE_DOMAIN}/user/${JENKINS_LOGIN}/configure password: ${JENKINS_PASSWORD})"
    [ "${GITLAB_API_TOKEN}" == "" ] && defineVar "GITLAB_API_TOKEN" "Please generate a GitLab's Api Token from (https://gitlab.${BASE_DOMAIN}/profile/personal_access_tokens)"
    #[ "${HARBOR_USER_SECRET_CLI}" == "" ] && defineVar "HARBOR_USER_SECRET_CLI" "Please generate a Harbor's Api Token from (https://harbor.${BASE_DOMAIN})"
    
    overrideEnvVar $tmp/deployment/kathra-services/extra-vars-wrapper.yaml $tmp/deployment/kathra-services/extra-vars-wrapper-configured.yaml

    $helmBin --tiller-namespace=$tillerNs delete $helmAppKathraName --purge 2> /dev/null > /dev/null
    $helmBin --tiller-namespace=$tillerNs install --timeout $helmInstallTimeout --namespace $helmAppKathraNS --name $helmAppKathraName -f $tmp/deployment/kathra-services/extra-vars-wrapper-configured.yaml $tmp/deployment/kathra-services/ 2>&1 > $tmp/log.installKathraService.$name
    [ $? -ne 0 ] && printError "Unable to install Kathra Services $(cat $tmp/log.installKathraService.$name)" && exit 1
    waitUntilJobSyncIsSucceeded || exit 1
    return 0
}
export -f installKathraService
function waitUntilJobSyncIsSucceeded() {
    checkCommandAndRetry "kubectl -n $helmAppKathraNS get jobs -o json | jq '.items[] | select(.metadata.ownerReferences[0].name == \"kathra-synchro\")  | select(.status.succeeded == 1) | .status.succeeded' | head -n 1 | grep 1 > /dev/null"
    [ $? -ne 0 ] && printError "Job 'kathra-synchro' isn't succeeded" && return 1
    printDebug "Job 'kathra-synchro' is succeeded"
    return 0
}
export -f waitUntilJobSyncIsSucceeded
###
### Create keycloak user
###
function keycloakCreateUser() {
    printDebug "keycloakCreateUser(username: $1, password: $2, groupUUID: $3, uuidFile: $4)"
    curl -v -X POST https://keycloak.${BASE_DOMAIN}/auth/admin/realms/kathra/users -H "Content-Type: application/json" -H "Authorization: bearer $keycloakAdminToken"   --data "{\"username\":\"${1}\", \"enabled\":\"true\", \"emailVerified\":\"true\",\"email\":\"${1}@${BASE_DOMAIN}\", \"credentials\": [{\"type\": \"password\",\"value\": \"${2}\", \"temporary\": \"false\"}]}" 2>&1 | grep -i "< Location:" | sed 's/^.*\/users\/\(.*\)$/\1/' > $4
    [ $? -ne 0 ] && printError "Unable to create user '$1' into keycloak" && exit 1
    [ "${3}" == "" ] && return 0
    curl -X PUT https://keycloak.${BASE_DOMAIN}/auth/admin/realms/kathra/users/$(cat $4 | tr -d '\r')/groups/${3} -H "Authorization: bearer $keycloakAdminToken"
    [ $? -ne 0 ] && printError "Unable to add user '$1' into keycloak's group '$3'" && exit 1
    return 0
}
export -f keycloakCreateUser
###
### Create Keycloak group
###
function keycloakCreateGroup() {
    printDebug "keycloakCreateGroup(groupName: $1, uuidFile: $2, groupParentUUID: $3 )"
    [ "${3}" == "" ] && path="/auth/admin/realms/kathra/groups" || path="/auth/admin/realms/kathra/groups/${3}/children"
    curl -v -X POST https://keycloak.${BASE_DOMAIN}${path} -H "Content-Type: application/json" -H "Authorization: bearer $keycloakAdminToken" --data "{\"name\":\"$1\"}" 2>&1 | grep -i "< Location:" | sed 's/^.*\/groups\/\(.*\)$/\1/' > $2
    [ $? -ne 0 ] && printError "Unable to create group '$1' into keycloak" && exit 1
    return 0
}
export -f keycloakCreateGroup
###
### Get Keycloak Token
###
function keycloakInitToken() {
    printDebug "keycloakInitToken()"
    local RESULT=`curl --data "username=${KEYCLOAK_ADMIN_LOGIN}&password=${KEYCLOAK_ADMIN_PASSWORD}&grant_type=password&client_id=admin-cli" "https://keycloak.${BASE_DOMAIN}/auth/realms/master/protocol/openid-connect/token" 2> /dev/null ` && keycloakAdminToken=`echo $RESULT | sed 's/.*access_token":"//g' | sed 's/".*//g'` && return 0
    return 1
}
export -f keycloakInitToken
###
### Push keycloak policy
###
function keycloakCreatePolicy() {
    printDebug "keycloakCreatePolicy(clientUuid: $1, uuidFile: $2)"
    local policy="{\"type\":\"js\",\"logic\":\"POSITIVE\",\"decisionStrategy\":\"UNANIMOUS\",\"name\":\"Only users from shared group policy\",\"description\":\"Only users from shared group policy\",\"code\":\"var context = \$evaluation.getContext(); \n var permission = \$evaluation.getPermission(); \n var identity = context.getIdentity(); \n var resource = permission.getResource(); \n  \n var identityAttr = identity.getAttributes().toMap(); \n var groups = identityAttr.get('groups'); \n  \n // Prefixing owner-group path with leading /, to match Keycloak groups mapping ['/group1', '/group2'] \n var ownerGroup = '/' + resource.getSingleAttribute('owner-group'); \n if (resource.getSingleAttribute('owner-group') != null && resource.getSingleAttribute('owner-group').startsWith('/')){ \n     ownerGroup = resource.getSingleAttribute('owner-group'); \n } \n var groupId = '/' + resource.getSingleAttribute('groupId'); \n if (resource.getSingleAttribute('groupId') != null && resource.getSingleAttribute('groupId').startsWith('/')){ \n     groupId = resource.getSingleAttribute('groupId'); \n } \n var groupPath = '/' + resource.getSingleAttribute('groupPath'); \n if (resource.getSingleAttribute('groupPath') != null && resource.getSingleAttribute('groupPath').startsWith('/')){ \n     groupPath = resource.getSingleAttribute('groupPath'); \n } \n  \n for(var i=0; i<groups.length; i++){ \n     print('Current User Group: ' + groups[i]); \n     if(ownerGroup == groups[i] || groupId == groups[i] || groupPath == groups[i]){ \n         \$evaluation.grant(); \n     } \n }\"}"
    keycloakPostJson "/auth/admin/realms/kathra/clients/${1}/authz/resource-server/policy/js" "${policy}"  "${2}"
    return $?
}
export -f keycloakCreatePolicy

function keycloakServiceAccountsAssignRole() {
    printDebug "keycloakServiceAccountsAssignRole(clientOrigin: $1, clientRole: $2, roleToAssign: $3)"
    local clientOrigin=$1
    local clientRole=$2
    local roleToAssign=$3
    keycloakGetJson "/auth/admin/realms/kathra/clients" > $tmp/keycloakServiceAccountsAssignRole.clients
    
    jq -c ".[] | select(.clientId==\"${clientOrigin}\")" < $tmp/keycloakServiceAccountsAssignRole.clients | jq -r -c '.id' > $tmp/keycloakServiceAccountsAssignRole.$clientOrigin.uuid
    jq -c ".[] | select(.clientId==\"${clientRole}\")" < $tmp/keycloakServiceAccountsAssignRole.clients | jq -r -c '.id' > $tmp/keycloakServiceAccountsAssignRole.$clientRole.uuid
    
    local clientOriginUUID=$(cat $tmp/keycloakServiceAccountsAssignRole.$clientOrigin.uuid)
    local clientRoleUUID=$(cat $tmp/keycloakServiceAccountsAssignRole.$clientRole.uuid)
    
    keycloakGetJson "/auth/admin/realms/kathra/clients/${clientOriginUUID}/service-account-user" | jq -r -c '.id' > $tmp/keycloakServiceAccountsAssignRole.$clientRole.service-account-user.uuid
    local serviceAccountUUID=$(cat $tmp/keycloakServiceAccountsAssignRole.$clientRole.service-account-user.uuid)
    keycloakGetJson "/auth/admin/realms/kathra/users/${serviceAccountUUID}/role-mappings/clients/${clientRoleUUID}/available" > $tmp/keycloakServiceAccountsAssignRole.${serviceAccountUUID}.role-mappings.${clientRole}.available
    
    jq -c ".[] | select(.name==\"${roleToAssign}\")" < $tmp/keycloakServiceAccountsAssignRole.${serviceAccountUUID}.role-mappings.${clientRole}.available > $tmp/keycloakServiceAccountsAssignRole.${serviceAccountUUID}.role-mappings.${clientRole}.available.${roleToAssign}
    jq -r -c '.id' < $tmp/keycloakServiceAccountsAssignRole.${serviceAccountUUID}.role-mappings.${clientRole}.available.${roleToAssign} > $tmp/keycloakServiceAccountsAssignRole.${serviceAccountUUID}.role-mappings.${clientRole}.available.${roleToAssign}.id
   
    local data="[$(cat $tmp/keycloakServiceAccountsAssignRole.${serviceAccountUUID}.role-mappings.${clientRole}.available.${roleToAssign})]"
    keycloakPostJson "/auth/admin/realms/kathra/users/${serviceAccountUUID}/role-mappings/clients/${clientRoleUUID}" "${data}" $tmp/keycloakServiceAccountsAssignRole.${serviceAccountUUID}.role-mappings.${clientRole}.available.${roleToAssign}.assigned
}
export -f keycloakServiceAccountsAssignRole

function keycloakCreateScope() {
    printDebug "keycloakCreateScope(scopeName: $1, clientUuid: $2, uuidFile: $3)"
    keycloakPostJson "/auth/admin/realms/kathra/clients/${2}/authz/resource-server/scope" "{\"name\":\"${1}\",\"displayName\":\"${1}\",\"iconUri\":\"\"}" "${3}"
}
export -f keycloakCreateScope

function keycloakPostJson() {
    printDebug "keycloakPostJson(path: $1, data: $2, uuidFile: $3)"
    curl --fail -v -X POST https://keycloak.${BASE_DOMAIN}${1} -H "Content-Type: application/json" -H "Authorization: bearer $keycloakAdminToken" --data "${2}" 2> /dev/null | jq -r -c '.id' > $3
    [ $? -ne 0 ] && printError "Unable to configure keycloak : POST https://keycloak.${BASE_DOMAIN}${1} DATA=${2}" && exit 1
}
export -f keycloakPostJson

function keycloakGetJson() {
    printDebug "keycloakGetJson(path: $1)"
    curl --fail -v https://keycloak.${BASE_DOMAIN}${1} -H "Content-Type: application/json" -H "Authorization: bearer $keycloakAdminToken" 2> /dev/null
    [ $? -ne 0 ] && printError "Unable to configure keycloak : GET https://keycloak.${BASE_DOMAIN}${1}" && exit 1
}
export -f keycloakGetJson

function keycloakCreatePermissionScopeBased() {
    printDebug "keycloakCreatePermissionScopeBased(path: $1, clientUuid: $2, scopeUuid: $3,policyUuid: $4,uuidFile: $5)"
    keycloakPostJson "/auth/admin/realms/kathra/clients/${2}/authz/resource-server/permission/scope" "{\"type\":\"scope\",\"logic\":\"POSITIVE\",\"decisionStrategy\":\"UNANIMOUS\",\"name\":\"${1}\",\"scopes\":[\"${3}\"],\"policies\":[\"${4}\"]}" "${5}"
}
export -f keycloakCreatePermissionScopeBased

function keycloakInitPermission() {
    printDebug 'keycloakInitPermission()'
    keycloakInitToken
    
    local clientUUID=$(curl https://keycloak.${BASE_DOMAIN}/auth/admin/realms/kathra/clients -H "Content-Type: application/json" -H "Authorization: bearer $keycloakAdminToken" 2> /dev/null | jq -c '.[] | select(.clientId=="kathra-resource-manager")' | jq -r -c '.id')
    keycloakCreatePolicy "${clientUUID}" $tmp/keycloak.policy.uuid
    local policyUUID=$(cat $tmp/keycloak.policy.uuid | tr -d '\n')
    local keycloakDbPodId=$(kubectl -n $helmFactoryKathraNS get pods -l=kubedb.com/name=keycloak-postgres-kubedb -o json | jq -r -c '.items[0] | .metadata.name')
    kubectl -n $helmFactoryKathraNS exec -it ${keycloakDbPodId} -- bash -c "echo \"update resource_server set allow_rs_remote_mgmt=true where id = '${clientUUID}';\" | psql -U postgres" 2> /dev/null > /dev/null 
    [ $? -ne 0 ] && printError "Unable to Allow Remote Resource Management into Keycloak" && exit 1
    
    keycloakCreateScope "kathra:scope:component:delete" "${clientUUID}" $tmp/keycloak.scope.component.delete.uuid
	keycloakCreateScope "kathra:scope:component:read" "${clientUUID}" $tmp/keycloak.scope.component.read.uuid
	keycloakCreateScope "kathra:scope:component:update" "${clientUUID}" $tmp/keycloak.scope.component.update.uuid
	keycloakCreateScope "kathra:scope:implementation:delete" "${clientUUID}" $tmp/keycloak.scope.implementation.delete.uuid
	keycloakCreateScope "kathra:scope:implementation:read" "${clientUUID}" $tmp/keycloak.scope.implementation.read.uuid
	keycloakCreateScope "kathra:scope:implementation:update" "${clientUUID}" $tmp/keycloak.scope.implementation.update.uuid
    
    keycloakCreatePermissionScopeBased "Only users from shared group can read components" "${clientUUID}" "$(cat $tmp/keycloak.scope.component.read.uuid | tr -d '\n')" "${policyUUID}" $tmp/keycloak.permission.component.read.uuid
    keycloakCreatePermissionScopeBased "Only users from shared group can update components" "${clientUUID}" "$(cat $tmp/keycloak.scope.component.update.uuid | tr -d '\n')" "${policyUUID}" $tmp/keycloak.permission.component.update.uuid
    keycloakCreatePermissionScopeBased "Only users from shared group can read implementations" "${clientUUID}" "$(cat $tmp/keycloak.scope.implementation.read.uuid | tr -d '\n')" "${policyUUID}" $tmp/keycloak.permission.implementation.read.uuid
    keycloakCreatePermissionScopeBased "Only users from shared group can update implementations" "${clientUUID}" "$(cat $tmp/keycloak.scope.implementation.update.uuid | tr -d '\n')" "${policyUUID}" $tmp/keycloak.permission.implementation.update.uuid
    
    keycloakServiceAccountsAssignRole "kathra-user-manager" "realm-management" "query-clients"
    keycloakServiceAccountsAssignRole "kathra-user-manager" "realm-management" "query-groups"
    keycloakServiceAccountsAssignRole "kathra-user-manager" "realm-management" "query-realms"
    keycloakServiceAccountsAssignRole "kathra-user-manager" "realm-management" "query-users"
    keycloakServiceAccountsAssignRole "kathra-user-manager" "realm-management" "view-realm"
    keycloakServiceAccountsAssignRole "kathra-user-manager" "realm-management" "view-users" 
    return 0
}
export -f keycloakInitPermission

###
### Generate API Token for Jenkins
###
function jenkinsGenerateApiToken() {
    local login=$1
    local password=$2
    local fileOut=$3
    printDebug "jenkinsGenerateApiToken(login: $login, password: $password, fileOut: $fileOut)"

    local attempt_counter=0
    local max_attempts=100
    
    checkCommandAndRetry "curl -v https://jenkins.${BASE_DOMAIN}/me/configure 2>&1 | grep \"HTTP.* 403\" > /dev/null"
    [ $? -ne 0 ] && printError "https://jenkins.${BASE_DOMAIN} is not ready" && exit 1
    
    curl -v https://jenkins.${BASE_DOMAIN}/me/configure  2> $tmp/jenkins.configure.me.err > $tmp/jenkins.configure.me
    local JSESSIONID=$(getHttpHeaderSetCookie $tmp/jenkins.configure.me.err JSESSIONID)

    curl -v -H "Cookie: $JSESSIONID" -L https://jenkins.${BASE_DOMAIN}/securityRealm/commenceLogin?from=%2Fme%2Fconfigure 2> $tmp/jenkins.commence.login.err > $tmp/jenkins.commence.login

    local uriLogin=$(grep "action=" < $tmp/jenkins.commence.login  | sed "s/.* action=\"\([^\"]*\)\".*/\1/" | sed 's/amp;//gi' | tr -d '\r\n')
    local AUTH_SESSION_ID=$(getHttpHeaderSetCookie $tmp/jenkins.commence.login.err AUTH_SESSION_ID)
    local KC_RESTART=$(getHttpHeaderSetCookie $tmp/jenkins.commence.login.err KC_RESTART)
    local location=$(getHttpHeaderLocation $tmp/jenkins.commence.login.err)

    curl -v -X POST "$uriLogin" -H "authority: keycloak.${BASE_DOMAIN}" -H 'cache-control: max-age=0' -H "origin: https://keycloak.${BASE_DOMAIN}" -H 'upgrade-insecure-requests: 1' -H 'content-type: application/x-www-form-urlencoded' -H "$UA" -H "$headerAccept" -H 'referer: $location' -H 'accept-encoding: gzip, deflate, br' -H "$headerAcceptLang" -H "Cookie:${AUTH_SESSION_ID};${KC_RESTART}" --data "username=${login}&password=${password}" --compressed 2> $tmp/jenkins.authenticate.err > $tmp/jenkins.authenticate

    locationFinishLogin=$(getHttpHeaderLocation $tmp/jenkins.authenticate.err)
    curl -v "${locationFinishLogin}" -H "$UA" -H "$headerAccept" -H "$headerAcceptLang" --compressed -H "Referer: https://keycloak.${BASE_DOMAIN}/" -H "DNT: 1" -H "Connection: keep-alive" -H "Cookie: $JSESSIONID; screenResolution=1920x1200" -H "Upgrade-Insecure-Requests: 1" -H "TE: Trailers" 2> $tmp/jenkins.finishLogin.err > $tmp/jenkins.finishLogin
    
    local JENKINS_CRUMB=$(curl -H "Cookie: $JSESSIONID" https://jenkins.${BASE_DOMAIN}/me/configure 2> /dev/null | grep "crumb.init" | sed 's#.*Jenkins\-Crumb",.*"\(.*\)");.*#\1#g' | tr -d '\r\n')
    
    curl "https://jenkins.${BASE_DOMAIN}/me/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken" -H "$UA" -H "$headerAccept" -H "$headerAcceptLang" --compressed -H "Referer: https://jenkins.${BASE_DOMAIN}/me/configure" -H "X-Requested-With: XMLHttpRequest" -H "X-Prototype-Version: 1.7" -H "Content-type: application/x-www-form-urlencoded; charset=UTF-8" -H "Jenkins-Crumb: $JENKINS_CRUMB" -H "DNT: 1" -H "Connection: keep-alive" -H "Cookie: $JSESSIONID" -H "TE: Trailers" --data "newTokenName=kathra-token" 2> $tmp/jenkins.generateNewToken.err > $tmp/jenkins.generateNewToken

    cat $tmp/jenkins.generateNewToken | jq -r -c '.data.tokenValue' > $fileOut
    [ $? -ne 0 ] && printError "Unable to generate api token jenkins" && exit 1
    return 0
}
export -f jenkinsGenerateApiToken

function getHttpHeaderLocation() {
    printDebug "getHttpHeaderLocation(file: $1)"
    grep -i "< Location" < $1 | sed 's/< Location: //gi' | tr -d '\r\n'
}
export -f getHttpHeaderLocation
function getHttpHeaderSetCookie() {
    printDebug "getHttpHeaderSetCookie(file: $1, cookie: $2)"
    grep -i "< Set-Cookie" < $1 | grep -i "$2" | sed 's/< Set-Cookie://gi' | sed 's/;.*//g' | tr '\r\n' ';'
}
export -f getHttpHeaderSetCookie

function checkCommandAndRetry() {
    local retrySecondInterval=5
    local attempt_counter=0
    local max_attempts=150
    while true; do
        eval "${1}" && return 0 
        [ ${attempt_counter} -eq ${max_attempts} ] && printError "Check $1, error" && return 1
        attempt_counter=$(($attempt_counter+1))
        printDebug "Check : $1, attempt ($attempt_counter/$max_attempts), retry in $retrySecondInterval sec."
        sleep $retrySecondInterval
    done
    return 0
}
export -f checkCommandAndRetry

###
### Generate API Token for GitLab having all authorization
###
function gitlabGenerateApiToken() {
    local login=$1
    local password=$2
    local fileOut=$3
    printDebug "gitlabGenerateApiToken(login: $login, password: $password, fileOut: $fileOut)"
    local attempt_counter=0
    local max_attempts=5
    while true; do

        curl -v https://gitlab.${BASE_DOMAIN}/sign_in  2> $tmp/gitlab.sign_in.err > $tmp/gitlab.sign_in.err
        local GA=$(getHttpHeaderSetCookie $tmp/gitlab.sign_in.err "_ga")
        local GA_SESSION=$(getHttpHeaderSetCookie $tmp/gitlab.sign_in.err "_gitlab_session")
        local locationAuth=$(getHttpHeaderLocation $tmp/gitlab.sign_in.err )

        curl -v -H "Cookie: $GA $GA_SESSION" ${locationAuth} 2> $tmp/gitlab.auth.err > $tmp/gitlab.auth
        local locationKathra=$(getHttpHeaderLocation $tmp/gitlab.auth.err)
        curl -v -H "Cookie: $GA $GA_SESSION" ${locationKathra} 2> $tmp/gitlab.auth.kathra.err > $tmp/gitlab.kathra.auth
        local locationKC=$(getHttpHeaderLocation $tmp/gitlab.auth.kathra.err )

        curl -v ${locationKC} 2> $tmp/gitlab.kc.err > $tmp/gitlab.kc
        local uriLogin=$(grep "action=" < $tmp/gitlab.kc  | sed "s/.* action=\"\([^\"]*\)\".*/\1/" | sed 's/amp;//g' | tr -d '\r\n')
        local AUTH_SESSION_ID=$(getHttpHeaderSetCookie $tmp/gitlab.kc.err AUTH_SESSION_ID)
        local KC_RESTART=$(getHttpHeaderSetCookie $tmp/gitlab.kc.err KC_RESTART)
        local location=$(getHttpHeaderLocation $tmp/gitlab.kc.err)

        curl -v "$uriLogin" -H 'authority: keycloak.${BASE_DOMAIN}' -H 'cache-control: max-age=0' -H "origin: https://keycloak.${BASE_DOMAIN}" -H 'upgrade-insecure-requests: 1' -H 'content-type: application/x-www-form-urlencoded' -H "$UA" -H "$headerAccept" -H "referer: $location" -H 'accept-encoding: gzip, deflate, br' -H "$headerAcceptLang" -H "Cookie:$AUTH_SESSION_ID;$KC_RESTART" --data-urlencode "username=${login}"  --data-urlencode "password=${password}" --compressed 2> $tmp/gitlab.kc.post.err > $tmp/gitlab.kc.post
        local locationFinishLogin=$(getHttpHeaderLocation $tmp/gitlab.kc.post.err)

        curl -v -H "Cookie: $GA $GA_SESSION" $locationFinishLogin 2> $tmp/gitlab.finishLogin.err > $tmp/gitlab.finishLogin
            
        gitlabDefineAccountAsAdmin ${login}
        local GA_SESSION_FINAL=$(getHttpHeaderSetCookie $tmp/gitlab.finishLogin.err "_gitlab_session")
        curl https://gitlab.${BASE_DOMAIN}/profile -H "Cookie: $GA $GA_SESSION_FINAL" 2> $tmp/gitlab.profile.err  > $tmp/gitlab.profile
        local AUTH_TOKEN=$(grep "name=\"authenticity_token\"" < $tmp/gitlab.profile  | sed "s/.* value=\"\([^\"]*\)\".*/\1/" | sed 's/amp;//g' | tr -d '\n')

        curl -v "https://gitlab.${BASE_DOMAIN}/profile/personal_access_tokens" -H 'authority: gitlab.${BASE_DOMAIN}' -H 'cache-control: max-age=0' -H "origin: https://gitlab.${BASE_DOMAIN}" -H 'upgrade-insecure-requests: 1' -H 'content-type: application/x-www-form-urlencoded' -H "${UA}" -H "${headerAccept}" -H "referer: https://gitlab.${BASE_DOMAIN}/profile/personal_access_tokens" -H 'accept-encoding: gzip, deflate, br' -H "${headerAcceptLang}" -H "Cookie: $GA $GA_SESSION_FINAL" --data-urlencode "utf8=✓" \
        --data-urlencode "authenticity_token=${AUTH_TOKEN}" \
        --data-urlencode "personal_access_token[name]=kathra-token" \
        --data-urlencode "personal_access_token[expires_at]=" \
        --data-urlencode "personal_access_token[scopes][]=api" \
        --data-urlencode "personal_access_token[scopes][]=read_user" \
        --data-urlencode "personal_access_token[scopes][]=sudo" \
        --data-urlencode "personal_access_token[scopes][]=read_repository" 2> $tmp/gitlab.personal_access_tokens.err  > $tmp/gitlab.personal_access_tokens
        curl -v -H "Cookie: $GA $GA_SESSION_FINAL" "https://gitlab.${BASE_DOMAIN}/profile/personal_access_tokens" 2> $tmp/gitlab.personal_access_tokens.created.err  > $tmp/gitlab.personal_access_tokens.created

        grep "id=\"created-personal-access-token\"" < $tmp/gitlab.personal_access_tokens.created  | sed "s/.* value=\"\([^\"]*\)\".*/\1/" | sed 's/amp;//g' | tr -d '\n' > $fileOut
        [ ! "$(cat $fileOut)" == "" ] && break
        [ ${attempt_counter} -eq ${max_attempts} ] && printError "Unable to generated ApiToken into GitLab after ${max_attempts} attempts" && exit 1
        attempt_counter=$(($attempt_counter+1))
        printDebug "Unable to generated ApiToken into GitLab [ ${attempt_counter}/${max_attempts} ]"
    done
    return 0
}
export -f gitlabGenerateApiToken

###
### Define GitLab Account as Admin
###
function gitlabDefineAccountAsAdmin() {
    printDebug "gitlabDefineAccountAsAdmin(accountName: $1)"
    local podIdentifier=$(kubectl -n $helmFactoryKathraNS get pods -l=project=gitlab -o json | jq -r -c '.items[0] | .metadata.name')
    kubectl -n $helmFactoryKathraNS exec -it ${podIdentifier} -- bash -c "echo \"update users set admin=true where username like '${1}';\" | gitlab-psql" 2> /dev/null > /dev/null
    return $?
}
export -f gitlabDefineAccountAsAdmin

###
### Init admin gitlab password after install
###
function gitlabResetAdminPwd() {
    local pwd=$1
    printDebug "gitlabResetAdminPwd(pwd: $pwd)"
    
    checkCommandAndRetry "curl --fail https://gitlab.${BASE_DOMAIN} > /dev/null 2> /dev/null "
    [ $? -ne 0 ] && printError "https://gitlab.${BASE_DOMAIN} is not ready." && exit 1

    curl -v https://gitlab.${BASE_DOMAIN}/users/sign_in 2> $tmp/gitlab.init.err > $tmp/gitlab.init

    local location=$(getHttpHeaderLocation $tmp/gitlab.init.err)
    local GA_SESSION=$(getHttpHeaderSetCookie $tmp/gitlab.init.err "_gitlab_session")
    curl -v -H "Cookie: $GA $GA_SESSION_FINAL" "${location}" 2> $tmp/gitlab.reset.err > $tmp/gitlab.reset
    local AUTH_TOKEN=$(grep "name=\"authenticity_token\"" < $tmp/gitlab.reset | sed "s/.* value=\"\([^\"]*\)\".*/\1/" | sed 's/amp;//gi' | tr -d '\n')
    local RESET_PWD_TOKEN=$(grep "id=\"user_reset_password_token\"" < $tmp/gitlab.reset | sed "s/.* value=\"\([^\"]*\)\".*/\1/" | sed 's/amp;//gi' | tr -d '\n')
    local GA_SESSION_FINAL=$(getHttpHeaderSetCookie $tmp/gitlab.reset.err "_gitlab_session")
    
    curl -v -X POST "https://gitlab.${BASE_DOMAIN}/users/password" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:67.0) Gecko/20100101 Firefox/67.0" -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" -H "Accept-Language: fr,fr-FR;q=0.8,en-US;q=0.5,en;q=0.3" --compressed -H "Referer: $location" -H "Content-Type: application/x-www-form-urlencoded" -H "Connection: keep-alive" -H "Cookie: $GA $GA_SESSION_FINAL" -H "Upgrade-Insecure-Requests: 1" --data-urlencode "utf8=✓" \
    --data-urlencode "_method=put" \
    --data-urlencode "authenticity_token=${AUTH_TOKEN}" \
    --data-urlencode "user[password]=${pwd}" \
    --data-urlencode "user[password_confirmation]=${pwd}" \
    --data-urlencode "user[reset_password_token]=${RESET_PWD_TOKEN}" 2> $tmp/gitlab.reset-pwd.err  > $tmp/gitlab.reset-pwd
    [ $? -ne 0 ] && printError "Unable to reset password gitlab" && exit 1
    printDebug "GitLab's admin has redefined password"
    return 0
}
export -f gitlabResetAdminPwd

function gitlabImportPublicSshKey() {
    local userId=$1
    local apiToken=$2
    local publicKeyFile=$3
    printDebug "gitlabImportPublicSshKey(userId: $userId, apiToken: $apiToken, publicKeyFile: $publicKeyFile)"
    curl --fail -s -X POST --header "PRIVATE-TOKEN: ${apiToken}" --data-urlencode "key=$(cat $publicKeyFile)" --data-urlencode "title=kathra-autoimport-key" "https://gitlab.${BASE_DOMAIN}/api/v4/user/keys" 2> /dev/null > /dev/null
    [ $? -ne 0 ] && printError "Unable to push public ssh key into gitlab" && exit 1
    printDebug "PublicKey $publicKeyFile is pushed into GitLab for user $userId"
}
export -f gitlabImportPublicSshKey

function harborDefineAccountAsAdmin() {
    local userLogin=$1
    local userPassword=$2
    local adminLogin=$3
    local adminPassword=$4

    checkCommandAndRetry "curl -v https://harbor.${BASE_DOMAIN} 2>&1 | grep \"HTTP.* 200\" > /dev/null"
    [ $? -ne 0 ] && printError "https://harbor.${BASE_DOMAIN} is not ready" && exit 1
    

    printDebug "harborDefineAccountAsAdmin(userLogin: $userLogin, userPassword: $userPassword, adminLogin: $adminLogin, adminPassword: $adminPassword)"
    harborInitFirstConnexion $userLogin $userPassword || return 1
    
    curl --fail -u $adminLogin:$adminPassword  -H "content-type: application/json" "https://harbor.${BASE_DOMAIN}/api/users" 2> /dev/null | jq -r ".[] | select(.username==\"$userLogin\") | .user_id" > $tmp.harborDefineAccountAsAdmin.$userLogin.userId
    [ $? -ne 0 ] && printError "Unable to find harbor users" && return 1
    [ "$(cat $tmp.harborDefineAccountAsAdmin.$userLogin.userId)" == "" ] && printError "Unable to find harbor user with username $userLogin" && return 1
    
    local userId=$(cat $tmp.harborDefineAccountAsAdmin.$userLogin.userId)

    curl --fail -X PUT -u $adminLogin:$adminPassword  -H "content-type: application/json" "https://harbor.${BASE_DOMAIN}/api/users/$userId/sysadmin" -d '{"has_admin_role": true}'
    [ $? -ne 0 ] && printError "Unable te define user '$userLogin' as harbor admin" && return 1
    printDebug 'User '$userLogin' is harbor admin'

}
export -f harborDefineAccountAsAdmin


function harborInitFirstConnexion() {
    printDebug "harborDefineAccountAsAdmin(userLogin: $1, userPassword: $2)"
    local userLogin=$1
    local userPassword=$2

    curl -v https://harbor.${BASE_DOMAIN}/c/oidc/login  2> $tmp/harbor.login.err > $tmp/harbor.login
    local location=$(getHttpHeaderLocation $tmp/harbor.login.err)
    local cookieSID=$(getHttpHeaderSetCookie $tmp/harbor.login.err ".*")
    
    curl -v "$location" -H 'authority: keycloak.${BASE_DOMAIN}' -H 'upgrade-insecure-requests: 1' -H "$UA" -H 'sec-fetch-mode: navigate' -H 'sec-fetch-site: none' -H "$headerAcceptLang" > $tmp/harbor.authenticate 2> $tmp/harbor.authenticate.err
    
    local uriLogin=$(grep "action=" < $tmp/harbor.authenticate  | sed "s/.* action=\"\([^\"]*\)\".*/\1/" | sed 's/amp;//g' | tr -d '\r\n')
    local AUTH_SESSION_ID=$(getHttpHeaderSetCookie $tmp/harbor.authenticate.err AUTH_SESSION_ID)
    local KC_RESTART=$(getHttpHeaderSetCookie $tmp/harbor.authenticate.err KC_RESTART)
    local location=$(getHttpHeaderLocation $tmp/harbor.authenticate.err )

    curl -v "$uriLogin" -H 'authority: keycloak.${BASE_DOMAIN}' -H 'cache-control: max-age=0' -H "origin: https://keycloak.${BASE_DOMAIN}" -H 'upgrade-insecure-requests: 1' -H 'content-type: application/x-www-form-urlencoded' -H "$UA" -H "$headerAccept" -H "referer: $location" -H "$headerAcceptLang" -H "Cookie:$AUTH_SESSION_ID;$KC_RESTART" --data-urlencode "username=${userLogin}"  --data-urlencode "password=${userPassword}" --compressed 2> $tmp/harbor.kc.post.err > $tmp/harbor.kc.post
    
    local locationFinishLogin=$(getHttpHeaderLocation $tmp/harbor.kc.post.err )
    
    curl -v "${locationFinishLogin}" -H "$UA" -H "$headerAccept" -H "$headerAcceptLang" --compressed -H "Referer: https://keycloak.${BASE_DOMAIN}/" -H "DNT: 1" -H "Connection: keep-alive" -H "Cookie: $cookieSID; screenResolution=1920x1200" -H "Upgrade-Insecure-Requests: 1" -H "TE: Trailers" 2> $tmp/harbor.finishLogin.err > $tmp/harbor.finishLogin
    
    grep "HTTP.* 200" < $tmp/harbor.finishLogin.err > /dev/null && printDebug "User '$userLogin' already declared in Harbor" && return 0
    grep -i "Location: \/[[:space:]]*$" < $tmp/harbor.finishLogin.err  > /dev/null && printDebug "User '$userLogin' already declared in Harbor" && return 0
    
    grep -i "Location: \/oidc-onboard.*" < $tmp/harbor.finishLogin.err > /dev/null
    [ $? -ne 0 ] && printError "Client should be redirected to /oidc-onboard.*" && return 1
    
    curl --fail -v "https://harbor.${BASE_DOMAIN}/c/oidc/onboard" -H "$UA" -H "Accept: application/json, text/plain, */*" -H "$headerAcceptLang" --compressed -H "Referer: https://harbor.${BASE_DOMAIN}/oidc-onboard?username=" -H "content-type: application/json" -H "DNT: 1" -H "Connection: keep-alive" -H "Cookie: $cookieSID" -H "TE: Trailers" --data "{\"username\": \"$userLogin\"}" 2> $tmp/harbor.defineUserId.err
    [ $? -ne 0 ] && printError "Unable to connect with user $userLogin on harbor.${BASE_DOMAIN}" && cat $tmp/harbor.defineUserId.err && return 1
    
    return 0
}
export -f harborInitFirstConnexion

function harborInitCliSecret() {
    printDebug "harborInitCliSecret(adminLogin: $1, adminPassword: $2, userLogin: $3, out: $4)"
    local adminLogin=$1
    local adminPassword=$2
    local userLogin=$3
    local out=$4

    curl --fail -u $adminLogin:$adminPassword  -H "content-type: application/json" "https://harbor.${BASE_DOMAIN}/api/users" 2> /dev/null | jq -r ".[] | select(.username==\"$userLogin\") | .user_id" > $tmp.harborInitCliSecret.$userLogin.userId
    [ $? -ne 0 ] && printError "Unable to find harbor users" && return 1
    [ "$(cat $tmp.harborInitCliSecret.$userLogin.userId)" == "" ] && printError "Unable to find harbor user with username $userLogin" && return 1
    
    curl --fail -u $adminLogin:$adminPassword -X POST -H "content-type: application/json" "https://harbor.${BASE_DOMAIN}/api/users/$(cat $tmp.harborInitCliSecret.$userLogin.userId)/gen_cli_secret" 2> /dev/null > $tmp.harborInitCliSecret.$userLogin.post.response
    [ $? -ne 0 ] && printError "Unable to find harbor users" && return 1
    [ "$(jq -r '.secret' < $tmp.harborInitCliSecret.$userLogin.post.response)" == "" ] && printError "Unable to find generate harbor's cli-secret with username $userLogin" && return 1
    jq -r '.secret' < $tmp.harborInitCliSecret.$userLogin.post.response > ${out}
}
export -f harborInitCliSecret

main $@

exit $?
