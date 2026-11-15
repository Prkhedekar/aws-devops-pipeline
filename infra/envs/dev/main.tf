locals {
  name = "taskapi-dev"
}

module "network" {
  source = "../../modules/network"
  name   = local.name
}

module "k3s" {
  source = "../../modules/k3s-node"

  name           = local.name
  vpc_id         = module.network.vpc_id
  subnet_id      = module.network.public_subnet_ids[0]
  instance_type  = var.instance_type
  allowed_cidr   = var.allowed_cidr
  ssh_public_key = file(pathexpand(var.ssh_public_key_path))
}

# TODO(stage 1 stretch): add an RDS Postgres module in module.network.private_subnet_ids
# and point the Helm chart at it instead of the in-cluster Postgres.
