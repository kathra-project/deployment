#!/bin/bash
export tmp=/tmp/kathra.gitlab.init_token.$(date +%s%N)
[ ! -d $tmp ] && mkdir $tmp
export SCRIPT_DIR=$(realpath $(dirname `which $0`))
export debug=1

. ${SCRIPT_DIR}/../../sh/commons.func.sh
. ${SCRIPT_DIR}/../../sh/gitlab.func.sh

export retrySecondInterval=2
export max_attempts=10

printDebug "$*"
declare gitlab_host=$1
declare keycloak_host=$2
declare username=$3
declare password=$4
declare kubeconfig=$5
declare namespace=$6
declare release_name=$6
declare secret_name=$7
declare secret_key=$9

eval "$(jq -r '@sh "gitlab_host=\(.gitlab_host) keycloak_host=\(.keycloak_host) kube_config=\(.kube_config) namespace=\(.namespace) release_name=\(.release_name) username=\(.username) password=\(.password) secret_name=\(.secret_name) secret_key=\(.secret_key)"')"

declare kubeconfig_file=$tmp/kubeconfig
generateKubeFile "$kube_config" "$kubeconfig_file"

gitlabGenerateApiToken "$gitlab_host" "$keycloak_host" "$username" "$password" "$tmp/gitlab.api_token" "$kubeconfig_file" "$namespace" "$release_name" "false"
declare rc=$?
[ $rc -eq 1 ] && printError "Error occured when generating Gitlab API Token" && exit 0
[ $rc -eq 0 ] && token=$(cat $tmp/gitlab.api_token) && setValueInSecretK8S $kubeconfig_file $namespace $secret_name $secret_key "$token"
## already existing
if [ $rc -eq 2 ]
then
    printDebug "Verify in k8s factory-token-store "
    token=$(getValueInSecretK8S $kubeconfig_file $namespace $secret_name $secret_key)
    printDebug "Token found factory-token-store : $token"

    if [ "$token" == "" ]
    then
        gitlabGenerateApiToken "$gitlab_host" "$keycloak_host" "$username" "$password" "$tmp/gitlab.api_token" "$kubeconfig_file" "$namespace" "$release_name" "true"
        token=$(cat $tmp/gitlab.api_token)
        printDebug "Token regenerated : $token"
        setValueInSecretK8S $kubeconfig_file $namespace $secret_name $secret_key "$token" > /dev/null
    fi
fi
printDebug "{\"token\":\"$token\"}"
jq -n --arg token "$token" '{"token":$token}'
exit $?