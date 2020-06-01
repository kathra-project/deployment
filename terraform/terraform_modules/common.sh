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


function checkDependencies() {
    printDebug "checkDependencies()"
    which curl > /dev/null          || sudo apt-get install curl -y > /dev/null 2> /dev/null 
    which jq >  /dev/null           || sudo apt-get install jq -y > /dev/null 2> /dev/null 
    which unzip > /dev/null         || sudo apt-get install unzip -y > /dev/null 2> /dev/null 
    which go > /dev/null            || sudo apt-get install golang-go > /dev/null 2> /dev/null 
    which kubectl > /dev/null       || installKubectl
    which terraform > /dev/null     || installTerraform
    
    installTerraformPlugin "keycloak" "1.18.0" "https://github.com/mrparkers/terraform-provider-keycloak.git" "1.18.0"   || printErrorAndExit "Unable to install keycloak terraform plugin"
    installTerraformPlugin "kubectl"  "1.3.5"  "https://github.com/gavinbunney/terraform-provider-kubectl"    "v1.3.5"   || printErrorAndExit "Unable to install kubectl terraform plugin"
    installTerraformPlugin "nexus"    "1.6.2"  "https://github.com/datadrivers/terraform-provider-nexus"      "v1.6.2"   || printErrorAndExit "Unable to install nexus terraform plugin"
}
export -f checkDependencies

function installTerraformPlugin() {
    printDebug "installTerraformPlugin(pluginName: $1, pluginVersion: $2, pluginSourceCommit: $3, pluginSourceCommit: $4)"
    local pluginName=$1
    local pluginVersion=$2
    local pluginSourceRepositoryGit=$3
    local pluginSourceCommit=$4
    local system="linux"
    [ "$OSTYPE" == "win32" ] && system="windows"
    [ "$OSTYPE" == "msys" ]  && system="windows"

    local bin=$SCRIPT_DIR/.terraform/plugins/${system}_amd64/terraform-provider-${pluginName}_v$pluginVersion
    printDebug "$bin"
    [ -f $bin ] && return 0
    [ -d /tmp/terraform-provider-$pluginName ] && rm -rf /tmp/terraform-provider-$pluginName 
    git clone ${pluginSourceRepositoryGit} /tmp/terraform-provider-$pluginName || return 1
    cd /tmp/terraform-provider-$pluginName || return 1
    git checkout $pluginSourceCommit || return 1
    go build -o terraform-provider-$pluginName || return 1
    [ ! -d "$(dirname $bin)" ] && mkdir "$(dirname $bin)"
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
    sudo curl -L -o $tmp/kubectl https://storage.googleapis.com/kubernetes-release/release/v$kubernetesVersion/bin/linux/amd64/kubectl 
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