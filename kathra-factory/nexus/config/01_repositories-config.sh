#!/bin/bash -x
export NEXUS_URL=${NEXUS_URL}
export NEXUS_USER=${ADMIN_USER}
export NEXUS_PWD=${ADMIN_PASSWORD}

function addScriptAndRun() {
    local name=$1
    local scriptFile=$2
    curl -v -X DELETE -u ${NEXUS_USER}:${NEXUS_PWD} ${NEXUS_URL}/service/rest/v1/script/${name}
    curl -v -X POST ${NEXUS_URL}/service/rest/v1/script -u ${NEXUS_USER}:${NEXUS_PWD} -H 'Content-Type: application/json' -d "{ \"name\": \"${name}\",\"content\":\"$(cat $scriptFile | sed ':a;N;$!ba;s/\n/\\n/g')\", \"type\": \"groovy\"}"
    curl -v -u ${NEXUS_USER}:${NEXUS_PWD} -X POST --header 'Content-Type: text/plain' ${NEXUS_URL}/service/rest/v1/script/${name}/run 
    curl -v -X DELETE -u ${NEXUS_USER}:${NEXUS_PWD} ${NEXUS_URL}/service/rest/v1/script/${name} 
}

function change_admin_password() {
    local NEXUS_USER='admin'
    local NEXUS_URL=$1
    local NEXUS_OLD_PWD=$2
    local NEXUS_NEW_PWD=$3
    local name=change_admin_password
    echo "security.securitySystem.changePassword('admin', '${NEXUS_NEW_PWD}')" > /tmp/change_admin_password

    curl -v -X DELETE -u ${NEXUS_USER}:${NEXUS_OLD_PWD} ${NEXUS_URL}/service/rest/v1/script/${name} || return 1 
    curl -v -X POST ${NEXUS_URL}/service/rest/v1/script -u ${NEXUS_USER}:${NEXUS_OLD_PWD} -H 'Content-Type: application/json' -d "{ \"name\": \"${name}\",\"content\":\"$(cat /tmp/change_admin_password | sed ':a;N;$!ba;s/\n/\\n/g')\", \"type\": \"groovy\"}"  || return 1 
    curl -v -u ${NEXUS_USER}:${NEXUS_OLD_PWD} -X POST --header 'Content-Type: text/plain' ${NEXUS_URL}/service/rest/v1/script/${name}/run  || return 1 
    curl -v -X DELETE -u ${NEXUS_USER}:${NEXUS_PWD} ${NEXUS_URL}/service/rest/v1/script/${name}  || return 1 
    return 0
}

declare retrySecondInterval=5
declare attemptCounter=0
declare maxAttempts=100
while true; do
    curl --fail $NEXUS_URL > /dev/null 2> /dev/null && break
    [ $attemptCounter -eq $maxAttempts ] && echo "[ERROR] Wait Nexus is not available" && exit 1
    attemptCounter=$(($attemptCounter+1))
    echo "[INFO] Wait Nexus is available $NEXUS_URL, attempt ($attemptCounter/$maxAttempts)"
    sleep $retrySecondInterval
done

if [ $? -eq 0 ]
then
    change_admin_password "$NEXUS_URL" "admin123" "$NEXUS_PWD" || exit 1

    ## before.. install repo first
    for script in $(find /scripts/ -name *.groovy ); do
        addScriptAndRun $(basename $script) $script;
    done

    exit 0

fi

echo "$NEXUS_URL is not ready, exit.. "
exit 1
