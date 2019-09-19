{{- define "pypirc" -}}
[distutils]
index-servers =
  kathra
  public

[kathra]
repository={{ .Values.configuration.globalProperties.envVars.NEXUS_URL }}/repository/pip-snapshots/
username={{ .Values.configuration.globalProperties.envVars.NEXUS_USERNAME }}
password={{ .Values.configuration.globalProperties.envVars.NEXUS_PASSWORD }}

[public]
repository={{ .Values.configuration.globalProperties.envVars.NEXUS_URL }}/repository/pip-all/
username={{ .Values.configuration.globalProperties.envVars.NEXUS_USERNAME }}
password={{ .Values.configuration.globalProperties.envVars.NEXUS_PASSWORD }}
{{- end -}}