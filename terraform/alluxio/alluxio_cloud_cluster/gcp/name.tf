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

// determine name_prefix for all resources created by the module
// name prefix should be valid in gcp
// gcp resource name must be a match of regex '(?:[a-z](?:[-a-z0-9]{0,61}[a-z0-9])?)'
// gcp account id match regexp "^[a-z](?:[-a-z0-9]{4,28}[a-z0-9])$"
resource "random_string" "name_presuffix" {
  length  = 4
  upper   = false
  lower   = true
  number  = false
  special = false
}

resource "random_id" "name_suffix" {
  byte_length = 2
}

locals {
  randomize_name = var.use_default_name ? "" : "${random_string.name_presuffix.result}${random_id.name_suffix.hex}-"
  name_prefix    = var.custom_name == "" ? local.randomize_name : "${local.randomize_name}${var.custom_name}-"
}
