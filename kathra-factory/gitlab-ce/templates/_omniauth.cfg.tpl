{{- define "omniauth.cfg" -}}
{
  'name' => {{ .Values.oidc.omniauthAutoSignInWithProvider | squote }},
  'app_id' => {{ .Values.oidc.clientName | squote }},
  'app_secret' => {{ .Values.oidc.clientSecret | squote }},
  'args' => {
    client_options: {
      'site' => {{ .Values.oidc.providerUrl | squote }}, # including port if necessary
      'authorize_url' => {{ .Values.oidc.authorizeUrl | squote }},
      'user_info_url' => {{ .Values.oidc.userInfoUrl | squote }},
      'token_url' => {{ .Values.oidc.tokenUrl | squote }}
    },
    user_response_structure: {
      #root_path: ['user'], # i.e. if attributes are returned in JsonAPI format (in a 'user' node nested under a 'data' node)
      attributes: { email:'email', first_name:'given_name', last_name:'family_name', name:'name', nickname:'preferred_username' }, # if the nickname attribute of a user is called 'username'
      id_path: 'preferred_username'
    },
    redirect_url: {{ .Values.oidc.redirectUrl | squote }},
    # optionally, you can add the following two lines to "white label" the display name
    # of this strategy (appears in urls and Gitlab login buttons)
    # If you do this, you must also replace oauth2_generic, everywhere it appears above, with the new name. 
    name: {{ .Values.oidc.omniauthAutoSignInWithProvider | squote }}, # display name for this strategy
    strategy_class: {{ .Values.oidc.omniauthStrategyClass | quote }} # Devise-specific config option Gitlab uses to find renamed strategy
  }
}
{{- end -}}