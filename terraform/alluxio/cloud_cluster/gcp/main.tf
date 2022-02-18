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

// get the current project and provider information
data "google_client_config" "current" {
  provider = google-beta
}

locals {
  alluxio_cluster_name   = "${local.name_prefix}cluster"
  private_hostname_suffix = ".${data.google_client_config.current.zone}.c.${data.google_client_config.current.project}.internal"

  default_metadata = {
    VmDnsSetting = "ZonalPreferred"
  }
  metadata = merge(local.default_metadata, var.metadata)

  optional_components = length(var.optional_components) == 0 ? null : var.optional_components

  default_override_properties = {
    // presto query will run as the root user
    // the following config prevent the error `User: root is not allowed to impersonate <actual_user>`
    "core:hadoop.proxyuser.root.hosts"  = "*"
    "core:hadoop.proxyuser.root.groups" = "*"

    "hdfs:dfs.webhdfs.enabled" = "true"
  }
  override_properties = length(var.override_properties) == 0 ? local.default_override_properties : var.override_properties
}

resource "google_dataproc_cluster" "dataproc_cluster" {
  provider = google-beta
  name     = local.alluxio_cluster_name
  region   = data.google_client_config.current.region
  cluster_config {
    staging_bucket = var.staging_bucket
    master_config {
      num_instances = var.master_config.instance_count
      machine_type  = var.master_config.machine_type
    }
    worker_config {
      num_instances = var.worker_config.instance_count
      machine_type  = var.worker_config.machine_type
      disk_config {
        num_local_ssds = var.worker_config.num_local_ssds
      }
    }
    gce_cluster_config {
      subnetwork = var.subnet_self_link
      zone       = data.google_client_config.current.zone
      metadata   = local.metadata
      internal_ip_only = var.internal_ip_only
    }
    endpoint_config {
      enable_http_port_access = "true"
    }
    software_config {
      image_version       = var.dataproc_image_version
      optional_components = local.optional_components
      override_properties = local.override_properties
    }
    dynamic "initialization_action" {
      for_each = var.initialization_actions
      content {
        script      = initialization_action.value
        timeout_sec = 600
      }
    }
  }
}

data google_compute_instance "cluster_masters" {
  count      = var.master_config.instance_count >= 1 ? var.master_config.instance_count : 0
  depends_on = [google_dataproc_cluster.dataproc_cluster]
  provider   = google-beta
  name       = var.master_config.instance_count == 1 ? "${local.alluxio_cluster_name}-m" : "${local.alluxio_cluster_name}-m-${count.index}"
  zone       = data.google_client_config.current.zone
}
