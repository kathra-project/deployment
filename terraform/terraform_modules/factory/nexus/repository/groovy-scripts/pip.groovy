import org.sonatype.nexus.blobstore.api.BlobStoreManager
import org.sonatype.nexus.repository.maven.LayoutPolicy
import org.sonatype.nexus.repository.storage.WritePolicy
import org.sonatype.nexus.repository.maven.VersionPolicy

def remote = repository.createPyPiProxy(
  'pip-remote',
  'https://test.pypi.org',
  BlobStoreManager.DEFAULT_BLOBSTORE_NAME,
  true
)

def local = repository.createPyPiHosted(
  'pip-snapshots',
  BlobStoreManager.DEFAULT_BLOBSTORE_NAME,
  true,
  WritePolicy.ALLOW
)

List<String> args = ['pip-snapshots', 'pip-remote'] as String[]
def all = repository.createPyPiGroup(
  'pip-all',
  args,
  BlobStoreManager.DEFAULT_BLOBSTORE_NAME
)
