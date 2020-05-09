#!/bin/bash -x
export SCRIPT_DIR=$(realpath $(dirname `which $0`))
export debug=1

. ${SCRIPT_DIR}/../../sh/commons.func.sh

function addScriptAndRun() {
    local url=$1
    local username=$2
    local password=$3
    local name=$4
    local scriptFile=$5
    curl -v -X DELETE -u ${username}:${password} ${url}/service/rest/v1/script/${name}
    curl -v -X POST ${url}/service/rest/v1/script -u ${username}:${password} -H 'Content-Type: application/json' -d "{ \"name\": \"${name}\",\"content\":\"$(cat $scriptFile | sed ':a;N;$!ba;s/\n/\\n/g')\", \"type\": \"groovy\"}"
    curl -v -u ${username}:${password} -X POST --header 'Content-Type: text/plain' ${url}/service/rest/v1/script/${name}/run 
    curl -v -X DELETE -u ${username}:${password} ${url}/service/rest/v1/script/${name} 
}

eval "$(jq -r '@sh "nexus_host=\(.nexus_host) kube_config=\(.kube_config) namespace=\(.namespace) username=\(.username) password=\(.password) secret_name=\(.secret_name) secret_key=\(.secret_key)"')"

declare retrySecondInterval=5
declare attemptCounter=0
declare maxAttempts=100
declare nexus_url=https://$nexus_host
declare is_ready="false"
while true; do
    curl --fail $nexus_url > /dev/null 2> /dev/null && is_ready="true" && break
    [ $attemptCounter -eq $maxAttempts ] && echo "[ERROR] Wait Nexus is not available" && break
    attemptCounter=$(($attemptCounter+1))
    printDebug "[INFO] Wait Nexus is available $nexus_url, attempt ($attemptCounter/$maxAttempts)"
    sleep $retrySecondInterval
done

if [ "$is_ready" == "true" ]
then
    for script in $(find ${SCRIPT_DIR}/groovy-scripts/ -name *.groovy ); do
        addScriptAndRun $nexus_url $username $password $(basename $script) $script;
    done
fi

jq -n --arg token "$token" '{"token":$token}'
exit $?