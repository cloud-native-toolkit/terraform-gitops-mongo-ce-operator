locals {
  name          = "mongo-ce-operator"
  bin_dir       = module.setup_clis.bin_dir
  yaml_dir      = "${path.cwd}/.tmp/${local.name}/chart/mongo-ce-operator"
  tmp_dir = "${path.cwd}/.tmp/${local.name}"
  values_content = {  
    name = "mongo-ce"
    saName = var.mongo_serviceaccount
    rbac = false
  }
  layer = "services"
  type  = "base"
  application_branch = "main"
  namespace = var.namespace
  layer_config = var.gitops_config[local.layer]
  values_file = "values-${var.server_name}.yaml"
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

module "service_account" {
  source = "github.com/cloud-native-toolkit/terraform-gitops-service-account.git?ref=provider"

  gitops_config = var.gitops_config
  git_credentials = var.git_credentials
  namespace = var.namespace
  name = var.mongo_serviceaccount
  sccs = ["anyuid"]
  server_name = var.server_name
  rbac_cluster_scope = true
  rbac_rules = [{
    apiGroups = [
      "*"
    ]
    resources = [
      "*"
    ]
    verbs = [
      "*"
    ]
  }]
}

resource gitops_module module {
  depends_on = [null_resource.create_yaml]

  name        = local.name
  namespace   = var.namespace
  content_dir = local.yaml_dir
  server_name = var.server_name
  layer       = local.layer
  type        = local.type
  branch      = local.application_branch
  config      = yamlencode(var.gitops_config)
  credentials = yamlencode(var.git_credentials)
}
