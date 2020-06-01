#!/bin/bash

###
### Create keycloak user
###
function keycloakCreateUser() {
    printDebug "keycloakCreateUser(username: $1, password: $2, email: $3, groupUUID: $4, uuidFile: $5)"
    curl -v -X POST https://keycloak.${BASE_DOMAIN}/auth/admin/realms/kathra/users -H "Content-Type: application/json" -H "Authorization: bearer $keycloakAdminToken"   --data "{\"username\":\"${1}\", \"enabled\":\"true\", \"emailVerified\":\"true\",\"email\":\"${3}\", \"credentials\": [{\"type\": \"password\",\"value\": \"${2}\", \"temporary\": \"false\"}]}" 2>&1 | grep -i "< Location:" | sed 's/^.*\/users\/\(.*\)$/\1/' > $5
    [ $? -ne 0 ] && printError "Unable to create user '$1' into keycloak" && exit 1
    [ "${4}" == "" ] && return 0
    curl -X PUT https://keycloak.${BASE_DOMAIN}/auth/admin/realms/kathra/users/$(cat $5 | tr -d '\r')/groups/${4} -H "Authorization: bearer $keycloakAdminToken"
    [ $? -ne 0 ] && printError "Unable to add user '$1' into keycloak's group '$4'" && exit 1
    return 0
}
export -f keycloakCreateUser
###
### Create Keycloak group
###
function keycloakCreateGroup() {
    printDebug "keycloakCreateGroup(groupName: $1, uuidFile: $2, groupParentUUID: $3 )"
    [ "${3}" == "" ] && path="/auth/admin/realms/kathra/groups" || path="/auth/admin/realms/kathra/groups/${3}/children"
    curl -v -X POST https://keycloak.${BASE_DOMAIN}${path} -H "Content-Type: application/json" -H "Authorization: bearer $keycloakAdminToken" --data "{\"name\":\"$1\"}" 2>&1 | grep -i "< Location:" | sed 's/^.*\/groups\/\(.*\)$/\1/' > $2
    [ $? -ne 0 ] && printError "Unable to create group '$1' into keycloak" && exit 1
    return 0
}
export -f keycloakCreateGroup
###
### Get Keycloak Token
###
function keycloakInitToken() {
    printDebug "keycloakInitToken()"
    local RESULT=`curl --data "username=${KEYCLOAK_ADMIN_LOGIN}&password=${KEYCLOAK_ADMIN_PASSWORD}&grant_type=password&client_id=admin-cli" "https://keycloak.${BASE_DOMAIN}/auth/realms/master/protocol/openid-connect/token" 2> /dev/null ` && keycloakAdminToken=`echo $RESULT | sed 's/.*access_token":"//g' | sed 's/".*//g'` && return 0
    return 1
}
export -f keycloakInitToken
###
### Push keycloak policy
###
function keycloakCreatePolicy() {
    printDebug "keycloakCreatePolicy(clientUuid: $1, uuidFile: $2)"
    local policy="{\"type\":\"js\",\"logic\":\"POSITIVE\",\"decisionStrategy\":\"UNANIMOUS\",\"name\":\"Only users from shared group policy\",\"description\":\"Only users from shared group policy\",\"code\":\"var context = \$evaluation.getContext(); \n var permission = \$evaluation.getPermission(); \n var identity = context.getIdentity(); \n var resource = permission.getResource(); \n  \n var identityAttr = identity.getAttributes().toMap(); \n var groups = identityAttr.get('groups'); \n  \n // Prefixing owner-group path with leading /, to match Keycloak groups mapping ['/group1', '/group2'] \n var ownerGroup = '/' + resource.getSingleAttribute('owner-group'); \n if (resource.getSingleAttribute('owner-group') != null && resource.getSingleAttribute('owner-group').startsWith('/')){ \n     ownerGroup = resource.getSingleAttribute('owner-group'); \n } \n var groupId = '/' + resource.getSingleAttribute('groupId'); \n if (resource.getSingleAttribute('groupId') != null && resource.getSingleAttribute('groupId').startsWith('/')){ \n     groupId = resource.getSingleAttribute('groupId'); \n } \n var groupPath = '/' + resource.getSingleAttribute('groupPath'); \n if (resource.getSingleAttribute('groupPath') != null && resource.getSingleAttribute('groupPath').startsWith('/')){ \n     groupPath = resource.getSingleAttribute('groupPath'); \n } \n  \n for(var i=0; i<groups.length; i++){ \n     print('Current User Group: ' + groups[i]); \n     if(ownerGroup == groups[i] || groupId == groups[i] || groupPath == groups[i]){ \n         \$evaluation.grant(); \n     } \n }\"}"
    keycloakPostJson "/auth/admin/realms/kathra/clients/${1}/authz/resource-server/policy/js" "${policy}"  "${2}"
    return $?
}
export -f keycloakCreatePolicy

