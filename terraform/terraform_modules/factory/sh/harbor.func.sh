#!/bin/bash

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
    
    curl -v "$location" -H "authority: keycloak.${BASE_DOMAIN}" -H 'upgrade-insecure-requests: 1' -H "$UA" -H 'sec-fetch-mode: navigate' -H 'sec-fetch-site: none' -H "$headerAcceptLang" > $tmp/harbor.authenticate 2> $tmp/harbor.authenticate.err
    
    local uriLogin=$(grep "action=" < $tmp/harbor.authenticate  | sed "s/.* action=\"\([^\"]*\)\".*/\1/" | sed 's/amp;//g' | tr -d '\r\n')
    local AUTH_SESSION_ID=$(getHttpHeaderSetCookie $tmp/harbor.authenticate.err AUTH_SESSION_ID)
    local KC_RESTART=$(getHttpHeaderSetCookie $tmp/harbor.authenticate.err KC_RESTART)
    local location=$(getHttpHeaderLocation $tmp/harbor.authenticate.err )

    curl -v "$uriLogin" -H "authority: keycloak.${BASE_DOMAIN}" -H 'cache-control: max-age=0' -H "origin: https://keycloak.${BASE_DOMAIN}" -H 'upgrade-insecure-requests: 1' -H 'content-type: application/x-www-form-urlencoded' -H "$UA" -H "$headerAccept" -H "referer: $location" -H "$headerAcceptLang" -H "Cookie:$AUTH_SESSION_ID;$KC_RESTART" --data-urlencode "username=${userLogin}"  --data-urlencode "password=${userPassword}" --compressed 2> $tmp/harbor.kc.post.err > $tmp/harbor.kc.post
    
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