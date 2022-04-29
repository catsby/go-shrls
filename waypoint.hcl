project = "shrls"

app "shrls" {
  labels = {
    "service" = "shrls",
    "env"     = "dev"
  }

  config {
    env = {
      MONGO_URI=var.mongo_url
      SHRLS_PORT=var.port
    }
  }

  build {
    # use "pack" {}
    use "docker" {}
    registry {
      use "docker" {
        image = "catsby.jfrog.io/shrl-docker/shrls"
        tag   = "latest"

        username = var.registry_username
        password = var.registry_password
        local = false
      }
    }
  }

  deploy {
    use "kubernetes" {
      probe_path = "/"
      image_secret = var.regcred_secret
    }
  }

  release {
    use "kubernetes" {
      // Sets up a load balancer to access released application
      load_balancer = true
      port          = var.port
    }
  }
}

runner {
  enabled = true

  data_source "git" {
    url  = "https://github.com/catsby/go-shrls.git"
    ref = "refs/heads/dev"
  }
}

variable "regcred_secret" {
  default     = "regcred"
  type        = string
  description = "The existing secret name inside Kubernetes for authenticating to the container registry"
}

variable "port" {
  default     = 3000
  type        = number
  description = "port the service is listening on"
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
  description = "password for registry" // DO NOT COMMIT YOUR PASSWORD TO GIT
}

variable "mongo_url" {
  default = dynamic("terraform-cloud", {
    organization = "hackweekfuntime"
    workspace    = "waypoint-demo-tfc"
    output       = "mongodb_url"
  })
  type    = string
  sensitive   = true
  description = "db url to connect"
}
