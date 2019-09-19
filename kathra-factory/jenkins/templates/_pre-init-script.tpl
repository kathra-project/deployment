{{- define "pre-init-script" -}}
import hudson.model.*
import jenkins.model.*
import hudson.tools.*
import hudson.security.*
import hudson.plugins.*
import hudson.security.SecurityRealm.*
import org.jenkinsci.plugins.oic.*

def instance = Jenkins.getInstance()
String clientId = {{ .Values.configuration.oidc.client | quote }}
String clientSecret = {{ .Values.configuration.oidc.secret | quote }}
String automanualconfigure = "auto"
String wellKnownOpenIDConfigurationUrl = {{ .Values.configuration.oidc.wellKnownConfigUrl | quote }}
String userNameField = "preferred_username"
String emailFieldName = "email"
String groupsFieldName = "groups"
String postLogoutRedirectUrl = {{ .Values.configuration.oidc.redirectUrl | quote }}
String adminGroup = {{ .Values.configuration.matrixAuth.adminGroup | quote }}
String adminUser = {{ .Values.configuration.matrixAuth.adminUser | quote }}

oicrealm = new OicSecurityRealm(clientId, clientSecret, wellKnownOpenIDConfigurationUrl, null, null,
                      null, userNameField, null, null,
                      null, emailFieldName, null, groupsFieldName, false,
                      true, null, postLogoutRedirectUrl, false,
                      null, null, null, automanualconfigure)
instance.setSecurityRealm(oicrealm)

ProjectMatrixAuthorizationStrategy authorizationStrategy = new ProjectMatrixAuthorizationStrategy()
authorizationStrategy.add(hudson.model.Hudson.ADMINISTER,adminGroup)
authorizationStrategy.add(hudson.model.Hudson.ADMINISTER,adminUser)
authorizationStrategy.add(hudson.model.Hudson.READ,"authenticated")
instance.setAuthorizationStrategy(authorizationStrategy);

globalNodeProperties = instance.getGlobalNodeProperties()
envVarsNodePropertyList = globalNodeProperties.getAll(hudson.slaves.EnvironmentVariablesNodeProperty.class)
newEnvVarsNodeProperty = null
envVars = null

if ( envVarsNodePropertyList == null || envVarsNodePropertyList.size() == 0 ) {
  newEnvVarsNodeProperty = new hudson.slaves.EnvironmentVariablesNodeProperty();
  globalNodeProperties.add(newEnvVarsNodeProperty)
  envVars = newEnvVarsNodeProperty.getEnvVars()
} else {
  envVars = envVarsNodePropertyList.get(0).getEnvVars()
}

org.jenkinsci.plugins.scriptsecurity.scripts.ScriptApproval.get().approveSignature('staticMethod org.codehaus.groovy.runtime.DefaultGroovyMethods invokeMethod java.lang.Object java.lang.String java.lang.Object')
org.jenkinsci.plugins.scriptsecurity.scripts.ScriptApproval.get().approveSignature('method groovy.lang.GroovyObject invokeMethod java.lang.String java.lang.Object')

{{- range $key, $val := .Values.configuration.globalProperties.envVars }}
envVars.put("{{ $key | upper }}", "{{ $val }}")
{{ end }}
instance.save()
{{- end -}}

