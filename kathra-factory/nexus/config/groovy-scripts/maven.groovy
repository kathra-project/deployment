import org.sonatype.nexus.blobstore.api.BlobStoreManager
import org.sonatype.nexus.repository.maven.LayoutPolicy
import org.sonatype.nexus.repository.storage.WritePolicy
import org.sonatype.nexus.repository.maven.VersionPolicy

def snapshots = repository.createMavenProxy(
  'maven-systemx-snapshots',
  'https://nexus.irtsysx.fr/repository/maven-snapshots/',
  BlobStoreManager.DEFAULT_BLOBSTORE_NAME,
  true,
  VersionPolicy.SNAPSHOT
)

def releases = repository.createMavenProxy(
  'maven-systemx-releases',
  'https://nexus.irtsysx.fr/repository/maven-releases/',
  BlobStoreManager.DEFAULT_BLOBSTORE_NAME,
  true,
  VersionPolicy.SNAPSHOT
)

def sonatype = repository.createMavenProxy(
  'sonatype-public',
  'https://oss.sonatype.org/content/repositories/public/',
  BlobStoreManager.DEFAULT_BLOBSTORE_NAME,
  true,
  VersionPolicy.SNAPSHOT
)

List<String> args = ['maven-central','maven-systemx-releases','maven-systemx-snapshots','sonatype-public','maven-releases','maven-snapshots'] as String[]
def all = repository.createMavenGroup(
  'maven-all',
  args,
  BlobStoreManager.DEFAULT_BLOBSTORE_NAME
)
