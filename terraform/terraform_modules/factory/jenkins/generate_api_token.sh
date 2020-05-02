#!/bin/bash

export SCRIPT_DIR=$(realpath $(dirname `which $0`))
export debug=1

. ${SCRIPT_DIR}/../sh/commons.func.sh
. ${SCRIPT_DIR}/../sh/jenkins.func.sh

export retrySecondInterval=2
export max_attempts=5

printDebug "$*"
declare jenkins_host=$1
declare keycloak_host=$2
declare username=$3
declare password=$4
declare kubeconfig=$5
declare namespace=$6
declare secret_name=$7
declare secret_key=$8

eval "$(jq -r '@sh "jenkins_host=\(.jenkins_host) keycloak_host=\(.keycloak_host) kube_config=\(.kube_config) namespace=\(.namespace) username=\(.username) password=\(.password) secret_name=\(.secret_name) secret_key=\(.secret_key)"')"

declare kubeconfig_file=$tmp/kubeconfig
generateKubeFile "$kube_config" "$kubeconfig_file"

jenkinsGenerateApiToken "$jenkins_host" "$keycloak_host" "$username" "$password" "$tmp/jenkins.api_token" "false"
declare rc=$?
[ $rc -eq 1 ] && printError "Error occured when generating Jenkins API Token" && exit 0

[ $rc -eq 0 ] && token=$(cat $tmp/jenkins.api_token) && setValueInSecretK8S $kubeconfig_file $namespace $secret_name $secret_key "$token" 
## already existing
if [ $rc -eq 2 ]
then
    printDebug "Verify in k8s factory-token-store "
    token=$(getValueInSecretK8S $kubeconfig_file $namespace $secret_name $secret_key)
    printDebug "Token found factory-token-store : $token"

    if [ "$token" == "" ]
    then
        jenkinsGenerateApiToken "$jenkins_host" "$keycloak_host" "$username" "$password" "$tmp/jenkins.api_token" "true"
        token=$(cat $tmp/jenkins.api_token)
        printDebug "Token regenerated : $token"
        setValueInSecretK8S $kubeconfig_file $namespace $secret_name $secret_key "$token" 
    fi
fi

jq -n --arg token "$token" '{"token":$token}'
exit $?