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

locals {
  credentials_file = var.credentials == "" ? null : file(var.credentials)
}

provider "google-beta" {
  alias       = "google_compute"
  project     = var.project_name
  credentials = local.credentials_file
  region      = var.compute_region
  zone        = var.compute_zone
  version     = "~> 3.21"
}

resource "random_string" "name_presuffix" {
  length  = 6
  upper   = false
  lower   = true
  number  = false
  special = false
}

resource "random_id" "name_suffix" {
  byte_length = 4
}

resource "google_storage_bucket" "shared_gs_bucket" {
  provider      = google-beta.google_compute
  name          = "${local.name_prefix}alluxio-gcs-bucket"
  location      = var.compute_region
  force_destroy = true
}

locals {
  randomize_name = var.use_default_name ? "" : "${random_string.name_presuffix.result}${random_id.name_suffix.hex}-"
  name_prefix    = var.custom_name == "" ? local.randomize_name : "${local.randomize_name}${var.custom_name}-"

  compute_custom_name_prefix = trimprefix("${var.custom_name}-alluxio", "-")

  conf_gs_uri = "gs://${google_storage_bucket.shared_gs_bucket.name}"
}

// compute cluster resources
#module "vpc_compute" {
#  source = "./alluxio/vpc_with_internet/gcp"
#  providers = {
#    google-beta = google-beta.google_compute
#  }
#
#  use_default_name = var.use_default_name
#  custom_name      = local.compute_custom_name_prefix
#}

resource "google_storage_bucket_object" "alluxio_bootstrap" {
  provider = google-beta.google_compute
  bucket   = google_storage_bucket.shared_gs_bucket.name
  name     = "alluxio-bootstrap.sh"
  source = "./staging_files/scripts/alluxio-bootstrap.sh"
}

resource "google_storage_bucket_object" "presto_bootstrap" {
  provider = google-beta.google_compute
  bucket   = google_storage_bucket.shared_gs_bucket.name
  name     = "presto-bootstrap.sh"
  source = "./staging_files/scripts/presto-bootstrap.sh"
}

resource "google_storage_bucket_object" "hadoop_core_site" {
  provider = google-beta.google_compute
  bucket   = google_storage_bucket.shared_gs_bucket.name
  name     = "core-site.xml"
  source = "./staging_files/conf/core-site.xml"
}

resource "google_storage_bucket_object" "hadoop_hdfs_site" {
  provider = google-beta.google_compute
  bucket   = google_storage_bucket.shared_gs_bucket.name
  name     = "hdfs-site.xml"
  source = "./staging_files/conf/hdfs-site.xml"
}

resource "google_storage_bucket_object" "alluxio_site_properties" {
  provider = google-beta.google_compute
  bucket   = google_storage_bucket.shared_gs_bucket.name
  name     = "alluxio-site.properties"
  source = "./staging_files/conf/alluxio-site.properties"
}

resource "google_storage_bucket_object" "alluxio_env_sh" {
  provider = google-beta.google_compute
  bucket   = google_storage_bucket.shared_gs_bucket.name
  name     = "alluxio-env.sh"
  source = "./staging_files/conf/alluxio-env.sh"
}

module "alluxio_cluster" {
  source = "./alluxio/alluxio_cloud_cluster/gcp"
  providers = {
    google-beta = google-beta.google_compute
  }

  project_id     = var.project_name
  use_default_name = var.use_default_name
  custom_name      = local.compute_custom_name_prefix

#  vpc_self_link    = module.vpc_compute.vpc_self_link
#  subnet_self_link = module.vpc_compute.subnet_self_link
  vpc_self_link = var.vpc_self_link
  subnet_self_link = var.subnet_self_link
  staging_bucket   = google_storage_bucket.shared_gs_bucket.name

  alluxio_tarball_url      = var.alluxio_tarball_url
  alluxio_bootstrap_gs_uri = "gs://${google_storage_bucket.shared_gs_bucket.name}/${google_storage_bucket_object.alluxio_bootstrap.name}"
  presto_bootstrap_gs_uri  = "gs://${google_storage_bucket.shared_gs_bucket.name}/${google_storage_bucket_object.presto_bootstrap.name}"

  on_prem_core_site_uri = "${local.conf_gs_uri}/core-site.xml"
  on_prem_hdfs_site_uri = "${local.conf_gs_uri}/hdfs-site.xml"

  metadata = {
    alluxio_gs_ufs_bucket   = google_storage_bucket.shared_gs_bucket.name
    alluxio_gs_conf_folder  = local.conf_gs_uri
  }

  master_config = {
    instance_count = 1
    machine_type   = "n1-highmem-16"
  }
  worker_config = {
    num_local_ssds = 2
    instance_count = 2
    machine_type   = "n1-highmem-16"
  }
}


