/*
 * The Alluxio Open Foundation licenses this work under the Apache License, version 2.0
 * (the "License"). You may not use this work except in compliance with the License, which is
 * available at www.apache.org/licenses/LICENSE-2.0
 *
 * This software is distributed on an "AS IS" basis, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
 * either express or implied, as more fully set forth in the License.
 *
 * See the NOTICE file distributed with this work for information regarding copyright ownership.
 */

variable "project_name" {
  description = "The project to deploy to, not required if launching in GCP cloud shell"
  type        = string
  default     = "my-gcp-project"
}

variable "credentials" {
  description = "File containing service account key, not required if launching in GCP cloud shell or authenticating with 'gcloud auth application-default login`"
  type        = string
  default     = ""
}

variable "use_default_name" {
  description = "Whether to use the default readable names for created resources. Random string will be attached to the default readable resource names if false. Recommended to set to false for production."
  type        = bool
  default     = true
}

variable "custom_name" {
  description = "Name to prefix resources with. Example: 'johns' will show up as 'johns-alluxio-cluster'"
  type        = string
  default     = "my"
}

variable "compute_region" {
  description = "Region to create compute cluster resources in"
  type        = string
  default     = "us-east1"
}

variable "compute_zone" {
  description = "Region to create compute cluster resources in"
  type        = string
  default     = "us-east1-d"
}

variable "alluxio_tarball_url" {
  description = "Alluxio tarball download url. Url should be of https url or gs url"
  type        = string
  default =     "https://downloads.alluxio.io/protected/files/alluxio-enterprise-trial.tar.gz"
}

variable "create_test_users" {
  description = "Create test users 'user1' and 'user2'"
  type        = string
  default =     "false"
}

variable "vpc_self_link" {
  description = "Link to the VPC to deploy resources in."
  type = string
}

variable "subnet_self_link" {
  description = "Link to the VPC subnetwork to deploy resources in."
  type = string
}
