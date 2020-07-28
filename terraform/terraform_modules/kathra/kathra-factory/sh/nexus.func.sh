#!/bin/bash

function nexusCheckVariableIsDefined(){
    [ -z ${NEXUS_URL} ] && printError "NEXUS_URL undefined" && return 1
    [ -z ${NEXUS_LOGIN} ] && printError "NEXUS_LOGIN undefined" && return 1
    [ -z ${NEXUS_PASSWORD} ] && printError "NEXUS_PASSWORD undefined" && return 1
    return 0
}
export -f nexusCheckVariableIsDefined

function nexusGetRepositories() {
    nexusCheckVariableIsDefined || return 1
    curl -u $NEXUS_LOGIN:$NEXUS_PASSWORD -X GET "${NEXUS_URL}/service/rest/beta/repositories" -H  "accept: application/json" 2> /dev/null
}
export -f nexusGetRepositories

function nexusValidateRepository() {
    local name=$(findInArgs --name "$@")
    local format=$(findInArgs --format "$@")
    local type=$(findInArgs --type "$@")
    local versionPolicy=$(findInArgs --version-policy "$@")
    local writePolicy=$(findInArgs --write-policy "$@")
    local remoteUrl=$(findInArgs --remote-url "$@")

    [ "$name"   == "" ] && printError "Repository's name undefined" && return 1
    [ "$type"   == "" ] && printError "Repository's type undefined" && return 1
    [ "$format" == "" ] && printError "Repository's format undefined" && return 1

    printDebug "nexusCreateRepository(name:$name format:$format type:$type version-policy:$versionPolicy write-policy:$writePolicy)"
    
    nexusGetRepositories | jq ".[] | select(.name==\"$name\")" > "$tmp/nexusValidateRepository.$name.existing.json"

    if [[ $(jq '.' < $tmp/nexusValidateRepository.$name.existing.json) ]]
    then
        if [[ $(jq 'select(.format!=\"$format\")'< "$tmp/nexusValidateRepository.$name.existing.json") ]]
        then
            nexusDeleteRepository "$@"
            nexusRepository --operation="POST" "$@"
        else
            local isValid=true
            jq 'select(.storage.writePolicy!=\"$writePolicy\")'   < "$tmp/nexusValidateRepository.$name.existing.json" && isValid=false
            [ "$type"  == "hosted" ] && jq 'select(.maven.versionPolicy!=\"$versionPolicy\")' < "$tmp/nexusValidateRepository.$name.existing.json" && isValid=false
            [ "$type"  == "proxy" ]  && jq 'select(.proxy.remoteUrl!=\"$remoteUrl\")' < "$tmp/nexusValidateRepository.$name.existing.json" && isValid=false
            
            [ $isValid == "false" ] && nexusRepository --operation="PUT" "$@"
        fi
    else 
        nexusRepository --operation="POST" "$@"
    fi 
}
export -f nexusValidateRepository

function nexusRepository() {
    local operation=$(findInArgs --operation "$@" || echo GET)
    local name=$(findInArgs --name "$@")
    local format=$(findInArgs --format "$@")
    local type=$(findInArgs --type "$@")
    local versionPolicy=$(findInArgs --version-policy "$@")
    local writePolicy=$(findInArgs --write-policy "$@")
    local remoteUrl=$(findInArgs --remote-url "$@")
    local groupMembers=$(findInArgs --group-members "$@")

    [ "$name"   == "" ]      && printError "Repository's name undefined"    && return 1
    [ "$type"   == "" ]      && printError "Repository's type undefined"    && return 1
    [ "$format" == "" ]      && printError "Repository's format undefined"  && return 1
    [ "$type"  == "hosted" ] && [ "$writePolicy" == "" ]  && printError "WritePolicy undefined for hosted repository"       && return 1
    [ "$type"  == "proxy"  ] && [ "$remoteUrl" == "" ]    && printError "RemoteUrl undefined for proxy repository"          && return 1
    [ "$type"  == "group"  ] && [ "$groupMembers" == "" ] && printError "Group's members undefined for proxy repository"    && return 1

    printDebug "nexusCreateRepository(operation:$operation name:$name format:$format type:$type version-policy:$versionPolicy write-policy:$writePolicy)"
    cat  >$tmp/nexus.repository.hosted.json <<EOF
{
  "name": "${name}",
  "online": true,
  "storage": {
    "blobStoreName": "default",
    "strictContentTypeValidation": true,
    "writePolicy": "${writePolicy}"
  },
  "cleanup": {
    "policyNames": ["weekly-cleanup"]
  },
  "maven": {
    "versionPolicy": "${versionPolicy}",
    "layoutPolicy": "STRICT"
  }
}
EOF

    cat  >$tmp/nexus.repository.group.json <<EOF
{
  "name": "${name}",
  "online": true,
  "storage": {
    "blobStoreName": "default",
    "strictContentTypeValidation": true
  },
  "group": {
    "memberNames": [ $(echo ${groupMembers} | sed 's/,/","/g') ]
  }
}
EOF
    cat  >$tmp/nexus.repository.proxy.json <<EOF
{
  "name": "${name}",
  "online": true,
  "storage": {
    "blobStoreName": "default",
    "strictContentTypeValidation": true
  },
  "cleanup": {
    "policyNames": "weekly-cleanup"
  },
  "proxy": {
    "remoteUrl": "${remoteUrl}",
    "contentMaxAge": 1440,
    "metadataMaxAge": 1440
  },
  "negativeCache": {
    "enabled": false,
    "timeToLive": 1440
  },
  "routingRule": "string"
}
EOF
    nexusCheckVariableIsDefined || return 1
    local url="${NEXUS_URL}/service/rest/beta/repositories/$format/$type"
    [ "$operation" == "PUT" ] && url=${url}/$name 

    curl -v -H 'Content-Type: application/json' -X $operation -d @$tmp/nexus.repository.$type.json -u $NEXUS_LOGIN:$NEXUS_PASSWORD $url 
}
export -f nexusRepository

function nexusDeleteRepository() {
    local name=$(findInArgs --name "$@")
    local format=$(findInArgs --format "$@")
    nexusCheckVariableIsDefined || return 1
    curl -H 'Content-Type: application/json' -X DELETE -u $NEXUS_LOGIN:$NEXUS_PASSWORD ${NEXUS_URL}/service/rest/beta/repositories/$name
    [ $? -ne 0 ] && printError "Unable to delete repository $name" && return 1
}
export -f nexusDeleteRepository


eval "$@"

exit $?
