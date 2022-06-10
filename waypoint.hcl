project = "hashiconf-demo"

// Variables
variable "registrycreds_secret" {
  default     = "registrycreds"
  type        = string
  description = "The existing secret name inside Kubernetes for authenticating to the container registry"
}

variable "registry_username" {
  default = dynamic("vault", {
    path = "secret/data/jfrogcreds"
    key = "/data/username"
  })
  type        = string
  sensitive   = true
  description = "username for container registry"
}

variable "registry_password" {
  default = dynamic("vault", {
    path = "secret/data/jfrogcreds"
    key = "/data/password"
  })
  type        = string
  sensitive   = true
  description = "password for registry"
}

variable "mongo_uri" {
  default = dynamic("terraform-cloud", {
    organization = "waypoint-demos"
    workspace    = "hashiconf-demo"
    output       = "dev_mongodb_uri"
  })
  type    = string
  sensitive   = true
  description = "Mongo DB URI to connect"
}

// Variables
variable "registrycreds_secret" {
  default     = "registrycreds"
  type        = string
  description = "The existing secret name inside Kubernetes for authenticating to the container registry"
}

variable "registry_username" {
  default = dynamic("vault", {
    path = "secret/data/jfrogcreds"
    key = "/data/username"
  })
  type        = string
  sensitive   = true
  description = "username for container registry"
}

variable "registry_password" {
  default = dynamic("vault", {
    path = "secret/data/jfrogcreds"
    key = "/data/password"
  })
  type        = string
  sensitive   = true
  description = "password for registry"
}

variable "mongo_uri" {
  default = dynamic("terraform-cloud", {
    organization = "waypoint-demos"
    workspace    = "hashiconf-demo"
    output       = "dev_mongodb_uri"
  })
  type    = string
  sensitive   = true
  description = "Mongo DB URI to connect"
}

app "short-urls" {
  labels = {
    "service" = "shrls",
  }

  config {
    env = {
      MONGO_URI=var.mongo_uri
      SHRLS_PORT=3000
    }
  }

  build {
    // Use Dockerfile to build the application
    use "docker" {}

    // Use JFrog registry to store the artifact/image
    registry {
      use "docker" {
        image = "catsby.jfrog.io/shrl-docker/shrls"
        tag   = "latest"

        username = var.registry_username
        password = var.registry_password
      }
    }
  }

  deploy {
    use "kubernetes" {
      // path for health checks
      probe_path = "/"
      // Kube secret for pulling image from registry
      image_secret = var.registrycreds_secret
    }
  }

  release {
    use "kubernetes" {
      // Sets up a load balancer to access released application
      load_balancer = true
      port          = 8080
    }
  }
}

// On-Demand Runner configuration
runner {
  enabled = true

  data_source "git" {
    url  = "https://github.com/catsby/go-shrls.git"
    ref = "refs/heads/dev"
  }
}
