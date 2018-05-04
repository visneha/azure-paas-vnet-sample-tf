provider "azurerm" {}

locals {
  ops_tags        = "${merge(var.base_tags, var.ops_tags)}"
  networking_tags = "${merge(var.base_tags, var.networking_tags)}"
}

resource "azurerm_resource_group" "shared_app" {
  name     = "${var.shared_app_rg_name}"
  location = "${var.location}"
}

resource "azurerm_resource_group" "ops" {
  name     = "${var.ops_rg_name}"
  location = "${var.location}"
  tags     = "${local.ops_tags}"
}

resource "azurerm_resource_group" "networking" {
  name     = "${var.networking_rg_name}"
  location = "${var.location}"
  tags     = "${local.networking_tags}"
}

module "monitoring" {
  source              = "./monitoring"
  resource_prefix     = "${var.resource_prefix}"
  resource_group_name = "${azurerm_resource_group.ops.name}"
  oms_retention       = "${var.oms_retention}"
  tags                = "${local.ops_tags}"

  diagnostic_profiles = {
    apim      = 365
    key_vault = 365
    nsg       = 365
    waf       = 365
  }
}

module "secrets" {
  source                       = "./secrets"
  resource_prefix              = "${var.resource_prefix}"
  resource_group_name          = "${azurerm_resource_group.ops.name}"
  key_vault_sku                = "${var.key_vault_sku}"
  key_vault_deployer_object_id = "${var.key_vault_deployer_object_id}"
  diagnostic_commands          = "${module.monitoring.diagnostic_commands}"
  tags                         = "${local.ops_tags}"

  apim_cert_config = {
    cert_name   = "${replace(local.apim_base_hostname, ".", "-")}"
    common_name = "${local.apim_base_hostname}"
    alt_name    = "*.${local.apim_base_hostname}"
  }

  ase_cert_config = {
    cert_name   = "${replace(local.ase_base_hostname, ".", "-")}"
    common_name = "*.${local.ase_base_hostname}"
    alt_name    = "*.scm.${local.ase_base_hostname}"
  }
}

module "networking" {
  source              = "./networking"
  resource_prefix     = "${var.resource_prefix}"
  resource_group_name = "${var.networking_rg_name}"
  dns_servers         = "${var.dns_servers}"
  diagnostic_commands = "${module.monitoring.diagnostic_commands}"
  tags                = "${local.networking_tags}"
}
