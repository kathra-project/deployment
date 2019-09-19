{{- define "target-docker-config.json" -}}
{
    "auths": {
        {{ .Values.docker.TARGET_DOCKER_URL | quote }}: {
            "auth": {{ .Values.docker.TARGET_DOCKER_AUTH | b64enc | quote }}
        }
    }
}
{{- end -}}