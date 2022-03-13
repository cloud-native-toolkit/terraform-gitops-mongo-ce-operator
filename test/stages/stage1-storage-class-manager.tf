module "sc_manager" {
  source = "github.com/cloud-native-toolkit/terraform-util-storage-class-manager"

  rwx_storage_class = var.rwx_storage_class
  file_storage_class = var.file_storage_class
  block_storage_class = var.block_storage_class
}
