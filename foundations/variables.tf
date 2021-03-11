variable "numberOfStudents" {
  default = 20
}
variable "project_id" {
  type        = string
  default     = "f5-gcs-4261-sales-agility2021"
  description = <<EOD
The GCP project identifier to use for testing.
EOD
}
variable "region" {
  type        = string
  default     = "us-west1"
  description = <<EOD
The region to deploy test resources. Default is 'us-west1'.
EOD
}
variable "admin_source_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = <<EOD
The list of source CIDRs that will be added to firewall rules to allow admin
access to BIG-IPs (SSH and GUI) on alpha and beta subnetworks. Only useful if
instance has a public IP address.
EOD
}
