
output "name" {
  description = "The name of the module"
  value       = local.name
  depends_on  = [null_resource.setup_gitops]
}

output "branch" {
  description = "The branch where the module config has been placed"
  value       = local.application_branch
  depends_on  = [null_resource.setup_gitops]
}

output "namespace" {
  description = "The namespace where the module will be deployed"
  value       = local.namespace
  depends_on  = [null_resource.setup_gitops]
}

output "server_name" {
  description = "The server where the module will be deployed"
  value       = var.server_name
  depends_on  = [null_resource.setup_gitops]
}

output "layer" {
  description = "The layer where the module is deployed"
  value       = local.layer
  depends_on  = [null_resource.setup_gitops]
}

output "type" {
  description = "The type of module where the module is deployed"
  value       = local.type
  depends_on  = [null_resource.setup_gitops]
}

output "mongo_pw" {
  value       = var.mongo_password
  description = "mongo admin pw"
  depends_on  = [
    null_resource.deploy_instance
  ]
}

output "mongo_namespace" {
  value       = var.mongo_namespace
  description = "Namespace mongo is located in cluster"
  depends_on  = [
    null_resource.deploy_instance
  ]
}

output "mongo_servicename" {
  description = "Name of mongo service to connect to"
  depends_on  = [
    null_resource.deploy_instance
  ]
  value       = data.local_file.svcname.content
}
