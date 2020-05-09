import org.sonatype.nexus.blobstore.api.BlobStoreManager
import org.sonatype.nexus.repository.maven.LayoutPolicy
import org.sonatype.nexus.repository.storage.WritePolicy
import org.sonatype.nexus.repository.maven.VersionPolicy


def sonatype = repository.createMavenProxy(
  'sonatype-public',
  'https://oss.sonatype.org/content/repositories/public/',
  BlobStoreManager.DEFAULT_BLOBSTORE_NAME,
  true,
  VersionPolicy.SNAPSHOT
)

List<String> args = ['maven-central','sonatype-public','maven-releases','maven-snapshots'] as String[]
def all = repository.createMavenGroup(
  'maven-all',
  args,
  BlobStoreManager.DEFAULT_BLOBSTORE_NAME
)
