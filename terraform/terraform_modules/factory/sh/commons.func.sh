#!/bin/bash
[ "$tmp" == "" ] && export tmp=/tmp/kathra.factory.$(date +%s%N)
[ ! -d $tmp ] && mkdir $tmp

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
    [ "$debug" -eq 1 ] && echo -e "\033[94;1m $* \033[0m" 1>&2
}
export -f printDebug


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

export retrySecondInterval=5
export max_attempts=300
function checkCommandAndRetry() {
    local attempt_counter=0
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


function getValueInSecretK8S() {
    local kube_config_file=$1
    local namespace=$2
    local secret_name=$3
    local secret_key=$4
    printDebug "getValueInSecretK8S(kube_config_file: $kube_config_file, namespace: $namespace, secret_name: $secret_name, secret_key: $secret_key)"
    kubectl --kubeconfig=$kube_config_file -n $namespace get secret $secret_name -o json 2> /dev/null | jq -r ".data.\"$secret_key\"" | base64 -d && return 1
}
export -f getValueInSecretK8S

function setValueInSecretK8S() {
    local kube_config_file=$1
    local namespace=$2
    local secret_name=$3
    local secret_key=$4
    local secret_value=$5
    printDebug "setValueInSecretK8S(kube_config_file: $kube_config_file, namespace: $namespace, secret_name: $secret_name, secret_key: $secret_key, secret_value: $secret_value)"
    kubectl --kubeconfig=$kube_config_file -n $namespace get secret $secret_name
    [ $rc -ne 0 ] && kubectl --kubeconfig=$kube_config_file -n $namespace  create secret generic $secret_name --from-literal="$secret_key"="$secret_value" 2> /dev/null && return 0
    kubectl --kubeconfig=$kube_config_file -n $namespace patch secret $secret_name -p="{\"data\":{\"$secret_key\": \"$(echo $secret_value | base64 -w0)\"}}" && return 0 || return 1
}
export -f setValueInSecretK8S

function generateKubeFile() {
    local kube_config="$1"
    local kube_config_file="$2"
    local url=$(echo ${kube_config} | jq -r '.host')
    local user=$(echo ${kube_config} | jq -r '.username')
    local password=$(echo ${kube_config} | jq -r '.password')
    local client_cert=$(echo ${kube_config} | jq -r '.client_certificate')
    local client_cert_key=$(echo ${kube_config} | jq -r '.client_key')
    local cluster_ca=$(echo ${kube_config} | jq -r '.cluster_ca_certificate')
    
    echo "apiVersion: v1
kind: Config
preferences:
  colors: true
current-context: default
contexts:
- context:
    cluster: default
    namespace: default
    user: default
  name: default
clusters:
- cluster:
    server: $url
    certificate-authority-data: "$cluster_ca"
  name: default
users:
- name: default
  user:
    password: "$password"
    username: "$user"
    client-certificate-data: "$client_cert"
    client-key-data: "$client_cert_key"" > $kube_config_file
}
export -f generateKubeFile