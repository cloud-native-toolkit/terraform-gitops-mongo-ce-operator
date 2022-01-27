module "gitops_module" {
  source = "./module"

  cluster_config_file = module.dev_cluster.config_file_path
  gitops_config = module.gitops.gitops_config
  git_credentials = module.gitops.git_credentials
  server_name = module.gitops.server_name
  namespace = module.gitops_namespace.name
  kubeseal_cert = module.gitops.sealed_secrets_cert
  mongo_storageclass = "ibmc-vpc-block-5iops-tier" 
}
