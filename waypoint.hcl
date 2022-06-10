project = "hashiconf-demo"

app "shrls" {
  labels = {
    "service" = "shrls",
    # "env"     = "dev"
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
        # local = false
      }
    }
  }

  deploy {
    use "kubernetes" {
      probe_path = "/"
      // Kube secret for pulling image from registry
      image_secret = var.registrycreds_secret
    }
  }

  release {
    use "kubernetes" {
      // Sets up a load balancer to access released application
      load_balancer = true
      # port          = var.port
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
