locals {
  name          = "mongo-ce"
  bin_dir       = module.setup_clis.bin_dir
  yaml_dir      = "${path.cwd}/.tmp/${local.name}/chart/${local.name}"
  service_url   = "http://${local.name}.${var.namespace}"
  tmp_dir = "${path.cwd}/.tmp"
  values_content = {  
    mongo-ce = {
      name = "mongo-ce"
      saname = var.mongo_serviceaccount
      namespace= var.namespace
      mongo-ce-secret = {
          password= var.mongo_password
        }
      mongo-ce-mongodbcommunity = {
          version = ""
          storageclassname = var.mongo_storageclass
        }
    }    
  }
  layer = "services"
  type  = "base"
  application_branch = "main"
  namespace = var.namespace
  layer_config = var.gitops_config[local.layer]
}

module setup_clis {
  source = "github.com/cloud-native-toolkit/terraform-util-clis.git"
}


resource null_resource create_yaml {
  provisioner "local-exec" {
    command = "${path.module}/scripts/create-yaml.sh '${local.name}' '${local.yaml_dir}'"

    environment = {
      VALUES_CONTENT = yamlencode(local.values_content)
    }
  }
}

resource null_resource setup_gitops {
  depends_on = [null_resource.create_yaml]

  provisioner "local-exec" {
    command = "${local.bin_dir}/igc gitops-module '${local.name}' -n '${var.namespace}' --contentDir '${local.yaml_dir}' --serverName '${var.server_name}' -l '${local.layer}' --type '${local.type}' --debug"

    environment = {
      GIT_CREDENTIALS = yamlencode(nonsensitive(var.git_credentials))
      GITOPS_CONFIG   = yamlencode(var.gitops_config)
    }
  }
}

module "service_account" {
  source = "github.com/cloud-native-toolkit/terraform-gitops-service-account.git"

  gitops_config = var.gitops_config
  git_credentials = var.git_credentials
  namespace = var.namespace
  name = var.mongo_serviceaccount
  sccs = ["anyuid"]
  server_name = var.server_name
}

resource null_resource setup_gitops_destroy {
  depends_on = [null_resource.create_yaml]

  triggers = {
    name = local.name
    namespace = var.namespace
    yaml_dir = local.yaml_dir
    server_name = var.server_name
    layer = local.layer
    type = local.type
    git_credentials = yamlencode(var.git_credentials)
    gitops_config   = yamlencode(var.gitops_config)
    bin_dir = local.bin_dir
  }

  provisioner "local-exec" {
    command = "${self.triggers.bin_dir}/igc gitops-module '${self.triggers.name}' -n '${self.triggers.namespace}' --contentDir '${self.triggers.yaml_dir}' --serverName '${self.triggers.server_name}' -l '${self.triggers.layer}' --type '${self.triggers.type}'"

    environment = {
      GIT_CREDENTIALS = nonsensitive(self.triggers.git_credentials)
      GITOPS_CONFIG   = self.triggers.gitops_config
    }
  }

  provisioner "local-exec" {
    when = destroy
    command = "${self.triggers.bin_dir}/igc gitops-module '${self.triggers.name}' -n '${self.triggers.namespace}' --delete --contentDir '${self.triggers.yaml_dir}' --serverName '${self.triggers.server_name}' -l '${self.triggers.layer}' --type '${self.triggers.type}'"

    environment = {
      GIT_CREDENTIALS = nonsensitive(self.triggers.git_credentials)
      GITOPS_CONFIG   = self.triggers.gitops_config
    }
  }
}

#  CREATE A CA CERTIFICATE

resource "tls_private_key" "ca" {
  algorithm   = "RSA"
  rsa_bits    = "2048"
}

