{{- define "sshconfig" -}}
Host {{ .Values.configuration.sshConfig.sourceHost }}
  Hostname {{ .Values.configuration.sshConfig.sourceHostname }}
  StrictHostKeyChecking false
  User {{ .Values.configuration.sshConfig.sourceUser }}
  Port {{ .Values.configuration.sshConfig.sourcePort }}
{{- end -}}