variable "nexus_url" {
}
variable "username" {
}
variable "password" {
}
variable "vm_depends_on" {
}

provider "nexus" {
    insecure = true
    url      = var.nexus_url
    username = var.username
    password = var.password
}


resource "nexus_repository" "pypi_public" {
    name   = "pypi-remote"
    type   = "proxy"
    format = "pypi"
    online = true
    proxy {
        remote_url       = "https://test.pypi.org"
        content_max_age  = 1440
        metadata_max_age = 1440
    }
    negative_cache {
        enabled = true
        ttl     = 1440
    }
    storage {
        blob_store_name                = "default"
        strict_content_type_validation = true
        write_policy                   = "ALLOW_ONCE"
    }

    http_client {
        authentication {
        }
    }

    depends_on = [var.vm_depends_on]
}

resource "nexus_repository" "maven_sonatype_public" {
    name   = "sonatype-public"
    type   = "proxy"
    format = "maven2"
    online = true

    proxy {
        remote_url          = "https://oss.sonatype.org/content/repositories/public/"
        content_max_age     = 1440
        metadata_max_age    = 1440
    }
    negative_cache {
        enabled = true
        ttl     = 1440
    }
    storage {
        blob_store_name                = "default"
        strict_content_type_validation = true
    }
    maven {
        version_policy = "MIXED"
        layout_policy  = "STRICT"
    }
    http_client {
        authentication {
        }
    }

    depends_on = [var.vm_depends_on]

}

data "nexus_repository" "maven_central" {
    name = "maven-central"
    depends_on = [var.vm_depends_on]
}
data "nexus_repository" "maven_releases" {
    name = "maven-releases"
    depends_on = [var.vm_depends_on]
}
data "nexus_repository" "maven_snapshots" {
    name = "maven-snapshots"
    depends_on = [var.nexus_url]
}

data "nexus_repository" "maven_public" {
    name = "maven-public"
    depends_on = [var.vm_depends_on]
}
resource "nexus_repository" "maven_group_all" {
    name   = "maven-all"
    format = "maven2"
    type   = "group"
    group {
        member_names = [
            data.nexus_repository.maven_central.name,
            data.nexus_repository.maven_releases.name,
            data.nexus_repository.maven_snapshots.name,
            nexus_repository.maven_sonatype_public.name
        ]
    }
    storage {
        blob_store_name                = "default"
        strict_content_type_validation = true
    }
    depends_on = [var.vm_depends_on]
}

resource "nexus_repository" "pypi_hosted" {
    name   = "pip-snapshots"
    format = "pypi"
    type   = "hosted"

    storage {
        blob_store_name                = "default"
        strict_content_type_validation = true
        write_policy                   = "ALLOW"
    }
    depends_on = [var.vm_depends_on]
}

resource "nexus_repository" "pypi_group_all" {
    name   = "pip-all"
    format = "pypi"
    type   = "group"
    online = true
    group {
        member_names = [
            nexus_repository.pypi_public.name,
            nexus_repository.pypi_hosted.name
        ]
    }
    storage {
        blob_store_name                = "default"
        strict_content_type_validation = true
    }
    depends_on = [var.vm_depends_on]
}

output "repositories" {
    value = [
        data.nexus_repository.maven_central,
        data.nexus_repository.maven_releases,
        data.nexus_repository.maven_snapshots,

        //data.nexus_repository.maven_public,
        nexus_repository.maven_group_all,
        //data.nexus_repository.pip_all,

        nexus_repository.pypi_hosted,
        nexus_repository.pypi_group_all
    ]
}
