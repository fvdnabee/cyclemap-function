locals {
  mongodb_uri = replace(mongodbatlas_cluster.cluster.srv_address, "mongodb+srv://", "mongodb+srv://${mongodbatlas_database_user.db_user.username}:${coalesce(nonsensitive(mongodbatlas_database_user.db_user.password), "null")}@")
}

variable "mongodbatlas_public_key" {
  type      = string
  nullable  = false
  sensitive = true
}

variable "mongodbatlas_private_key" {
  type      = string
  nullable  = false
  sensitive = true
}

provider "mongodbatlas" {
  public_key  = var.mongodbatlas_public_key
  private_key = var.mongodbatlas_private_key
}

data "mongodbatlas_roles_org_id" "vdna" {
}

resource "mongodbatlas_project" "cyclemap" {
  name   = "cyclemap"
  org_id = data.mongodbatlas_roles_org_id.vdna.org_id
}

resource "mongodbatlas_project_ip_access_list" "test" {
  project_id = mongodbatlas_project.cyclemap.id
  cidr_block = "0.0.0.0/0"
  comment    = "allow world"
}

resource "mongodbatlas_cluster" "cluster" {
  project_id = mongodbatlas_project.cyclemap.id
  name       = "cluster"

  # Provider Settings "block"
  provider_name               = "TENANT"
  backing_provider_name       = "AWS"
  provider_region_name        = "EU_CENTRAL_1"
  provider_instance_size_name = "M0"
}

resource "random_password" "db_user_pw" {
  length  = 32
  special = false
}

resource "mongodbatlas_database_user" "db_user" {
  username           = "cyclemap"
  password           = random_password.db_user_pw.result
  auth_database_name = "admin"
  project_id         = mongodbatlas_project.cyclemap.id
  roles {
    role_name     = "readWrite"
    database_name = "cyclemap_db"
  }
  depends_on = [mongodbatlas_project.cyclemap]
}

output "mongo_srv_address" {
  value = mongodbatlas_cluster.cluster.srv_address
}

output "mongo_user_username" {
  value = mongodbatlas_database_user.db_user.username
}

output "mongo_user_password" {
  value     = mongodbatlas_database_user.db_user.password
  sensitive = true
}

output "mongo_conn_string" {
  value     = local.mongodb_uri
  sensitive = true
}
