#!/bin/sh

java -cp $(realpath $(dirname `which $0`))/keycloak-admin-cli.jar org.keycloak.client.admin.cli.KcAdmMain $@