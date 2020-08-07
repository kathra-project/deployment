#/bin/bash

export terraformVersion="0.12.21"
export kubectlVersion="1.15.4"
export veleroVersion="1.2.0"

function printErrorAndExit(){
    echo -e "\033[31;1m $* \033[0m" 1>&2 && exit 1
}
export -f printErrorAndExit
function printError(){
    echo -e "\033[31;1m $* \033[0m" 1>&2 && return 0
}
export -f printError
function printWarn(){
    echo -e "\033[33;1m $* \033[0m" 1>&2 && return 0
}
export -f printWarn
function printInfo(){
    echo -e "\033[33;1m $* \033[0m" 1>&2 && return 0
}
export -f printInfo
function printDebug(){
    [ "$debug" == "1" ] && echo -e "\033[94;1m $* \033[0m" 1>&2
    return 0
}
export -f printDebug

function findInArgs() {
    local keyToFind=$1
    shift 
    POSITIONAL=()
    while [[ $# -gt 0 ]]
    do
        [ "$(echo "$1" | cut -d'=' -f1)" == "${keyToFind}" ] && echo $(echo "$1" | cut -d'=' -f2) && return 0
        shift
    done
    return 1
}
export -f findInArgs

function checkCommandAndRetry() {
    local retrySecondInterval=5
    local attempt_counter=0
    local max_attempts=100
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

function checkDependencies() {
    printDebug "checkDependencies()"
    local packageInstall="sudo apt-get install"
    [ "$OSTYPE" == "win32" ] && packageInstall="choco install"
    [ "$OSTYPE" == "msys" ]  && packageInstall="choco install"

    which curl > /dev/null          || $packageInstall curl -y > /dev/null 2> /dev/null 
    which jq >  /dev/null           || $packageInstall jq -y > /dev/null 2> /dev/null 
    which unzip > /dev/null         || $packageInstall unzip -y > /dev/null 2> /dev/null 
    which go > /dev/null            || $packageInstall golang-go > /dev/null 2> /dev/null 
    which kubectl > /dev/null       || installKubectl
    which terraform > /dev/null     || installTerraform
    
    installTerraformPlugin "keycloak" "1.19.0" "https://github.com/mrparkers/terraform-provider-keycloak.git" "1.19.0"   || printErrorAndExit "Unable to install keycloak terraform plugin"
    installTerraformPlugin "kubectl"  "1.3.5"  "https://github.com/gavinbunney/terraform-provider-kubectl"    "v1.3.5"   || printErrorAndExit "Unable to install kubectl terraform plugin"
    installTerraformPlugin "nexus"    "1.8.1"  "https://github.com/datadrivers/terraform-provider-nexus"      "v1.8.1"   || printErrorAndExit "Unable to install nexus terraform plugin"
}
export -f checkDependencies

function installTerraformPlugin() {
    printDebug "installTerraformPlugin(pluginName: $1, pluginVersion: $2, pluginSourceCommit: $3, pluginSourceCommit: $4)"
    local pluginName=$1
    local pluginVersion=$2
    local pluginSourceRepositoryGit=$3
    local pluginSourceCommit=$4
    local system="linux"
    local ext=""
    local basePlugin=$SCRIPT_DIR/.terraform/plugins
    [ "$OSTYPE" == "win32" ] && system="windows" && ext=".exe"
    [ "$OSTYPE" == "msys" ]  && system="windows" && ext=".exe"

    local bin=$basePlugin/${system}_amd64/terraform-provider-${pluginName}_v${pluginVersion}${ext}
    printDebug "$bin"
    [ -f $bin ] && return 0
    [ -d /tmp/terraform-provider-$pluginName ] && rm -rf /tmp/terraform-provider-$pluginName 
    git clone ${pluginSourceRepositoryGit} /tmp/terraform-provider-$pluginName || return 1
    cd /tmp/terraform-provider-$pluginName || return 1
    git checkout $pluginSourceCommit || return 1
    go build -o terraform-provider-$pluginName || return 1
    [ ! -d "$(dirname $bin)" ] && mkdir -p "$(dirname $bin)"
    mv terraform-provider-$pluginName $bin || return 1
    cd $SCRIPT_DIR
}

function installVeleroCli() {
    printDebug "installVeleroCli()"
    [ -f $veleroBin ] && return 0
    curl -L https://github.com/vmware-tanzu/velero/releases/download/v$veleroVersion/velero-v$veleroVersion-linux-amd64.tar.gz > $tmp/velero.tar.gz
    [ ! -d $tmp/velero ] && mkdir $tmp/velero
    tar -xvf $tmp/velero.tar.gz -C $tmp/velero
    chmod +x $veleroBin 
}
export -f installVeleroCli


function installKubectl() {
    printDebug "installKubectl()"
    which kubectl > /dev/null 2> /dev/null && return 0
    sudo curl -L -o $tmp/kubectl https://storage.googleapis.com/kubernetes-release/release/v$kubectlVersion/bin/linux/amd64/kubectl 
    sudo chmod +x $tmp/kubectl 
    sudo mv $tmp/kubectl /usr/local/bin/kubectl
}
export -f installKubectl
 
function installTerraform() {
    printDebug "installTerraform()"
    which terraform > /dev/null 2> /dev/null && return 0
    sudo apt-get install unzip
    [ -f /tmp/terraform.zip ] && rm -f /tmp/terraform.zip
    curl https://releases.hashicorp.com/terraform/${terraformVersion}/terraform_${terraformVersion}_linux_amd64.zip > /tmp/terraform.zip
    unzip /tmp/terraform.zip
    sudo mv terraform /usr/local/bin/terraform
}
export -f installTerraform


function postInstall() {
    terraform output -json kathra > $tmp/settings.json
    installKathraCli $tmp/settings.json
    printInfo "Kathra is installed in $((`date +%s`-START_KATHRA_INSTALL)) secondes"
    printInfo "You can use Kathra from dashboard : https://$(cat $tmp/settings.json | jq -r '.services.services.dashboard.host') or from kathra-cli: $KATHRA_CLI_GIT"
    printInfo "All passwords are stored in Terraform (exec: terraform output)" 
    printInfo "User login: $(cat $tmp/settings.json | jq -r '.factory.realm.first_user.username')"
    printInfo "User password: $(cat $tmp/settings.json | jq -r '.factory.realm.first_user.password')"
    printInfo "Keycloak admin login: $(cat $tmp/settings.json | jq -r '.factory.keycloak.username')"
    printInfo "Keycloak admin password: $(cat $tmp/settings.json | jq -r '.factory.keycloak.password')"
}
export -f postInstall

export KATHRA_CLI_GIT="https://gitlab.com/kathra/kathra/kathra-cli.git"
export LOCAL_CONF_FILE_KATHRA_CLI=$HOME/.kathra-context
function installKathraCli() {
    printDebug "installKathraCli(settings_file=$1)"
    autoConfigureKathraCli "$1" "$LOCAL_CONF_FILE_KATHRA_CLI"
    [ ! -d $HOME/kathra-cli ] && git clone https://gitlab.com/kathra/kathra/kathra-cli.git $HOME/kathra-cli
    printInfo "kathra-cli configured : $HOME/kathra-cli"
}
export -f installKathraCli

function autoConfigureKathraCli() {
    printDebug "autoConfigureKathraCli(settings_file=$1, local_file=$2)"
    local settings_file=$1
    local local_file=$2

    writeEntryIntoFile "DOMAIN_HOST"            "$( cat $settings_file | jq -r '.domain')" "${local_file}"
    writeEntryIntoFile "KEYCLOAK_HOST"          "$( cat $settings_file | jq -r '.factory.keycloak.host')" "${local_file}"
    writeEntryIntoFile "APP_MANAGER_HOST"       "$( cat $settings_file | jq -r '.services.services.appmanager.host')" "${local_file}"
    writeEntryIntoFile "RESOURCE_MANAGER_HOST"  "$( cat $settings_file | jq -r '.services.services.resourcemanager.host')" "${local_file}"
    writeEntryIntoFile "PIPELINE_MANAGER_HOST"  "$( cat $settings_file | jq -r '.services.services.pipelinemanager.host')" "${local_file}"
    writeEntryIntoFile "SOURCE_MANAGER_HOST"    "$( cat $settings_file | jq -r '.services.services.sourcemanager.host')" "${local_file}"
    writeEntryIntoFile "JENKINS_HOST"           "$( cat $settings_file | jq -r '.factory.jenkins.host')" "${local_file}"
    writeEntryIntoFile "GITLAB_HOST"            "$( cat $settings_file | jq -r '.factory.gitlab.host')" "${local_file}"
    writeEntryIntoFile "KEYCLOAK_CLIENT_ID"     "$( cat $settings_file | jq -r '.factory.kathra.client_id')" "${local_file}"
    writeEntryIntoFile "KEYCLOAK_CLIENT_SECRET" "$( cat $settings_file | jq -r '.factory.kathra.client_secret')" "${local_file}"
    writeEntryIntoFile "KEYCLOAK_CLIENT_REALM"  "$( cat $settings_file | jq -r '.factory.realm.name')" "${local_file}"
    writeEntryIntoFile "JENKINS_API_USER"       "$( cat $settings_file | jq -r '.factory.kathra_service_account.username')" "${local_file}"
    writeEntryIntoFile "JENKINS_API_TOKEN"      "$( cat $settings_file | jq -r '.factory.kathra_service_account.jenkins_api_token')" "${local_file}"
    writeEntryIntoFile "GITLAB_API_TOKEN"       "$( cat $settings_file | jq -r '.factory.kathra_service_account.gitlab_api_token')" "${local_file}"
    
}
export -f autoConfigureKathraCli


function writeEntryIntoFile(){
    local key=$1
    local value=$2
    local file=$3
    [ ! -f $file ] && echo "{}" > $file
    jq ".$key = \"$value\"" $file > $file.updated && mv $file.updated $file
}
export -f writeEntryIntoFile