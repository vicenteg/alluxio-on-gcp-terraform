# alluxio-on-gcp-terraform
Run Alluxio Enterprise Trial Edition on Google Cloud Platform using terraform templates

# Introduction

![Alt text](/images/Meet_Alluxio_Overview.png?raw=true "Meet Alluxio")

# USAGE

### Step 1. Clone this repo

Use the git command to clone this repo:

     $ git clone https://github.com/gregpalmr/alluxio-on-gcp-terraform

Or use the the github.com web page (the green "Code" button) to download the repo zip file and unzip it into a directory.

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

The terraform templates create resources in the Google Cloud Platform and some of those resources must contain unique names. If you would like to create a unique name prefix you can modify the variables.tf file and change "my" to something unique in your GCP project.

     variable "custom_name" {
       description = "Name to prefix resources with. Example: 'johns' will show up as 'johns-alluxio-cluster'"
       type        = string
       default     = "my"
     }

The default region is "us-east1". If you would like to change the region or zone, modify the variables.tf file and change "us-east1" to your desired region.

     variable "compute_region" {
       description = "Region to create compute cluster resources in"
       type        = string
       default     = "us-east1"
     }

By default the templates launch 5 Alluxio worker nodes. If you would like to change the number of workers, modify the main.tf file and change the "instance_count" for "worker_config", like this:

     master_config = {
       instance_count = 1
       machine_type   = "n1-highmem-16"
     }
     worker_config = {
       num_local_ssds = 1
       instance_count = 5
       machine_type   = "n1-highmem-16"
     }

### Step 4. Customize the Alluxio properties

The Alluxio configuration files are located in the ./staging_files/conf directory. They are setup to use Google Cloud Storage as the root understore (UFS), but other understores can be mounted using the "nested mount" options in Alluxio.  

If you would like to tune the JVM parameters for the Alluxio masters and workers, you can modify the alluxio-env.sh file like this:

     # File: alluxio-env.sh
     #
     
     # Alluxio Master Nodes:
     export ALLUXIO_MASTER_JAVA_OPTS+=" -Xms64g -Xmx64g -XX:+UseConcMarkSweepGC -XX:+PrintGC -XX:+PrintGCDateStamps -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:+UseParNewGC -Xloggc:/opt/alluxio/logs/jvm_gc_master.log"
     
     # Alluxio Worker Nodes:
     export ALLUXIO_WORKER_JAVA_OPTS+=" -Xms24g -Xmx24g -XX:MaxDirectMemorySize=12g -XX:+UseConcMarkSweepGC -XX:+PrintGC -XX:+PrintGCDateStamps -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:+UseParNewGC -Xloggc:/opt/alluxio/logs/jvm_gc_worker.log"
     
     # end of file

If you would like to tweak the properties for the Alluxio masters, workers and users, you can modify the alluxio-site.properties file like this:

     ### File: alluxio-site.properties
     ###
     
     # General props
     alluxio.web.login.enabled=true
     alluxio.web.login.username=admin
     alluxio.web.login.password=changeme123
     alluxio.web.login.session.timeout=3h
     
     # Master props
     alluxio.master.hostname=ALLUXIO_MASTER
     alluxio.master.journal.type=EMBEDDED
     alluxio.master.metastore=ROCKS
     
     # Client-side (northbound) kerberos authentication props
     
     # Root understore UFS props
     alluxio.master.mount.table.root.ufs=gs://GS_UFS_BUCKET/alluxio_ufs/
     # alluxio.master.mount.table.root.option.fs.gcs.credential.path=/path/to/<google_application_credentials>.json
     alluxio.master.security.impersonation.root.users=*
     alluxio.master.security.impersonation.root.groups=*
     alluxio.master.security.impersonation.client.users=*
     alluxio.master.security.impersonation.client.groups=*
     
     # Security props
     alluxio.security.login.impersonation.username=_NONE_
     alluxio.security.authorization.permission.enabled=true
     
     # Worker props
     alluxio.worker.ramdisk.size=64GB
     alluxio.worker.tieredstore.level0.alias=MEM
     alluxio.worker.tieredstore.level0.dirs.path=/mnt/ramdisk
     alluxio.worker.tieredstore.levels=1
     
     # User props
     alluxio.user.rpc.retry.max.duration=10min
     alluxio.user.file.writetype.default=CACHE_THROUGH
     alluxio.user.file.readtype.default=CACHE
     
     ### end of file

### Step 5. Launch the Alluxio cluster on Google Cloud Platform

Use the terraform commands to initilize the templates and to launch the cluster:

     terraform init

     terraform apply

When the cluster is up and running, you will see a message indicating that the cluster is up and that shows the public IP address of the Alluxio master node. 

     Apply complete! Resources: 23 added, 0 changed, 0 destroyed.

     Outputs:

     alluxio_cluster_master_hostname = "my-alluxio-cluster-m"
     alluxio_cluster_master_public_ip = "104.196.61.72"
     alluxio_cluster_master_web_ui = "http://104.196.61.72:19999"

### Step 6. Access the Alluxio Web UI

Point your web browser to the "alluxio_cluster_master_web_ui" URL shown above. 

![Alt text](/images/Alluxio_WebUI_Login.png?raw=true "Alluxio Web UI Login")

The default user id and password for the Alluxio Web UI are:

     User ID: admin
     Password: changeme123

Once logged in, you will see the Alluxio cluster summary page.

![Alt text](/images/Alluxio_WebUI_Summary.png?raw=true "Alluxio Web UI Summary")

### Step 7. Use the Alluxio Command Line Interface (CLI)

Use the gcloud command to ssh into the Alluxio master node:

     gcloud  compute ssh \
        --zone "us-west1-a" "my-alluxio-cluster-m"

Become the alluxio user to run some smoke tests:

     sudo su - alluxio

     runTests

![Alt text](/images/Alluxio_runTests.png?raw=true "Alluxio runTests results")

When completed, exit as the alluxio user.

     exit

Become the test user to run user based alluxio commands:

     sudo su - user1

Use the alluxio command to view the status of the cluster:

     alluxio fsadmin report

![Alt text](/images/Alluxio_fsadmin_report.png?raw=true "Alluxio fsadmin report")

Use the alluxio command to test creating a directory and a new file in the GCS understore:

     alluxio fs mkdir /user/user1

     alluxio fs copyFromLocal /etc/motd /user/user1/test_file.txt

### Step 8. Destroy the cluster

Use the Terraform CLI command to destroy the cluster and release the resources.

     terraform destroy

---

Please direct your comments and questions to greg.palmer@alluxio.com


