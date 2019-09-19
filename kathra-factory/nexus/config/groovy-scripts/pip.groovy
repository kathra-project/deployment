import org.sonatype.nexus.blobstore.api.BlobStoreManager
import org.sonatype.nexus.repository.maven.LayoutPolicy
import org.sonatype.nexus.repository.storage.WritePolicy
import org.sonatype.nexus.repository.maven.VersionPolicy

def kathra = repository.createPyPiProxy(
  'pip-systemx-snapshots',
  'https://nexus.irtsysx.fr/repository/pip-snapshots/',
  BlobStoreManager.DEFAULT_BLOBSTORE_NAME,
  true
)

def kathra2 = repository.createPyPiProxy(
  'pip-kathra',
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

List<String> args = ['pip-snapshots', 'pip-systemx-snapshots', 'pip-kathra'] as String[]
def all = repository.createPyPiGroup(
  'pip-all',
  args,
  BlobStoreManager.DEFAULT_BLOBSTORE_NAME
)
