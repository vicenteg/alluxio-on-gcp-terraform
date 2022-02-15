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
  dataproc_masters_names             = google_dataproc_cluster.dataproc_cluster.cluster_config.0.master_config.0.instance_names
  dataproc_masters_private_hostnames = formatlist("%s${local.private_hostname_suffix}", local.dataproc_masters_names)
}

output "cluster_masters_hostnames" {
  depends_on  = [google_dataproc_cluster.dataproc_cluster]
  value       = local.dataproc_masters_names
  description = "Hostnames of the masters of the dataproc cluster"
}

#output "cluster_masters_public_ips" {
#  depends_on  = [google_dataproc_cluster.dataproc_cluster]
#  value       = length(data.google_compute_instance.cluster_masters) == 0 ? [] : data.google_compute_instance.cluster_masters[*].network_interface.0.access_config.0.nat_ip
#  description = "Public ips of the masters of the dataproc cluster"
#}

output "cluster_masters_private_hostnames" {
  depends_on  = [google_dataproc_cluster.dataproc_cluster]
  value       = local.dataproc_masters_private_hostnames
  description = "Private hostnames of the masters of the dataproc cluster"
}

output "alluxio_cluster_name" {
  depends_on  = [google_dataproc_cluster.dataproc_cluster]
  value       = local.alluxio_cluster_name
  description = "Name of the dataproc cluster"
}
