{{- define "kathra-docker-config.json" -}}
{
    "auths": {
        {{ .Values.docker.KATHRA_DOCKER_URL | quote }}: {
            "auth": {{ .Values.docker.KATHRA_DOCKER_AUTH | b64enc | quote }}
        }
    }
}
{{- end -}}