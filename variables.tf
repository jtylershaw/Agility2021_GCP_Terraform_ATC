variable "student_id" {
  type = number
  description = <<EOD
Your student id number for the lab.
EOD
}

variable "project_id" {
  type        = string
  default = "f5-gcs-4261-sales-agility2021"
  description = <<EOD
The GCP project identifier to use for testing.
EOD
}

variable "region" {
  type        = string
  default     = "us-east1"
  description = <<EOD
The region to deploy test resources. Default is 'us-east1'.
EOD
}

variable "bigip_image" {
  type = string
  default = "projects/f5-7626-networks-public/global/images/f5-bigip-15-1-2-1-0-0-10-payg-good-25mbps-210115160742"
  description = <<EOD
The BIG-IP base image to use in lab.
EOD
}
