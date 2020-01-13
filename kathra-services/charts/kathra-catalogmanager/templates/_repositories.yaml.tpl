{{- define "repositories_helm.yaml" -}}
- name: stable
  url: https://kubernetes-charts.storage.googleapis.com
- name: appscode
  url: https://charts.appscode.com/stable/
- name: {{ .Values.helm.repoName }}
  url: {{ .Values.helm.url }}
  username: {{ .Values.harbor.username | b64enc }}
  password: {{ .Values.harbor.password | b64enc }}
{{- end -}}