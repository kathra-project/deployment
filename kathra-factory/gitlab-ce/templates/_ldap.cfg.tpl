{{- define "ldap.cfg" -}}
main: 
  verify_certificates: false
  label: 'LDAP'
  host: {{ .Values.ldap.host | squote }}
  port: {{ .Values.ldap.port }}
  uid: {{ .Values.ldap.userUID | squote }}
  method: {{ .Values.ldap.method | squote }}
  bind_dn: {{ .Values.ldap.bindDn | squote }}
  password: 'dummy'
  active_directory: true
  allow_username_or_email_login: false
  block_auto_created_users: false
  base: {{ .Values.ldap.baseDn | squote }}
  user_filter: ''
  attributes:
    username: [{{ .Values.ldap.userUID | squote }}]
    email:    ['mail']
    name:       'cn'
    first_name: 'givenName'
    last_name:  'sn'
{{- end -}}