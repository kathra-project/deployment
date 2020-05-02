#!/bin/bash

###
### Generate API Token for GitLab having all authorization
###
function gitlabGenerateApiToken() {
    local login=$1
    local password=$2
    local fileOut=$3
    printDebug "gitlabGenerateApiToken(login: $login, password: $password, fileOut: $fileOut)"
    local attempt_counter=0
    local max_attempts=5
    while true; do

        curl -v https://gitlab.${BASE_DOMAIN}/sign_in  2> $tmp/gitlab.sign_in.err > $tmp/gitlab.sign_in.err
        local GA=$(getHttpHeaderSetCookie $tmp/gitlab.sign_in.err "_ga")
        local GA_SESSION=$(getHttpHeaderSetCookie $tmp/gitlab.sign_in.err "_gitlab_session")
        local locationAuth=$(getHttpHeaderLocation $tmp/gitlab.sign_in.err )

        curl -v -H "Cookie: $GA $GA_SESSION" ${locationAuth} 2> $tmp/gitlab.auth.err > $tmp/gitlab.auth
        local locationKathra=$(getHttpHeaderLocation $tmp/gitlab.auth.err)
        curl -v -H "Cookie: $GA $GA_SESSION" ${locationKathra} 2> $tmp/gitlab.auth.kathra.err > $tmp/gitlab.kathra.auth
        local locationKC=$(getHttpHeaderLocation $tmp/gitlab.auth.kathra.err )

        curl -v ${locationKC} 2> $tmp/gitlab.kc.err > $tmp/gitlab.kc
        local uriLogin=$(grep "action=" < $tmp/gitlab.kc  | sed "s/.* action=\"\([^\"]*\)\".*/\1/" | sed 's/amp;//g' | tr -d '\r\n')
        local AUTH_SESSION_ID=$(getHttpHeaderSetCookie $tmp/gitlab.kc.err AUTH_SESSION_ID)
        local KC_RESTART=$(getHttpHeaderSetCookie $tmp/gitlab.kc.err KC_RESTART)
        local location=$(getHttpHeaderLocation $tmp/gitlab.kc.err)

        curl -v "$uriLogin" -H "authority: keycloak.${BASE_DOMAIN}" -H 'cache-control: max-age=0' -H "origin: https://keycloak.${BASE_DOMAIN}" -H 'upgrade-insecure-requests: 1' -H 'content-type: application/x-www-form-urlencoded' -H "$UA" -H "$headerAccept" -H "referer: $location" -H 'accept-encoding: gzip, deflate, br' -H "$headerAcceptLang" -H "Cookie:$AUTH_SESSION_ID;$KC_RESTART" --data-urlencode "username=${login}"  --data-urlencode "password=${password}" --compressed 2> $tmp/gitlab.kc.post.err > $tmp/gitlab.kc.post
        local locationFinishLogin=$(getHttpHeaderLocation $tmp/gitlab.kc.post.err)

        curl -v -H "Cookie: $GA $GA_SESSION" $locationFinishLogin 2> $tmp/gitlab.finishLogin.err > $tmp/gitlab.finishLogin
            
        gitlabDefineAccountAsAdmin ${login}
        local GA_SESSION_FINAL=$(getHttpHeaderSetCookie $tmp/gitlab.finishLogin.err "_gitlab_session")
        curl https://gitlab.${BASE_DOMAIN}/profile -H "Cookie: $GA $GA_SESSION_FINAL" 2> $tmp/gitlab.profile.err  > $tmp/gitlab.profile
        local AUTH_TOKEN=$(grep "name=\"authenticity_token\"" < $tmp/gitlab.profile  | sed "s/.* value=\"\([^\"]*\)\".*/\1/" | sed 's/amp;//g' | tr -d '\n')

        curl -v "https://gitlab.${BASE_DOMAIN}/profile/personal_access_tokens" -H 'authority: gitlab.${BASE_DOMAIN}' -H 'cache-control: max-age=0' -H "origin: https://gitlab.${BASE_DOMAIN}" -H 'upgrade-insecure-requests: 1' -H 'content-type: application/x-www-form-urlencoded' -H "${UA}" -H "${headerAccept}" -H "referer: https://gitlab.${BASE_DOMAIN}/profile/personal_access_tokens" -H 'accept-encoding: gzip, deflate, br' -H "${headerAcceptLang}" -H "Cookie: $GA $GA_SESSION_FINAL" --data-urlencode "utf8=✓" \
        --data-urlencode "authenticity_token=${AUTH_TOKEN}" \
        --data-urlencode "personal_access_token[name]=kathra-token" \
        --data-urlencode "personal_access_token[expires_at]=" \
        --data-urlencode "personal_access_token[scopes][]=api" \
        --data-urlencode "personal_access_token[scopes][]=read_user" \
        --data-urlencode "personal_access_token[scopes][]=sudo" \
        --data-urlencode "personal_access_token[scopes][]=read_repository" 2> $tmp/gitlab.personal_access_tokens.err  > $tmp/gitlab.personal_access_tokens
        curl -v -H "Cookie: $GA $GA_SESSION_FINAL" "https://gitlab.${BASE_DOMAIN}/profile/personal_access_tokens" 2> $tmp/gitlab.personal_access_tokens.created.err  > $tmp/gitlab.personal_access_tokens.created

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
    printDebug "gitlabDefineAccountAsAdmin(accountName: $1, kubeconfig_file: $2, namespace: $3, release=$4)"
    local podIdentifier=$(kubectl --kubeconfig=$2 -n $3 get pods -l app=postgresql,release=$4 -o json | jq -r -c '.items[0] | .metadata.name')
    kubectl --kubeconfig=$2 -n $3 exec -it ${podIdentifier} -- bash -c "echo \"update users set admin=true where username like '${1}';\" | gitlab-psql" 2> /dev/null > /dev/null
    return $?
}
export -f gitlabDefineAccountAsAdmin


function gitlabImportPublicSshKey() {
    local userId=$1
    local apiToken=$2
    local publicKeyFile=$3
    printDebug "gitlabImportPublicSshKey(userId: $userId, apiToken: $apiToken, publicKeyFile: $publicKeyFile)"
    curl --fail -s -X POST --header "PRIVATE-TOKEN: ${apiToken}" --data-urlencode "key=$(cat $publicKeyFile)" --data-urlencode "title=kathra-autoimport-key" "https://gitlab.${BASE_DOMAIN}/api/v4/user/keys" 2> /dev/null > /dev/null
    [ $? -ne 0 ] && printError "Unable to push public ssh key into gitlab" && exit 1
    printDebug "PublicKey $publicKeyFile is pushed into GitLab for user $userId"
}
export -f gitlabImportPublicSshKey