function keycloakServiceAccountsAssignRole() {
    printDebug "keycloakServiceAccountsAssignRole(clientOrigin: $1, clientRole: $2, roleToAssign: $3)"
    local clientOrigin=$1
    local clientRole=$2
    local roleToAssign=$3
    keycloakGetJson "/auth/admin/realms/kathra/clients" > $tmp/keycloakServiceAccountsAssignRole.clients
    
    jq -c ".[] | select(.clientId==\"${clientOrigin}\")" < $tmp/keycloakServiceAccountsAssignRole.clients | jq -r -c '.id' > $tmp/keycloakServiceAccountsAssignRole.$clientOrigin.uuid
    jq -c ".[] | select(.clientId==\"${clientRole}\")" < $tmp/keycloakServiceAccountsAssignRole.clients | jq -r -c '.id' > $tmp/keycloakServiceAccountsAssignRole.$clientRole.uuid
    
    local clientOriginUUID=$(cat $tmp/keycloakServiceAccountsAssignRole.$clientOrigin.uuid)
    local clientRoleUUID=$(cat $tmp/keycloakServiceAccountsAssignRole.$clientRole.uuid)
    
    keycloakGetJson "/auth/admin/realms/kathra/clients/${clientOriginUUID}/service-account-user" | jq -r -c '.id' > $tmp/keycloakServiceAccountsAssignRole.$clientRole.service-account-user.uuid
    local serviceAccountUUID=$(cat $tmp/keycloakServiceAccountsAssignRole.$clientRole.service-account-user.uuid)
    keycloakGetJson "/auth/admin/realms/kathra/users/${serviceAccountUUID}/role-mappings/clients/${clientRoleUUID}/available" > $tmp/keycloakServiceAccountsAssignRole.${serviceAccountUUID}.role-mappings.${clientRole}.available
    
    jq -c ".[] | select(.name==\"${roleToAssign}\")" < $tmp/keycloakServiceAccountsAssignRole.${serviceAccountUUID}.role-mappings.${clientRole}.available > $tmp/keycloakServiceAccountsAssignRole.${serviceAccountUUID}.role-mappings.${clientRole}.available.${roleToAssign}
    jq -r -c '.id' < $tmp/keycloakServiceAccountsAssignRole.${serviceAccountUUID}.role-mappings.${clientRole}.available.${roleToAssign} > $tmp/keycloakServiceAccountsAssignRole.${serviceAccountUUID}.role-mappings.${clientRole}.available.${roleToAssign}.id
   
    local data="[$(cat $tmp/keycloakServiceAccountsAssignRole.${serviceAccountUUID}.role-mappings.${clientRole}.available.${roleToAssign})]"
    keycloakPostJson "/auth/admin/realms/kathra/users/${serviceAccountUUID}/role-mappings/clients/${clientRoleUUID}" "${data}" $tmp/keycloakServiceAccountsAssignRole.${serviceAccountUUID}.role-mappings.${clientRole}.available.${roleToAssign}.assigned
}
export -f keycloakServiceAccountsAssignRole

function keycloakCreateScope() {
    printDebug "keycloakCreateScope(scopeName: $1, clientUuid: $2, uuidFile: $3)"
    keycloakPostJson "/auth/admin/realms/kathra/clients/${2}/authz/resource-server/scope" "{\"name\":\"${1}\",\"displayName\":\"${1}\",\"iconUri\":\"\"}" "${3}"
}
export -f keycloakCreateScope

function keycloakPostJson() {
    printDebug "keycloakPostJson(path: $1, data: $2, uuidFile: $3)"
    curl --fail -v -X POST https://keycloak.${BASE_DOMAIN}${1} -H "Content-Type: application/json" -H "Authorization: bearer $keycloakAdminToken" --data "${2}" 2> /dev/null | jq -r -c '.id' > $3
    [ $? -ne 0 ] && printError "Unable to configure keycloak : POST https://keycloak.${BASE_DOMAIN}${1} DATA=${2}" && exit 1
}
export -f keycloakPostJson

function keycloakGetJson() {
    printDebug "keycloakGetJson(path: $1)"
    curl --fail -v https://keycloak.${BASE_DOMAIN}${1} -H "Content-Type: application/json" -H "Authorization: bearer $keycloakAdminToken" 2> /dev/null
    [ $? -ne 0 ] && printError "Unable to configure keycloak : GET https://keycloak.${BASE_DOMAIN}${1}" && exit 1
}
export -f keycloakGetJson

