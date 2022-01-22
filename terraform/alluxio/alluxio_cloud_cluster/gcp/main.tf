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

// metadata
locals {
  default_metadata = {
    VmDnsSetting = "ZonalPreferred"
  }
  // compact helps remove empty entries from the list
  download_files_list = join(";", compact([var.on_prem_core_site_uri, var.on_prem_hdfs_site_uri]))

  // alluxio configuration
  enable_manager_ui_pv              = "alluxio.web.manager.enabled=true"
  root_mount_hdfs_remote_pv         = "alluxio.master.mount.table.root.option.alluxio.underfs.hdfs.remote=true"
  remote_hdfs_additional_properties = var.on_prem_hdfs_address != "" ? local.root_mount_hdfs_remote_pv : ""
  all_additional_properties = trim(join(";", [
    local.enable_manager_ui_pv,
    local.remote_hdfs_additional_properties,
    var.alluxio_additional_properties
  ]), ";")

  alluxio_default_metadata = {
    alluxio_download_path   = var.alluxio_tarball_url
    alluxio_root_ufs_uri    = var.on_prem_hdfs_address == "" ? "LOCAL" : var.on_prem_hdfs_address
    alluxio_site_properties = local.all_additional_properties

    alluxio_download_files_list = local.download_files_list
    alluxio_ssd_capacity_usage  = var.alluxio_ssd_percentage_usage == 0 ? null : tostring(var.alluxio_ssd_percentage_usage)
    alluxio_sync_list           = var.alluxio_active_sync_list
    alluxio_hdfs_version        = var.hdfs_version == "" ? null : var.hdfs_version
  }

  // presto configuration
  presto_default_metadata = {
    presto_hive_catalog_address   = var.on_prem_hms_address
    presto_download_files_list    = local.download_files_list
    presto_configure_alluxio_shim = "true"
  }

  finialized_metadata = merge(local.default_metadata, local.alluxio_default_metadata, local.presto_default_metadata, var.metadata)
}

// other local variables
locals {
  finalized_optional_components = length(var.optional_components) == 0 ? ["PRESTO"] : var.optional_components
  finalize_initialization_actions = concat(
    [var.alluxio_bootstrap_gs_uri, var.presto_bootstrap_gs_uri],
    var.initialization_actions
  )
}

module "dataproc" {
  source = "../../cloud_cluster/gcp"

  // meta
  enabled = var.enabled

  // name
  use_default_name = var.use_default_name
  custom_name      = var.custom_name

  // dataproc
  master_config          = var.master_config
  worker_config          = var.worker_config
  metadata               = local.finialized_metadata
  optional_components    = local.finalized_optional_components
  override_properties    = var.override_properties
  initialization_actions = local.finalize_initialization_actions
  staging_bucket         = var.staging_bucket
  dataproc_image_version = var.dataproc_image_version

  // network connectivity
  vpc_self_link    = var.vpc_self_link
  subnet_self_link = var.subnet_self_link
}

// Open alluxio and presto web ui ports to the world
// Presto is launched with 8060 http port in dataproc
resource "google_compute_firewall" "alluxio_presto_firewall" {
  provider = google-beta
  name     = "${local.name_prefix}alluxio-presto-firewall"
  network  = var.vpc_self_link

  allow {
    protocol = "tcp"
    ports = [
    "19999", "30077", "30000", "8060"]
  }
}

resource "null_resource" "master_nums_check" {
  count = var.enabled ? 1 : 0
  provisioner "local-exec" {
    command = "if [[ \"${var.master_config.instance_count}\" != \"1\" ]]; then echo \"Alluxio cloud cluster doesn't support multiple masters\" && exit 1; fi"
  }
}
