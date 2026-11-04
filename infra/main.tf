# ROOT: the whole CloudNotes system, assembled from five modules.
# Each module.X.y reference passes a value and also sets the build order.

module "network" {
  source             = "./modules/network"
  name_prefix        = var.name_prefix
  vpc_cidr           = var.vpc_cidr
  web_subnet_cidr    = var.web_subnet_cidr
  app_subnet_cidr    = var.app_subnet_cidr
  db_subnet_cidrs    = var.db_subnet_cidrs
  availability_zones = var.availability_zones
  web_source_ranges  = var.web_source_ranges
  app_port           = var.app_port
  db_port            = var.db_port
}

module "storage" {
  source      = "./modules/storage"
  bucket_name = var.bucket_name
}

module "iam" {
  source      = "./modules/iam"
  name_prefix = var.name_prefix
  bucket_arn  = module.storage.bucket_arn # storage output -> iam input
}

module "compute" {
  source               = "./modules/compute"
  name_prefix          = var.name_prefix
  ami_id               = var.ami_id
  instance_type        = var.instance_type
  subnet_id            = module.network.app_subnet_id         # network output -> compute input
  security_group_id    = module.network.app_security_group_id # network output -> compute input
  iam_instance_profile = module.iam.app_instance_profile_name # iam output -> compute input
}

module "database" {
  source            = "./modules/database"
  name_prefix       = var.name_prefix
  engine_version    = var.db_engine_version
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  db_name           = var.db_name
  db_username       = var.db_username
  db_port           = var.db_port
  subnet_ids        = module.network.db_subnet_ids        # network output -> database input
  security_group_id = module.network.db_security_group_id # network output -> database input
}
