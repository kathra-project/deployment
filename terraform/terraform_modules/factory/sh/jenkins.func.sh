#!/bin/bash

###
### Generate API Token for Jenkins
###
function jenkinsGenerateApiToken() {
    local jenkinsHost=$1
    local keycloakHost=$2
    local login=$3
    local password=$4
    local fileOut=$5
    local renewIfExist=$6
    local tokenName="token-generated-by-kathra"
    printDebug "jenkinsGenerateApiToken(jenkinsHost: $jenkinsHost, keycloakHost: $keycloakHost, login: $login, password: $password, fileOut: $fileOut, renewIfExist: $renewIfExist)"


    checkCommandAndRetry "curl -v https://${jenkinsHost}/me/configure 2>&1 | grep \"HTTP.* 403\" > /dev/null"
    [ $? -ne 0 ] && printError "https://${jenkinsHost} is not ready" && exit 1

    curl -v https://${jenkinsHost}/me/configure  2> $tmp/jenkins.configure.me.err > $tmp/jenkins.configure.me
    local JSESSIONID=$(getHttpHeaderSetCookie $tmp/jenkins.configure.me.err JSESSIONID)

    curl -v -H "Cookie: $JSESSIONID" -L https://${jenkinsHost}/securityRealm/commenceLogin?from=%2Fme%2Fconfigure 2> $tmp/jenkins.commence.login.err > $tmp/jenkins.commence.login

    local uriLogin=$(grep "action=" < $tmp/jenkins.commence.login  | sed "s/.* action=\"\([^\"]*\)\".*/\1/" | sed 's/amp;//gi' | tr -d '\r\n')
    local AUTH_SESSION_ID=$(getHttpHeaderSetCookie $tmp/jenkins.commence.login.err AUTH_SESSION_ID)
    local KC_RESTART=$(getHttpHeaderSetCookie $tmp/jenkins.commence.login.err KC_RESTART)
    local location=$(getHttpHeaderLocation $tmp/jenkins.commence.login.err)

    curl -v -X POST "$uriLogin" -H "authority: ${keycloakHost}" -H 'cache-control: max-age=0' -H "origin: https://${keycloakHost}" -H 'upgrade-insecure-requests: 1' -H 'content-type: application/x-www-form-urlencoded' -H "$UA" -H "$headerAccept" -H 'referer: $location' -H 'accept-encoding: gzip, deflate, br' -H "$headerAcceptLang" -H "Cookie:${AUTH_SESSION_ID};${KC_RESTART}" --data "username=${login}&password=${password}" --compressed 2> $tmp/jenkins.authenticate.err > $tmp/jenkins.authenticate

    locationFinishLogin=$(getHttpHeaderLocation $tmp/jenkins.authenticate.err)
    curl -v "${locationFinishLogin}" -H "$UA" -H "$headerAccept" -H "$headerAcceptLang" --compressed -H "Referer: https://${keycloakHost}/" -H "DNT: 1" -H "Connection: keep-alive" -H "Cookie: $JSESSIONID; screenResolution=1920x1200" -H "Upgrade-Insecure-Requests: 1" -H "TE: Trailers" 2> $tmp/jenkins.finishLogin.err > $tmp/jenkins.finishLogin

    [ ! "${renewIfExist}" == "true" ] && curl -H "Cookie: $JSESSIONID" https://${jenkinsHost}/me/configure 2> /dev/null | grep "value=\"$tokenName\"" > /dev/null && printDebug "Jenkins token '$tokenName' already exist !" && return 2
    local JENKINS_CRUMB=$(curl -H "Cookie: $JSESSIONID" https://${jenkinsHost}/me/configure 2> /dev/null | grep "crumb.init" | sed 's#.*Jenkins\-Crumb",[[:space:]]*"\([^"]*\).*#\1#g' | tr -d '\r\n')

    
    curl "https://${jenkinsHost}/me/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken" -H "$UA" -H "$headerAccept" -H "$headerAcceptLang" --compressed -H "Referer: https://${jenkinsHost}/me/configure" -H "X-Requested-With: XMLHttpRequest" -H "X-Prototype-Version: 1.7" -H "Content-type: application/x-www-form-urlencoded; charset=UTF-8" -H "Jenkins-Crumb: $JENKINS_CRUMB" -H "DNT: 1" -H "Connection: keep-alive" -H "Cookie: $JSESSIONID" -H "TE: Trailers" --data "newTokenName=$tokenName" 2> $tmp/jenkins.generateNewToken.err > $tmp/jenkins.generateNewToken

    cat $tmp/jenkins.generateNewToken  | jq -r -c '.data.tokenValue' > $fileOut
    [ $? -ne 0 ] && printError "Unable to generate api token jenkins" && exit 1
    return 0
}
export -f jenkinsGenerateApiToken
