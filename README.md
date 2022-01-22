# alluxio-on-gcp-terraform
Run Alluxio Enterprise Trial Edition on Google Cloud Platform using terraform templates

# USAGE

### Step 1. Clone this repo

Use the git command to clone this repo:

     $ git clone https://github.com/gregpalmr/alluxio-on-gcp-terraform

Or using the the github.com web page (green "Code" button) to download the repo zip file and unzip it into a directory.

Change your working directory to the terraform sub-directory:

     $ cd alluxio-on-gcp-terraform/terraform

### Step 2. Install the Terraform CLI

Follow the instructions on the HashiCorp Terraform website to install the Terraform CLI on your computer. See:

     https://learn.hashicorp.com/tutorials/terraform/install-cli

### Step 3. Customize the Terraform variables

The terraform templates create resources in your Google Cloud Platform project. Modify the variables.tf file to configure the GCP project to use. Change "my-gcp-project" to your project name.

     variable "project_name" {
       description = "The project to deploy to, not required if launching in GCP cloud shell"
       type        = string
       default     = "my-gcp-project"
     }

The terraform templates create resources in the Google Cloud Platform and some of those resources must contain unique names. If you would like to create a unique name prefix you can modify the variables.tf file and change "my-cluster" to something unique in your GCP project.

     variable "custom_name" {
       description = "Name to prefix resources with."
       type        = string
       default     = "my-cluster"
     }

The default region is "us-east1". If you would like to change the region or zone, modify the variables.tf file and change "us-east1" to your desired region.

     variable "compute_region" {
       description = "Region to create compute cluster resources in"
       type        = string
       default     = "us-east1"
     }

### Step 4. Launch the Alluxio cluster on Google Cloud Platform

Use the terraform commands to initilize the templates and to launch the cluster:

     terraform init

     terraform apply

When the cluster is up and running, you will see a message indicating that the cluster is up and that shows the public IP address of the Alluxio master node. 

     Apply complete! Resources: 23 added, 0 changed, 0 destroyed.

     Outputs:

     alluxio_cluster_master_hostname = "mycluster-alluxio-cluster-m"
     alluxio_cluster_master_public_ip = "104.196.61.72"
     alluxio_cluster_master_web_ui = "http://104.196.61.72:19999"

### Step 5. Access the Alluxio Web UI

The default user id and password for the Alluxio Web UI are:

     User ID: admin
     Password: changeme123

### Step 6. Use the Alluxio Command Line Interface (CLI)

Use the gcloud command to ssh into the Alluxio master node:

     gcloud  compute ssh \
        --zone "us-west1-a" "my-cluster-alluxio-cluster-m"

Become the test user to run user based alluxio commands:

     su - user1

Use the alluxio command to view the status of the cluster:

     alluxio fsadmin report

Use the alluxio command to test creating a directory and a new file in the GCS understore:

     alluxio fs mkdir /user/user1

     alluxio fs copyFromLocal /etc/motd /user/user1/test_file.txt



---

Please direct your comments and questions to greg.palmer@alluxio.com