resource "tls_self_signed_cert" "ca" {
  key_algorithm     = "${tls_private_key.ca.algorithm}"
  private_key_pem   = "${tls_private_key.ca.private_key_pem}"
  is_ca_certificate = true
  set_subject_key_id = true

  subject {
    common_name  = "*.mas-mongo-ce-svc.${var.namespace}.svc.cluster.local"
    organization = "Example, LLC"
  }
  
  validity_period_hours = 730 * 24
  allowed_uses = [
    "digital_signature",
    "content_commitment",
    "key_encipherment",
    "data_encipherment",
    "key_agreement",
    "cert_signing",
    "crl_signing",
    "encipher_only",
    "decipher_only",
    "any_extended",
    "server_auth",
    "client_auth",
    "code_signing",
    "email_protection",
    "ipsec_end_system",
    "ipsec_tunnel",
    "ipsec_user",
    "timestamping",
    "ocsp_signing"
  ]
  dns_names = [ "*.mas-mongo-ce-svc.${var.namespace}.svc.cluster.local","127.0.0.1","localhost" ]

}

# CREATE A TLS CERTIFICATE SIGNED USING THE CA CERTIFICATE

resource "tls_private_key" "cert" {
  algorithm   = "RSA"
  rsa_bits    = "2048"
}

resource "local_file" "cafile" {
  sensitive_content = "${tls_self_signed_cert.ca.cert_pem}"
  file_permission = "0600"
  filename    = "${local.tmp_dir}/ca.pem"
}

resource "tls_cert_request" "cert" {
  key_algorithm   = "${tls_private_key.cert.algorithm}"
  private_key_pem = "${tls_private_key.cert.private_key_pem}"

  dns_names = [ "*.mas-mongo-ce-svc.${var.namespace}.svc.cluster.local","127.0.0.1","localhost" ]

  subject {
    common_name  = "*.mas-mongo-ce-svc.${var.namespace}.svc.cluster.local"
    organization = "Example, LLC"
  }
}

resource "tls_locally_signed_cert" "cert" {
  cert_request_pem = "${tls_cert_request.cert.cert_request_pem}"

  ca_key_algorithm   = "${tls_private_key.ca.algorithm}"
  ca_private_key_pem = "${tls_private_key.ca.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.ca.cert_pem}"
  is_ca_certificate = true

  validity_period_hours = 730 * 24
  allowed_uses = [
    "digital_signature",
    "content_commitment",
    "key_encipherment",
    "data_encipherment",
    "key_agreement",
    "cert_signing",
    "crl_signing",
    "encipher_only",
    "decipher_only",
    "any_extended",
    "server_auth",
    "client_auth",
    "code_signing",
    "email_protection",
    "ipsec_end_system",
    "ipsec_tunnel",
    "ipsec_user",
    "timestamping",
    "ocsp_signing"
  ]

}

resource "local_file" "srvkeyfile" {
  sensitive_content = "${tls_private_key.cert.private_key_pem}"
  file_permission = "0600"
  filename    = "${local.tmp_dir}/server.key"
}

  resource "local_file" "srvcrtfile" {
  sensitive_content = "${tls_locally_signed_cert.cert.cert_pem}"
  file_permission = "0600"
  filename    = "${local.tmp_dir}/server.crt"
}

resource "null_resource" "deploy_certs" {
  depends_on = [null_resource.setup_gitops]
  triggers = {
    kubeconfig = var.cluster_config_file
    namespace = var.namespace
    certpath = local.tmp_dir
  }
  provisioner "local-exec" {
    command = "kubectl create configmap mas-mongo-ce-cert-map --from-file=ca.crt=${self.triggers.certpath}/ca.pem -n ${self.triggers.namespace}"
    
    environment = {
      KUBECONFIG = self.triggers.kubeconfig
    }
  }

  provisioner "local-exec" {
    command = "kubectl create secret tls mas-mongo-ce-cert-secret --cert=${self.triggers.certpath}/server.crt --key=${self.triggers.certpath}/server.key -n ${self.triggers.namespace}"
    
    environment = {
      KUBECONFIG = self.triggers.kubeconfig
    }
  }

  provisioner "local-exec" {
    when = destroy
    command = "kubectl delete configmap mas-mongo-ce-cert-map -n ${self.triggers.namespace}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
    }
  }

  provisioner "local-exec" {
    when = destroy
    command = "kubectl delete secret mas-mongo-ce-cert-secret -n ${self.triggers.namespace}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
    }
  }
}

