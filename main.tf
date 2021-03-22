terraform {
  required_version = "> 0.11"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  # The generated service account email identifier is predictable; use this value
  # anywhere BIG-IP dedicated service account is needed.
  bigip_service_account = format("student%d-bigip@%s.iam.gserviceaccount.com", var.student_id, var.project_id)

  # CFE key:value label - will be applied to GCS buckets, VMs, and other resources
  # that need to be managed by CFE at some point.
  cfe_label_key = "f5-cfe-failover-label"
  cfe_label_value = format("student%d", var.student_id)

  # Subnets are named using an abbreviated form of region
  short_region = replace(var.region, "/^[^-]+-([^0-9-]+)[0-9]$/", "$1")

  # Labels to be applied to VMs
  # TODO: @jtylershaw @El-Coder - anything else to add?
  labels = {
    owner = format("student%d", var.student_id)
    # Make sure CFE label is present
    (local.cfe_label_key) = local.cfe_label_value
  }
}

# Each student will have their own VPCs to work in that were created by
# foundations module.
data "google_compute_subnetwork" "external" {
  project = var.project_id
  name = format("student%d-external-%s", var.student_id, local.short_region)
  region = var.region
}

data "google_compute_subnetwork" "mgmt" {
  project = var.project_id
  name = format("student%d-mgmt-%s", var.student_id, local.short_region)
  region = var.region
}
data "google_compute_subnetwork" "internal" {
  project = var.project_id
  name = format("student%d-internal-%s", var.student_id, local.short_region)
  region = var.region
}

# Pick a zone at random
data "google_compute_zones" "active" {
  project = var.project_id
  region = var.region
  status = "UP"
}

resource "random_shuffle" "zones" {
  input = data.google_compute_zones.active.names
  keepers = {
    project_id = var.project_id
    student_id = var.student_id
  }
}

# Create a service account for BIG-IP to use. This service account will be
# granted ability to send logs and metrics to Google Cloud Operations, if wanted.
module "bigip_sa" {
  source     = "terraform-google-modules/service-accounts/google"
  version    = "3.0.1"
  project_id = var.project_id
  prefix     = format("student%d", var.student_id)
  names      = ["bigip"]
  project_roles = [
    "${var.project_id}=>roles/logging.logWriter",
    "${var.project_id}=>roles/monitoring.metricWriter",
    "${var.project_id}=>roles/monitoring.viewer",
  ]
  generate_keys = false
}

# Generate a random password for BIG-IP admin, and store in GCP Secret Manager
module "bigip_admin_password" {
  source     = "memes/secret-manager/google//modules/random"
  version    = "1.0.2"
  project_id = var.project_id
  id         = format("student%d-bigip-admin-key", var.student_id)
  accessors = [
    # Generated service account email address is predictable - use it directly
    format("serviceAccount:%s", local.bigip_service_account),
  ]
  length           = 16
  special_char_set = "@#%&*()-_=+[]<>:?"
}

# HA/CFE pairs need a firewall rule to allow ConfigSync traffic
module "configsync_fw" {
  source                   = "memes/f5-bigip/google//modules/configsync-fw"
  version = "2.1.0-rc1"
  project_id               = var.project_id
  bigip_service_account    = local.bigip_service_account
  dataplane_network        = data.google_compute_subnetwork.internal.network
  management_network       = data.google_compute_subnetwork.mgmt.network
  dataplane_firewall_name  = format("student%d-allow-configsync-data", var.student_id)
  management_firewall_name = format("student%d-allow-configsync-mgt", var.student_id)
}

# BIG-IP service account will need special permissions to modify GCP resources;
# E.g. alias IP (VIP) migration on failover, route updates, etc.
module "cfe_role" {
  source                   = "memes/f5-bigip/google//modules/cfe-role"
  version = "2.1.0-rc1"
  target_type = "project"
  target_id   = var.project_id
  members     = [format("serviceAccount:%s", local.bigip_service_account)]
}

# BIG-IP CFE module requires a GCS bucket that can be used to synchronise state
# and credentials between instances.
module "cfe_bucket" {
  source     = "terraform-google-modules/cloud-storage/google"
  version    = "1.7.2"
  project_id = var.project_id
  prefix     = format("student%d", var.student_id)
  names      = ["cfe-state"]
  force_destroy = {
    "cfe-state" = true
  }
  location          = "US"
  set_admin_roles   = false
  set_creator_roles = false
  set_viewer_roles  = true
  viewers           = [format("serviceAccount:%s", local.bigip_service_account)]
  # Label the bucket with the CFE pair, as supplied to CFE module
  labels = {
    (local.cfe_label_key) = local.cfe_label_value
  }
}

