{{- define "maven-settings.xml" -}}
<settings>
  <!-- sets the local maven repository outside of the ~/.m2 folder for easier mounting of secrets and repo -->
  <localRepository>${user.home}/.mvnrepository</localRepository>
  <mirrors>
    <mirror>
      <id>nexus</id>
      <mirrorOf>external:*</mirrorOf>
      <url>{{ .Values.configuration.globalProperties.envVars.NEXUS_URL }}/repository/maven-all/</url>
    </mirror>
  </mirrors>

  <!-- lets disable the download progress indicator that fills up logs -->
  <interactiveMode>false</interactiveMode>

  <servers>
    <server>
      <id>kathra-nexus</id>
      <username>{{ .Values.configuration.globalProperties.envVars.NEXUS_USERNAME }}</username>
      <password>{{ .Values.configuration.globalProperties.envVars.NEXUS_PASSWORD }}</password>
    </server>
  </servers>

  <profiles>
    <profile>
      <id>nexus</id>
      <repositories>
       <repository>
          <id>kathra-nexus</id>
          <name>Nexus public dev</name>
          <url>{{ .Values.configuration.globalProperties.envVars.NEXUS_URL }}/repository/maven-all/</url>
          <releases>
            <updatePolicy>always</updatePolicy>
            <enabled>true</enabled>
          </releases>
          <snapshots>
            <updatePolicy>always</updatePolicy>
            <enabled>true</enabled>
          </snapshots>
        </repository>
      </repositories>
      <properties>
        <altReleaseDeploymentRepository>kathra-nexus::default::{{ .Values.configuration.globalProperties.envVars.NEXUS_URL }}/repository/maven-releases/</altReleaseDeploymentRepository>
        <altSnapshotDeploymentRepository>kathra-nexus::default::{{ .Values.configuration.globalProperties.envVars.NEXUS_URL }}/repository/maven-snapshots/</altSnapshotDeploymentRepository>
      </properties>
      
      <pluginRepositories>
      </pluginRepositories>

    </profile>
  </profiles>
  <activeProfiles>
    <activeProfile>nexus</activeProfile>
  </activeProfiles>
</settings>
{{- end -}}
