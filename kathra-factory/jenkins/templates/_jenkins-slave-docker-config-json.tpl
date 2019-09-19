{{- define "docker-config.json" -}}
{
    "auths": {
        {{ .Values.configuration.globalProperties.envVars.KATHRA_DOCKER_URL | quote }}: {
            "auth": {{ .Values.configuration.globalProperties.envVars.KATHRA_DOCKER_AUTH | b64enc | quote }}
        },
        {{ .Values.configuration.globalProperties.envVars.DOCKER_URL | quote }}: {
                "auth": {{ .Values.configuration.globalProperties.envVars.DOCKER_AUTH | b64enc | quote }}
        }
    }
}
{{- end -}}