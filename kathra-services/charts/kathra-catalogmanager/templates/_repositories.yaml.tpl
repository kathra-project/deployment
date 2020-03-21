{{- define "repositories_helm.yaml" -}}
- name: stable
  url: https://kubernetes-charts.storage.googleapis.com
- name: appscode
  url: https://charts.appscode.com/stable/
{{- end -}}