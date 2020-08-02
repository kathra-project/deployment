#!/bin/bash

###
### Generate API Token for GitLab having all authorization
###
function gitlabGenerateApiToken() {
    local gitlab_host=$1
    local keycloak_host=$2
    local login=$3
    local password=$4
    local fileOut=$5
    local kubeconfigFile=$6
    local namespace=$7
    local releaseName=$8
    local renewIfExists=$9
    printDebug "$*"
    printDebug "gitlabGenerateApiToken(gitlab_host: $gitlab_host, keycloak_host:$keycloak_host login: $login, password: $password, fileOut: $fileOut, kubeconfigFile: $kubeconfigFile, namespace: $namespace releaseName: $releaseName)"
    
    checkCommandAndRetry "curl -vvI https://${gitlab_host} 2>&1 | grep \"SSL certificate problem: self signed certificate\" && return 1 || return 0" 
    [ $? -ne 0 ] && printError "https://${gitlab_host} is not ready, TLS is self signed" && exit 1

    local attempt_counter=0
    local max_attempts=5
    while true; do

        curl -v https://${gitlab_host}/users/sign_in  2> $tmp/gitlab.sign_in.err > $tmp/gitlab.sign_in
        local GA=$(getHttpHeaderSetCookie $tmp/gitlab.sign_in.err "_ga")
        local GA_SESSION=$(getHttpHeaderSetCookie $tmp/gitlab.sign_in.err "_gitlab_session")
        local authenticity_token=$(cat $tmp/gitlab.sign_in | grep csrf-token | sed 's/.*content="\(.*\)".*/\1/g' )

        printDebug "authenticity_token: $authenticity_token"
        printDebug "_gitlab_session: $GA_SESSION"
        curl -X POST -H "Content-Type: application/x-www-form-urlencoded" --data-urlencode "_method=post" --data-urlencode "authenticity_token=$authenticity_token" -v -H "Origin: https://gitlab.kathra.az3.boubechtoula.ovh" -H "Origin: https://gitlab.kathra.az3.boubechtoula.ovh/users/sign_in"  -H "Cookie: $GA_SESSION" https://${gitlab_host}/users/auth/openid_connect 2> $tmp/gitlab.openid_connect.err > $tmp/gitlab.openid_connect
        local locationKathra=$(getHttpHeaderLocation $tmp/gitlab.openid_connect.err)
        
        printDebug "GA: $GA"
        printDebug "GA_SESSION: $GA_SESSION"
        printDebug "locationKathra: $locationKathra"
        curl -v -H "Cookie: $GA $GA_SESSION" ${locationKathra} 2> $tmp/gitlab.auth.kathra.err > $tmp/gitlab.auth.kathra
        local locationKC=$(getHttpHeaderLocation $tmp/gitlab.auth.kathra.err )
        local uriLogin=$(grep "action=" < $tmp/gitlab.auth.kathra | sed "s/.* action=\"\([^\"]*\)\".*/\1/" | sed 's/amp;//g' | tr -d '\r\n')
        local AUTH_SESSION_ID=$(getHttpHeaderSetCookie $tmp/gitlab.auth.kathra.err AUTH_SESSION_ID)
        local KC_RESTART=$(getHttpHeaderSetCookie $tmp/gitlab.auth.kathra.err KC_RESTART)
        local location=$(getHttpHeaderLocation $tmp/gitlab.auth.kathra.err)

        printDebug "uriLogin: $uriLogin"
        curl -v "$uriLogin" -H "authority: ${keycloak_host}" -H 'cache-control: max-age=0' -H "origin: https://${keycloak_host}" -H 'upgrade-insecure-requests: 1' -H 'content-type: application/x-www-form-urlencoded' -H "$UA" -H "$headerAccept" -H "referer: $location" -H 'accept-encoding: gzip, deflate, br' -H "$headerAcceptLang" -H "Cookie:$AUTH_SESSION_ID;$KC_RESTART" --data-urlencode "username=${login}"  --data-urlencode "password=${password}" --compressed 2> $tmp/gitlab.kc.post.err > $tmp/gitlab.kc.post
        local locationFinishLogin=$(getHttpHeaderLocation $tmp/gitlab.kc.post.err)

        curl -v -H "Cookie: $GA $GA_SESSION" $locationFinishLogin 2> $tmp/gitlab.finishLogin.err > $tmp/gitlab.finishLogin
            
        gitlabDefineAccountAsAdmin ${login} ${kubeconfigFile} ${namespace} ${releaseName} || printError "Unable to define user ${login} as admin"
        local GA_SESSION_FINAL=$(getHttpHeaderSetCookie $tmp/gitlab.finishLogin.err "_gitlab_session")
        curl https://${gitlab_host}/profile -H "Cookie: $GA $GA_SESSION_FINAL" 2> $tmp/gitlab.profile.err  > $tmp/gitlab.profile
        local AUTH_TOKEN=$(grep "name=\"authenticity_token\"" < $tmp/gitlab.profile  | sed "s/.* value=\"\([^\"]*\)\".*/\1/" | sed 's/amp;//g' | tr -d '\n')

        curl -v "https://${gitlab_host}/profile/personal_access_tokens" -H 'authority: ${gitlab_host}' -H 'cache-control: max-age=0' -H "origin: https://${gitlab_host}" -H 'upgrade-insecure-requests: 1' -H 'content-type: application/x-www-form-urlencoded' -H "${UA}" -H "${headerAccept}" -H "referer: https://${gitlab_host}/profile/personal_access_tokens" -H 'accept-encoding: gzip, deflate, br' -H "${headerAcceptLang}" -H "Cookie: $GA $GA_SESSION_FINAL" --data-urlencode "utf8=✓" \
        --data-urlencode "authenticity_token=${AUTH_TOKEN}" \
        --data-urlencode "personal_access_token[name]=kathra-token" \
        --data-urlencode "personal_access_token[expires_at]=" \
        --data-urlencode "personal_access_token[scopes][]=api" \
        --data-urlencode "personal_access_token[scopes][]=read_user" \
        --data-urlencode "personal_access_token[scopes][]=sudo" \
        --data-urlencode "personal_access_token[scopes][]=read_repository" 2> $tmp/gitlab.personal_access_tokens.err  > $tmp/gitlab.personal_access_tokens
        curl -v -H "Cookie: $GA $GA_SESSION_FINAL" "https://${gitlab_host}/profile/personal_access_tokens" 2> $tmp/gitlab.personal_access_tokens.created.err  > $tmp/gitlab.personal_access_tokens.created

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
    printDebug "gitlabDefineAccountAsAdmin(accountName: $1, kubeconfigFile: $2, namespace: $3, release=$4)"
    local accountName=$1
    local kubeconfigFile=$2
    local namespace=$3
    local release=$4
    local dbUser=postgres
    local dbName=gitlabhq_production
    local dbPasswordB64=$(kubectl --kubeconfig=$kubeconfigFile -n $namespace get secret $release-postgresql-password -o json | jq -r '.data."postgresql-postgres-password"')
    local dbPassword=$(echo $dbPasswordB64 | base64 -d)
    local podIdentifier=$(kubectl --kubeconfig=$kubeconfigFile -n $namespace get pods -l app=postgresql,release=$release -o json | jq -r -c '.items[0] | .metadata.name')
    kubectl --kubeconfig=$kubeconfigFile -n $namespace exec -it ${podIdentifier} -- bash -c "export PGPASSWORD=\"$dbPassword\" ; echo \"update users set admin=true where username like '${accountName}';\" | psql -U $dbUser -d $dbName" 2> /dev/null > $tmp/gitlabDefineAccountAsAdmin.updateDb
    grep "UPDATE 1" < $tmp/gitlabDefineAccountAsAdmin > /dev/null || return 1
    return 0
}
export -f gitlabDefineAccountAsAdmin

rawurlencode() {
  local string="${1}"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in
        [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
     esac
     encoded+="${o}"
  done
  echo "${encoded}"    # You can either set a return variable (FASTER) 
  REPLY="${encoded}"   #+or echo the result (EASIER)... or both... :p
}

function gitlabImportPublicSshKey() {
    local userId=$1
    local apiToken=$2
    local publicKeyFile=$3
    printDebug "gitlabImportPublicSshKey(userId: $userId, apiToken: $apiToken, publicKeyFile: $publicKeyFile)"
    curl --fail -s -X POST --header "PRIVATE-TOKEN: ${apiToken}" --data-urlencode "key=$(cat $publicKeyFile)" --data-urlencode "title=kathra-autoimport-key" "https://${gitlab_host}/api/v4/user/keys" 2> /dev/null > /dev/null
    [ $? -ne 0 ] && printError "Unable to push public ssh key into gitlab" && exit 1
    printDebug "PublicKey $publicKeyFile is pushed into GitLab for user $userId"
}
export -f gitlabImportPublicSshKey
