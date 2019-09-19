{{- define "sshconfig" -}}
Host {{ .Values.configuration.sshConfig.sourceHost }}
  Hostname {{ .Values.configuration.sshConfig.sourceHostname }}
  User {{ .Values.configuration.sshConfig.sourceUser }}
  Port {{ .Values.configuration.sshConfig.sourcePort }}
{{- end -}}