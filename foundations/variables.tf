variable "numberOfStudents" {
  type = number
  default = 20
  description = <<EOD
The number of students attending the Agility lab. Separate VPCs will be created
for each attendee.
EOD
}

variable "project_id" {
  type        = string
  default     = "f5-gcs-4261-sales-agility2021"
  description = <<EOD
The GCP project identifier to use for Agility lab.
EOD
}

variable "region" {
  type        = string
  default     = "us-east1"
  description = <<EOD
The region to deploy test resources. Default is 'us-east1'.
EOD
}

variable "admin_source_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = <<EOD
The list of source CIDRs that will be added to firewall rules to allow admin
access to BIG-IPs (SSH and GUI) on external and management subnetworks.
EOD
}

variable "apis" {
  type = list(string)
  default = [
    "iam.googleapis.com",
    "storage-api.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ]
  description = <<EOD
A list of GCP APIs to enable in the project.
EOD
}
