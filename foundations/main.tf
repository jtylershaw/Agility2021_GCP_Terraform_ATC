# To do:
# Create variables file to pull # of students to create loop
# Create students prefix (studentXX) for naming standards
# Create loop to populate and create different VPCs and associated objects
# Pull firewall rules to firewallRules.tf for students to run

# This module has been tested with Terraform 0.12, 0.13 and 0.14.
terraform {
  required_version = "> 0.11"
}

locals {
  short_region = replace(var.region, "/^[^-]+-([^0-9-]+)[0-9]$/", "$1")
}

# Explicitly create each VPC as this will work on all supported Terraform versions

# Alpha - allows internet egress if the instance(s) have public IPs on nic0
module "external" {
  count                                  = var.numberOfStudents
  source                                 = "terraform-google-modules/network/google"
  version                                = "3.0.0"
  project_id                             = var.project_id
  network_name                           = format("student%s-external", count.index)
  delete_default_internet_gateway_routes = false
  subnets = [
    {
      subnet_name           = format("student%s-external-%s", count.index, local.short_region)
      subnet_ip             = "172.16.0.0/16"
      subnet_region         = var.region
      subnet_private_access = false
    }
  ]
}

# Management - a NAT gateway will be provisioned to support egress for control-plane
# download and installation of libraries, reaching Google APIs, etc.
module "mgmt" {
  count                                  = var.numberOfStudents
  source                                 = "terraform-google-modules/network/google"
  version                                = "3.0.0"
  project_id                             = var.project_id
  network_name                           = format("student%s-mgmt", count.index)
  delete_default_internet_gateway_routes = false
  subnets = [
    {
      subnet_name           = format("student%s-mgmt-%s", count.index, local.short_region)
      subnet_ip             = "172.17.0.0/16"
      subnet_region         = var.region
      subnet_private_access = false
    }
  ]
}

# Gamma - default routes are deleted
module "internal" {
  count                                  = var.numberOfStudents
  source                                 = "terraform-google-modules/network/google"
  version                                = "3.0.0"
  project_id                             = var.project_id
  network_name                           = format("student%s-internal", count.index)
  delete_default_internet_gateway_routes = true
  subnets = [
    {
      subnet_name           = format("student%s-internal-%s", count.index, local.short_region)
      subnet_ip             = "172.18.0.0/16"
      subnet_region         = var.region
      subnet_private_access = false
    }
  ]
}

# need to define source var.admin_source_cidrs as 0.0.0.0/0 because we are going to use strong passwords 
## and/or ssh-key deployments
resource "google_compute_firewall" "admin_mgmt" {
  count         = var.numberOfStudents
  project       = var.project_id
  name          = format("student%s-mgmt-allow-admin-access", count.index)
  network       = module.mgmt[count.index].network_self_link
  description   = format("Allow external admin access on mgmt (student%s)", count.index)
  direction     = "INGRESS"
  source_ranges = var.admin_source_cidrs
  #  target_service_accounts = [module.sa.emails["bigip"]]
  allow {
    protocol = "tcp"
    ports = [
      22,
      443,
    ]
  }
  allow {
    protocol = "icmp"
  }
}

resource "google_project_service" "api" {
  project = var.project_id
  service = "iam.googleapis.com"
  disable_on_destroy = false
}
