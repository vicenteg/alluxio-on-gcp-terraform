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

resource "random_integer" "cidr_range_prefix" {
  count = var.enabled ? (var.subnet_cidr == "" ? 1 : 0) : 0
  // avoid 0, 10, 127, and 224
  // https://cloud.ibm.com/docs/vpc-on-classic-network?topic=vpc-on-classic-network-choosing-ip-ranges-for-your-vpc
  // avoid 128 to 184 which is used as gcp default vpc ip ranges
  min = 11
  max = 126
}

// avoid cidr range prefix conflicts
resource "random_integer" "cidr_range" {
  count = var.enabled ? (var.subnet_cidr == "" ? 1 : 0) : 0
  min   = 1
  max   = 255
}

locals {
  subnet_cidr = var.subnet_cidr == "" ? cidrsubnet("10.${random_integer.cidr_range_prefix[0].result}.${random_integer.cidr_range[0].result}.0/16", 4, 0) : var.subnet_cidr
}

resource "google_compute_network" "vpc" {
  count                   = var.enabled ? 1 : 0
  provider                = google-beta
  auto_create_subnetworks = false
  name                    = "${local.name_prefix}vpc"
}

resource "google_compute_subnetwork" "subnet" {
  count                    = var.enabled ? 1 : 0
  provider                 = google-beta
  name                     = "${local.name_prefix}subnet"
  network                  = google_compute_network.vpc[0].self_link
  ip_cidr_range            = local.subnet_cidr
  private_ip_google_access = true
}

// Allow all traffic ingress from current subnet cidr
resource "google_compute_firewall" "internal_firewall" {
  count    = var.enabled ? 1 : 0
  provider = google-beta
  name     = "${local.name_prefix}internal-firewall"
  network  = google_compute_network.vpc[0].self_link
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

  source_ranges = [local.subnet_cidr]
}

// Allow ssh from anywhere
resource "google_compute_firewall" "ssh_firewall" {
  count    = var.enabled ? 1 : 0
  provider = google-beta
  name     = "${local.name_prefix}ssh-firewall"
  network  = google_compute_network.vpc[0].self_link
  allow {
    protocol = "tcp"
    ports = [
    "22"]
  }
}