# Standup BIG-IP VMs for students
# TODO: @memes @jtylershaw @El-Coder - review if F5 module is ready for lab
#  - F5 BIG-IP module does not perform NIC swap - mgmt is NIC0
module "bigip_1" {
  source = "git::https://github.com/f5devcentral/terraform-gcp-bigip-module"
  prefix = format("student%d-1", var.student_id)
  project_id = var.project_id
  zone = element(random_shuffle.zones.result, 0)
  service_account = local.bigip_service_account
  image = var.bigip_image
  gcp_secret_manager_authentication = true
  gcp_secret_name = format("student%d-bigip-admin-key", var.student_id)
  labels = local.labels
  mgmt_subnet_ids = [
    {
      subnet_id = data.google_compute_subnetwork.mgmt.self_link
      public_ip = true
      private_ip_primary = "172.17.100.1"
    },
  ]
  external_subnet_ids = [
    {
      subnet_id = data.google_compute_subnetwork.external.self_link
      public_ip = true
      private_ip_primary = "172.16.100.1"
      private_ip_secondary = "172.16.0.128/29"
    },
  ]
  internal_subnet_ids = [
    {
      subnet_id = data.google_compute_subnetwork.internal.self_link
      public_ip = false
      private_ip_primary = "172.18.100.1"
    },
  ]
  depends_on = [module.bigip_sa, module.bigip_admin_password]
}

module "bigip_2" {
  source = "git::https://github.com/f5devcentral/terraform-gcp-bigip-module"
  prefix = format("student%d-2", var.student_id)
  project_id = var.project_id
  zone = element(random_shuffle.zones.result, 1)
  service_account = local.bigip_service_account
  image = var.bigip_image
  gcp_secret_manager_authentication = true
  gcp_secret_name = format("student%d-bigip-admin-key", var.student_id)
  labels = local.labels
  mgmt_subnet_ids = [
    {
      subnet_id = data.google_compute_subnetwork.mgmt.self_link
      public_ip = true
      private_ip_primary = "172.17.100.2"
      private_ip_secondary = ""
    },
  ]
  external_subnet_ids = [
    {
      subnet_id = data.google_compute_subnetwork.external.self_link
      public_ip = true
      private_ip_primary = "172.16.100.2"
      private_ip_secondary = ""
    },
  ]
  internal_subnet_ids = [
    {
      subnet_id = data.google_compute_subnetwork.internal.self_link
      public_ip = false
      private_ip_primary = "172.18.100.2"
    },
  ]
  depends_on = [module.bigip_sa, module.bigip_admin_password]
}

# RENDER TEMPLATE FILE

data "template_file" "postman" {
  # depends_on = [null_resource.ecdsa_certs]
template = file("./postman_template.json")
vars = { 
    GCP_SECRET_ACCESS_KEY = module.bigip_2.bigip_password
    GCP_ACCESS_KEY_ID = module.bigip_2.service_account
    BIGIP_ADMIN = module.bigip_2.f5_username
    BIGIP_ADMIN_PASSWORD = module.bigip_2.bigip_password
    BIGIP1_MGMT_IP_ADDRESS = module.bigip_1.mgmtPublicIP
    BIGIP2_MGMT_IP_ADDRESS = module.bigip_2.mgmtPublicIP
    PROJECT_ID = var.project_id
    # BIGIP1_MGMT_PRIVATE_ADDRESS = aws_instance.bigip1.private_ip
    # BIGIP2_MGMT_PRIVATE_ADDRESS = aws_instance.bigip2.private_ip
    # BIGIP1_TRAFFIC_PRIVATE_ADDRESS = var.bigip1_private_ip[0]
    # BIGIP2_TRAFFIC_PRIVATE_ADDRESS = var.bigip2_private_ip[0]
    # WEB1_PRIVATE_IP_ADDRESS = aws_instance.example-a.private_ip
    # WEB2_PRIVATE_IP_ADDRESS = aws_instance.example-b.private_ip
    # BIGIP1_DEFAULT_ROUTE = var.bigip1_default_route
    # BIGIP2_DEFAULT_ROUTE = var.bigip2_default_route
    # BIGIP1_EXAMPLE01_ADDRESS = var.bigip1_private_ip[1]
    # BIGIP1_EXAMPLE02_ADDRESS = var.bigip1_private_ip[2]
    # BIGIP1_EXAMPLE03_ADDRESS = var.bigip1_private_ip[3]
    # BIGIP1_EXAMPLE04_ADDRESS = var.bigip1_private_ip[4]
    # BIGIP2_EXAMPLE01_ADDRESS = var.bigip2_private_ip[1]
    # BIGIP2_EXAMPLE02_ADDRESS = var.bigip2_private_ip[2]
    # BIGIP2_EXAMPLE03_ADDRESS = var.bigip2_private_ip[3]
    # BIGIP2_EXAMPLE04_ADDRESS = var.bigip2_private_ip[4]
    # EXAMPLE01A_ECDSA_CERT = fileexists("example01a.f5lab.dev.cert") ? file("example01a.f5lab.dev.cert") : "null"
    # EXAMPLE01A_ECDSA_KEY = fileexists("example01a.f5lab.dev.key") ? file("example01a.f5lab.dev.key") : "null"
    # EXAMPLE01B_ECDSA_CERT = fileexists("example01b.f5lab.dev.cert") ? file("example01b.f5lab.dev.cert") : "null"
    # EXAMPLE01B_ECDSA_KEY = fileexists("example01b.f5lab.dev.key") ? file("example01b.f5lab.dev.key") : "null"
}
}


resource "local_file" "postman_rendered" {
  # depends_on = [null_resource.ecdsa_certs]
content = data.template_file.postman.rendered
filename = "postman_rendered.json"
}

# resource "null_resource" "ecdsa_certs" {
#     provisioner "local-exec" {
#     command = "create-ecdsa-certs.sh"
#   }
# }
