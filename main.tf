locals {
  name          = "mongo-ce"
  bin_dir       = module.setup_clis.bin_dir
  yaml_dir      = "${path.cwd}/.tmp/${local.name}/chart/${local.name}"
  service_url   = "http://${local.name}.${var.namespace}"
  tmp_dir = "${path.cwd}/.tmp/${local.name}"
  values_content = {  
    mongoce = {
      name = "mongo-ce"
      crdname = var.crdname
      saname = var.mongo_serviceaccount
      namespace= var.namespace
      mongocesecret = {
          password= var.mongo_password
          crt =  base64encode("${local_file.srvcrtfile.sensitive_content}")
          key = base64encode("${local_file.srvkeyfile.sensitive_content}")

        }
      mongocemongodbcommunity = {
          version = var.mongo_version
          storageclassname = var.mongo_storageclass
        }
      mongocecm = {
        cacrt = "${tls_self_signed_cert.ca.cert_pem}"
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
  cluster_scope = true
  rbac_rules = [{
    apiGroups = [
      "",
      "apps",
      "monitoring.coreos.com",
      "rbac.authorization.k8s.io",
      "mongodbcommunity.mongodb.com",
      "security.openshift.io",


    ]
    resourceNames = [
      "mongodb-kubernetes-operator",
      "${namespace}-${name}-anyuid"

    ]
    resources = [
      "pods",
      "services",
      "serviceaccounts",
      "services/finalizers",
      "endpoints",
      "persistentvolumeclaims",
      "events",
      "configmaps",
      "secrets",
      "deployments",
      "daemonsets",
      "replicasets",
       "statefulsets",
       "servicemonitors",
       "deployments/finalizers",
       "clusterrolebindings",
       "clusterroles",
       "rolebindings",
       "roles",
       "namespaces",
       "replicasets",
       "mongodbcommunity",
       "mongodbcommunity/status",
       "mongodbcommunity/spec",
       "mongodbcommunity/finalizers",
       "securitycontextconstraints"
       
    ]
    verbs = [
      "*"
    ]
  }]
}






