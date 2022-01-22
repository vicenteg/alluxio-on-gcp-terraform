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

provider "google-beta" {
  alias = "cloud_compute"
}

provider "google-beta" {
  alias = "on_prem"
}

data "google_compute_subnetwork" "subnet_compute" {
  count     = var.enabled ? 1 : 0
  provider  = google-beta.cloud_compute
  self_link = var.cloud_compute_subnet_self_link
}

data "google_compute_subnetwork" "subnet_onprem" {
  count     = var.enabled ? 1 : 0
  provider  = google-beta.on_prem
  self_link = var.on_prem_subnet_self_link
}

resource "google_compute_network_peering" "vpc_peering_on_prem" {
  count        = var.enabled ? 1 : 0
  provider     = google-beta.on_prem
  name         = "${local.name_prefix}vpc-peering-on-prem"
  network      = var.on_prem_vpc_self_link
  peer_network = var.cloud_compute_vpc_self_link
}

// get the current project and provider information
data "google_client_config" "client_config_on_prem" {
  count    = var.enabled ? 1 : 0
  provider = google-beta.on_prem
}

resource "google_dns_managed_zone" "dns_peering_compute_to_onprem" {
  count      = var.enabled ? 1 : 0
  provider   = google-beta.on_prem
  name       = "${local.name_prefix}dns-peering-on-prem"
  dns_name   = "${data.google_client_config.client_config_on_prem[0].zone}.c.${data.google_compute_subnetwork.subnet_onprem[0].project}.internal."
  visibility = "private"
  private_visibility_config {
    networks {
      network_url = var.cloud_compute_vpc_self_link
    }
  }
  peering_config {
    target_network {
      network_url = var.on_prem_vpc_self_link
    }
  }
}

resource "google_compute_network_peering" "vpc_peering_compute" {
  count        = var.enabled ? 1 : 0
  provider     = google-beta.cloud_compute
  name         = "${local.name_prefix}vpc-peering-compute"
  network      = var.cloud_compute_vpc_self_link
  peer_network = var.on_prem_vpc_self_link
  depends_on   = [google_compute_network_peering.vpc_peering_on_prem] // define strict dependency for clean destroy
}

// Allow all traffic ingress from onprem to compute cluster
resource "google_compute_firewall" "firewall_onprem_to_compute" {
  count    = var.enabled ? 1 : 0
  provider = google-beta.cloud_compute
  name     = "${local.name_prefix}firewall-onprem-to-compute"
  network  = var.cloud_compute_vpc_self_link
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports = [
    "0-65535"]
  }
  allow {
    protocol = "udp"
    ports = [
    "0-65535"]
  }
  source_ranges = [data.google_compute_subnetwork.subnet_onprem[0].ip_cidr_range]
}

// Allow all traffic ingress from compute to onprem cluster
resource "google_compute_firewall" "firewall_compute_to_onprem" {
  count    = var.enabled ? 1 : 0
  provider = google-beta.on_prem
  name     = "${local.name_prefix}firewall-compute-to-onprem"
  network  = var.on_prem_vpc_self_link
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports = [
    "0-65535"]
  }
  allow {
    protocol = "udp"
    ports = [
    "0-65535"]
  }
  source_ranges = [data.google_compute_subnetwork.subnet_compute[0].ip_cidr_range]
}

// Not required for our examples
// for exchanging routes between google VPC and on-premises networks by using BGP
resource "google_compute_router" "router_compute" {
  count    = var.enabled ? 1 : 0
  provider = google-beta.cloud_compute
  name     = "${local.name_prefix}rounter-compute"
  region   = data.google_compute_subnetwork.subnet_compute[0].region
  network  = var.cloud_compute_vpc_self_link

  bgp {
    asn = 64514
  }
}
resource "google_compute_router_nat" "nat_compute" {
  count                              = var.enabled ? 1 : 0
  provider                           = google-beta.cloud_compute
  name                               = "${local.name_prefix}rounter-nat-compute"
  router                             = google_compute_router.router_compute[0].name
  region                             = google_compute_router.router_compute[0].region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
