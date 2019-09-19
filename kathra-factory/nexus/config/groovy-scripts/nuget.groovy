import org.sonatype.nexus.blobstore.api.BlobStoreManager
import org.sonatype.nexus.repository.maven.LayoutPolicy
import org.sonatype.nexus.repository.storage.WritePolicy
import org.sonatype.nexus.repository.maven.VersionPolicy

def local = repository.createNugetHosted(
  'nuget-hosted',
  BlobStoreManager.DEFAULT_BLOBSTORE_NAME,
  true,
  WritePolicy.ALLOW_ONCE
)

def proxy = repository.createNugetProxy(
  'nuget-org-proxy',
  'https://www.nuget.org/api/v2/',
  BlobStoreManager.DEFAULT_BLOBSTORE_NAME,
  true
)

List<String> args = ['nuget-org-proxy','nuget-hosted'] as String[]
def all = repository.createNugetGroup(
  'nuget-all',
  args,
  BlobStoreManager.DEFAULT_BLOBSTORE_NAME
)

