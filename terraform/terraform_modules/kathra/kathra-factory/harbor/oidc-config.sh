#!/bin/bash -x

cat > /tmp/config.json <<EOF
    {
        "auth_mode": "oidc_auth",
        "oidc_name": "Keycloak",
        "oidc_endpoint": "${OIDC_ENDPOINT}",
        "oidc_scope": "${OIDC_SCOPE}",
        "oidc_client_id": "${OIDC_CLIENT_ID}",
        "oidc_groups_claim": "${OIDC_GROUP_CLAIM}",
        "oidc_client_secret":  "${OIDC_CLIENT_SECRET}"
    }
EOF

cat config.json

declare attempt_counter=0
declare max_attempts=100

while true; do
    curl --fail -v -k -u $ADMIN_USER:$ADMIN_PASSWORD -H 'Content-Type: application/json' -X PUT -d @/tmp/config.json "${HARBOR_CONFIGURATIONS_ENDPOINT}"
    [ $? -eq 0 ] && echo "Configuration done! Exiting job..." && exit 0
    attempt_counter=$(($attempt_counter+1))
    [ ${attempt_counter} -eq ${max_attempts} ] && echo "Unable to configure ${HARBOR_CONFIGURATIONS_ENDPOINT}" && exit 1
    sleep 3
done

exit 1