function keycloakCreatePermissionScopeBased() {
    printDebug "keycloakCreatePermissionScopeBased(path: $1, clientUuid: $2, scopeUuid: $3,policyUuid: $4,uuidFile: $5)"
    keycloakPostJson "/auth/admin/realms/kathra/clients/${2}/authz/resource-server/permission/scope" "{\"type\":\"scope\",\"logic\":\"POSITIVE\",\"decisionStrategy\":\"UNANIMOUS\",\"name\":\"${1}\",\"scopes\":[\"${3}\"],\"policies\":[\"${4}\"]}" "${5}"
}
export -f keycloakCreatePermissionScopeBased

function keycloakInitPermission() {
    printDebug 'keycloakInitPermission()'
    keycloakInitToken
    
    local clientUUID=$(curl https://keycloak.${BASE_DOMAIN}/auth/admin/realms/kathra/clients -H "Content-Type: application/json" -H "Authorization: bearer $keycloakAdminToken" 2> /dev/null | jq -c '.[] | select(.clientId=="kathra-resource-manager")' | jq -r -c '.id')
    keycloakCreatePolicy "${clientUUID}" $tmp/keycloak.policy.uuid
    local policyUUID=$(cat $tmp/keycloak.policy.uuid | tr -d '\n')
    local keycloakDbPodId=$(kubectl -n $helmFactoryKathraNS get pods -l=kubedb.com/name=keycloak-postgres-kubedb -o json | jq -r -c '.items[0] | .metadata.name')
    kubectl -n $helmFactoryKathraNS exec -it ${keycloakDbPodId} -- bash -c "echo \"update resource_server set allow_rs_remote_mgmt=true where id = '${clientUUID}';\" | psql -U postgres" 2> /dev/null > /dev/null 
    [ $? -ne 0 ] && printError "Unable to Allow Remote Resource Management into Keycloak" && exit 1
    
    keycloakCreateScope "kathra:scope:component:delete" "${clientUUID}" $tmp/keycloak.scope.component.delete.uuid
    keycloakCreateScope "kathra:scope:component:read" "${clientUUID}" $tmp/keycloak.scope.component.read.uuid
    keycloakCreateScope "kathra:scope:component:update" "${clientUUID}" $tmp/keycloak.scope.component.update.uuid
    keycloakCreateScope "kathra:scope:implementation:delete" "${clientUUID}" $tmp/keycloak.scope.implementation.delete.uuid
    keycloakCreateScope "kathra:scope:implementation:read" "${clientUUID}" $tmp/keycloak.scope.implementation.read.uuid
    keycloakCreateScope "kathra:scope:implementation:update" "${clientUUID}" $tmp/keycloak.scope.implementation.update.uuid
    
    keycloakCreatePermissionScopeBased "Only users from shared group can read components" "${clientUUID}" "$(cat $tmp/keycloak.scope.component.read.uuid | tr -d '\n')" "${policyUUID}" $tmp/keycloak.permission.component.read.uuid
    keycloakCreatePermissionScopeBased "Only users from shared group can update components" "${clientUUID}" "$(cat $tmp/keycloak.scope.component.update.uuid | tr -d '\n')" "${policyUUID}" $tmp/keycloak.permission.component.update.uuid
    keycloakCreatePermissionScopeBased "Only users from shared group can read implementations" "${clientUUID}" "$(cat $tmp/keycloak.scope.implementation.read.uuid | tr -d '\n')" "${policyUUID}" $tmp/keycloak.permission.implementation.read.uuid
    keycloakCreatePermissionScopeBased "Only users from shared group can update implementations" "${clientUUID}" "$(cat $tmp/keycloak.scope.implementation.update.uuid | tr -d '\n')" "${policyUUID}" $tmp/keycloak.permission.implementation.update.uuid
    
    keycloakServiceAccountsAssignRole "kathra-user-manager" "realm-management" "query-clients"
    keycloakServiceAccountsAssignRole "kathra-user-manager" "realm-management" "query-groups"
    keycloakServiceAccountsAssignRole "kathra-user-manager" "realm-management" "query-realms"
    keycloakServiceAccountsAssignRole "kathra-user-manager" "realm-management" "query-users"
    keycloakServiceAccountsAssignRole "kathra-user-manager" "realm-management" "view-realm"
    keycloakServiceAccountsAssignRole "kathra-user-manager" "realm-management" "view-users" 
    return 0
}
export -f keycloakInitPermission
