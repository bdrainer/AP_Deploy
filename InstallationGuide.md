# Installation Guide

These are the steps for installing the __IAT system__ in an __AWS__ environment using __Kubernetes__ (K8s).

Before proceeding see [README](README.md).

Confirm you have forked this repository (or copied it) so you can make your change in a secure
environment you control.

## Initial Configuration

Here we will set properties to prepare for the first steps of the installation.

### Steps

1. Open [gradle.properties](gradle.properties)
1. set `encrypt_key`
    * __IMPORTANT__ - The value can be anything, but once set don't change it.
    * The value is used to encrypt secrets. 
    * They are decrypted by the config service.  
    * The key you encrypt with must be the same the config service decrypts with.
1. set `aws_state_store_name`
    * Example: `kops-iat-production-state-store`
1. set `k8s_cluster_name`
    * Example: `ap-iat.smarterbalanced.org`
1. set `k8s_node_zone`
    * Example: `us-west-2a`
1. set `k8s_node_size`
    * Example: `m4.large`
1. set `k8s_master_zone`
    * Example: `us-west-2a`
1. set `k8s_master_size`
    * Example: `m4.large`
1. set `k8s_dns_zone`
    * Example: `iat.smarterbalanced.org`
1. Save changes

## Existing Components

### Item Bank (GitLab)

The IAT system requires GitLab.  The IAT system is configured with a user for interacting with GitLab. 

#### Steps

1. Create an account in GitLab for the IAT system to use.
1. Create an impersonation token for the user.
1. Create a GitLab group.  This represents the item bank the IAT system will use.
1. Give the user access to the group. 
1. Open [gradle.properties](gradle.properties)
1. Set `gitlab_host` to the GitLab host instance 
1. Set `gitlab_group` to the name of the group
1. Set `gitlab_user` to the name of the GitLab user
1. Run `./encrypt.sh {gitlab_access_token}`  - replace with real value
1. Set `gitlab_access_token` to the encrypted value
1. Run `./encrypt.sh {gitlab_password}`  - replace with real value
1. Set `gitlab_password` to the encrypted value
1. Save changes

## SSO (OpenAM)

OpenAM is the SSO provider for the IAT system. 

Public access to the IAT system is done over HTTPS.

### SSL

1. Create a certificate in AWS for the domain the system is going to run under.
1. Open [gradle.properties](gradle.properties)
1. Set `aws_arn_ssl_certificate` to the full ARN of the SSL cert.
    * Example: arn:aws:acm:us-west-2:479572410002:certificate/704d7a65-b9ef-4632-9bef-f47e75892088
1. Save changes

### Generate KeyStore File

A keystore file is used to secure the passwords use in the SAML authentication flow.

#### Steps

We are naming the keystore file __ap-iat-keystore.jks__.  It is important to use this name.

We are using _ap-iat-sp_ as the alias value.  It is important to use this name.

1. Choose two passwords.  *__We will need these for future steps__*.
    * Password 1: key entry password
    * Password 2: key store password 
1. Run `keytool -genkeypair -alias ap-iat-sp -keypass {key entry password} -keystore ap-iat-keystore.jks`
    * the first input after running the keytool command is to enter the **_key store password_**, make sure to enter the 
    key **store** password and not the key **entry** password 
1. Run `openssl s_client -connect sso.smarterbalanced.org:443 > sso.crt`
1. Edit `sso.crt`, delete everything that isn't between (and including) BEGIN/END lines (_the BEGIN/END **should** remain in the file, **do not delete them**_)
1. Import cert into keystore `keytool -import -trustcacerts -alias sso -file ./sso.crt -keystore ./ap-iat-keystore.jks`

You will add `ap-iat-keystore.jks` to the config-repo in a later step.

## AWS Infrastructure

### Create Cluster

Perform the steps from the command line.  You should be in the root of this repository.

#### Steps

1. Run `./install-k8s-cluster.sh`

#### Verify

Verify the cluster is ready.

Run `kops validate cluster {your-cluster-name}`

Between 5 and 10 minutes is the expected time it takes for the cluster to be ready.

### INSTALL K8s Base

Run `./install-k8s-base.sh`

### INSTALL K8s Utilities

The utilities are for monitoring.

Before installing the utilities, __make sure to navigate out of the "deploy" folder__ so you can clone a new Git repository.
We don't want to clone the new repo within the deploy repo.

#### Steps

The steps below ask you to modify the grafana.yaml file.  You will uncomment one line and comment out another line. 
 
1. git clone https://github.com/kubernetes/heapster.git
1. cd heapster
1. vi deploy/kube-config/influxdb/grafana.yaml
```
    - name: GF_SERVER_ROOT_URL
    # If you're only using the API Server proxy, set this value instead:
    value: /api/v1/proxy/namespaces/kube-system/services/monitoring-grafana/
    # value: /
```
4. kubectl create -f deploy/kube-config/influxdb

__*Navigate back to the deploy repo*__. 

## New Components

### ElasticCache Redis

Redis stores user session data.  The data is available to all the services in the IAT system.

Create an ElasticCache Redis instance in AWS.  It must be accessible by the cluster.  

3 replicas is recommended.

Once Redis is available you should have a 'Primary Endpoint'. The endpoint is used to point the IAT system to Redis.

#### Steps

1. Open [gradle.properties](gradle.properties)
1. Set `redis_host` using the primary endpoint, do not include port only the host.  For example set `redis_host=redis.host.on.aws.com` and not `redis_host=redis.host.on.aws.com:6397`    
1. Save changes

### Public URLS

The authoring tool and viewing service require a public URL.  Using the cluster load balancer we will create two 
Route 53 records. 

It is assumed you have an existing hosted zone in AWS.  The Route 53 records to create are done in the hosted zone.

#### Create Route 53 Records

1. Run `kubectl -n kube-system get svc -o wide | grep 'NAME\|nginx-ingress-service'`
    * this gives you the cluster load blancer, copy the external-ip
1. Login to the AWS console
1. Navigate to your Route 53 hosted zone 
1. Create a CNAME record for the authoring tool using the external-ip
    * Example: iat-production.<hosted zone>
1. Create a CNAME record for the viewing service using the external-ip
    * Example: ivs-production.<hosted zone>
1. Open [gradle.properties](gradle.properties)
1. Set `public_host_name_authoring_tool` to the full URL of the __authoring tool__ CNAME.
1. Set `public_host_name_viewing_service` to the full URL of the __viewing service__ CNAME.
1. Save changes

#### Install K8s Ingress

Users need access to the authoring tool and viewing service.  Here we setup the cluster's public entry
point.  

Ingress routes requests to the appropriate service. 

1. Run `./install-k8s-iat-ingress.sh`

### Config Repo

The IAT services store their configuration in a git repository.  Here we will create the repository in GitHub.

This repository is referred to as _**config-repo**_ throughout this document.

#### Steps

1. Create a private GitHub repository for storing the configuration files.
    * Example: `AP_Config_Production`
1. Create a Git user so the IAT system can use it to connect.
1. Run `./gen`
    * *must run the gen script so the next step is setup properly*
1. Add, commit, and push files to master branch of the config-repo:
    * `config-repo/application.yml` 
    * `ap-iat-keystore.jks` (_created in a previous step_)

### Config Service

The config service uses the config-repo created previously.  Here we will deploy the config service to the K8s cluster.

#### Steps

1. Open [gradle.properties](gradle.properties)
1. Set `config_service_repo_url` to the URL of the GitHub repository. 
1. Set `config_service_git_user` to the IAT system user you created. 
1. Set `config_service_git_password` to the password of the IAT system user you created. 
1. Save changes
1. Run `./install-k8s-config-service.sh`

#### Verify 

1. Run `kubectl get pods` to a list of pods.  There is likely only the config service we just installed.  If there are more than one config service pod select any one as it doesn't matter. 
1. Copy the config service pod name, something like `configuration-deployment-2876482002-k6084`
1. Run `kubectl exec -it {pod name} bash --namespace default` where the pod name should be pasted in for {pod name}.  This starts a bash session in the pod.
1. Run `curl http://configuration-service/dummy/default`
1. Confirm curl result is a json object starting with `{"name":"dummy"`.  This shows configurations are being served up successfully. 
1. Run 'exit' to leave the pod.

### Item Management Service (IMS) 

#### Install MySQL on AWS

The MySQL instance must be accessible by the cluster.

There is no schema to install. It is installed automatically by IMS.

##### Parameter Group

Before creating the db instance, create a Parameter Group.

One of the IMS schema steps creates DB function.  To create a DB function on a MySQL AWS RDS instance 
requires a parameter group with the __event_scheduler__ parameter turned __ON__.

```
Create a RDS Parameter Group
Pick mysql5.7 as the parameter group family. 
Edit the group's parameters
Find the parameter 'log_bin_trust_function_creators'
Set its value to 1
Find the parameter 'event_scheduler'
Set its value to ON and save your changes
```

**Changing parameter group values could require a reboot of the database**.  It is helpful to understand when a reboot is required and how to identify its required.  
See [Modifying Parameter Group](http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_WorkingWithParamGroups.html#USER_WorkingWithParamGroups.Modifying)

##### MySQL DB Instance

* `Create a MySQL database instance in AWS, associate it with the parameter group described previously`

* `Version mysql-5-7`

* `Use the default port 3306`

* `When setting up the instance initialize a new database called 'iat'`

* `Create an application database user` - its preferable not to use the root/admin user.

The IAT system creates and maintains the database schema via the item management service (IMS).

When IMS starts up it creates/updates the database schema.  

The database user IMS is configured with must have certain privileges in order to maintain the schema.

* `Give the application database user you just created these privileges`
  * ALTER
  * ALTER ROUTINE
  * CREATE 
  * CREATE ROUTINE
  * CREATE VIEW
  * DELETE
  * DROP
  * EXECUTE
  * INDEX
  * INSERT
  * LOCK TABLES
  * SELECT
  * SHOW DATABASES
  * SHOW VIEW
  * TRIGGER
  * UPDATE    

Once the database instance is available and you have created the application user
proceed with the next steps.  

##### Steps

The Spring Boot CLI is required to execute these steps.  See the tools section.  

Make sure you are in the root of the deploy repo.

When the MySQL instance is available you should have an endpoint for accessing it.  And you 
should have already created the DB app user.

#### Install IMS

1. Run `git clone https://github.com/SmarterApp/AP_ItemManagementService.git`
1. Open `AP_ItemManagementService/deploy/config-repo/ap-ims.yml`
1. Replace all setting values where you see @REPLACE@
    * any property with {cipher} requires the value to be encrypted
1. Add `ap-ims.yml` to the config repo.  It must be added, committed, and pushed to the master branch.
1. Run `./install-k8s-ims.sh`

#### Verify

1. SSH into IMS pod
1. Run `curl localhost:8080/manage/health`
    * UP is expected
1. Run `curl localhost:8080/api/v1/items/workflow-statuses`
    * A JSON array of workflow statuses confirms the database is working

### Item Viewing Service (IVS)

The item viewing service uses a file system shared between it and IRS.  EFS (Elastic File System), is used to create
a shared file system.

#### Install EFS

Create an AWS EFS instance.  Give it a name reflective that it is for the viewing service.  

Assign it to the cluster's VPC. 

Once the instance is created you will have a DNS name for it.

##### Steps

1. Open [gradle.properties](gradle.properties)
1. Set `aws_efs_dns_name` with the DNS name of the EFS instance.
1. Save changes.

#### Install Proxy

1. Run `git clone https://github.com/SmarterApp/AP_ItemViewerProxy.git`
1. Open `AP_ItemViewerProxy/deploy/config-repo/ap-item-viewer-proxy.yml`
1. Replace all setting values where you see @REPLACE@
    * any property with {cipher} requires the value to be encrypted
1. Add the file `ap-item-viewer-proxy.yml` to the config repo.  It must be added, committed, and pushed to the master branch.
1. Run `./install-k8s-item-viewer-proxy.sh`

#### Install IVS

1. Run `./install-k8s-ivs.sh`

#### Install SSO

A service provider needs created in OpenAM for the viewer proxy.

##### Steps

Register SPs in ForgeRock OpenAM

1. Navigate to Federation, Entity Providers
1. Import Entity using the URL 
1. Insert the URL of the IVS public URL - http://{ivs-public-url}/saml/metadata 
1. Add newly created entity to circle-of-trust of the identify provider (IDP)

#### Verify

1. SSH into IVS pod 
1. Run `curl http://localhost:8080/Pages/API/content/reload`
    * a JSON response with "Reload succeed" is expected
1. In a browser navigate to `https://{ivs-public-url}/Pages/API/content/reload`
    * you should have to authenticate
    * a JSON response with "Reload succeed" is expected
    
### Item Rendering Service (IRS)

#### Install 

1. Run `git clone https://github.com/SmarterApp/AP_ItemRenderingService.git`
1. Open `AP_ItemRenderingService/deploy/config-repo/ap-irs.yml`
1. Replace all setting values where you see @REPLACE@
    * any property with {cipher} requires the value to be encrypted
1. Add the file `ap-irs.yml` to the config-repo.  It must be added, committed, and pushed to the master branch.
1. Run `./install-k8s-irs.sh`

#### Verify
1. SSH into pod
1. Run `curl localhost:8080/manage/health`
    * UP is expected

### Item Authoring Tool (IAT) 

#### Install IAT

1. Run `git clone https://github.com/SmarterApp/AP_ItemAuthoringTool.git`
1. Open `AP_ItemAuthoringTool/deploy/config-repo/ap-iat.yml`
1. Replace all setting values where you see @REPLACE@
    * any property with {cipher} requires the value to be encrypted
1. Add `ap-iat.yml` to the config repo.  It must be added, committed, and pushed to the master branch.
1. Run `./install-k8s-iat.sh`

#### Install SSO

A service provider needs created in OpenAM for the authoring tool.

##### Steps

We need to register IAT as a service provider (SP) in ForgeRock OpenAM.  

1. Navigate to Federation, Entity Providers
1. Import Entity using the URL 
1. Insert the URL of the IVS public URL - http://{iat-public-url}/saml/metadata 
1. Add newly created entity to circle-of-trust of the identify provider (IDP)

#### Verify

1. SSH into IAT pod 
1. Run `curl localhost:8080/manage/health`
    * UP is expected
1. In a browser navigate to `https://{iat-public-url}`
    * you should have to authenticate
    * the authoring tool landing page is expected
1. Create an item
1. Preview an item


### Item Reporting Job (IRJ)

The reporting job uses EFS to store an item bank.  All items are pulled down to the EFS instance where IRJ runs
the report against it.

#### Install EFS

Create an AWS EFS instance.  Give it a name reflective that it is for the reporting service.  

Assign it to the cluster's VPC. 

Once the instance is created you will have a DNS name for it.

##### Steps

1. Open [gradle.properties](gradle.properties)
1. Set `aws_efs_report_dns_name` with the DNS name of the EFS instance.
1. Save changes.

#### Install IRJ

##### Steps
1. Run `git clone https://github.com/SmarterApp/AP_ItemReportJob.git`
1. Add `AP_ItemReportJob/deploy/config-repo/ap-item-report-job.yml` to the config repo.  It must be added, committed, and pushed to the master branch.
1. Run `./install-k8s-item-report-job.sh`

#### Verify

1. SSH into pod
1. Run `curl localhost:8080/manage/health`
    * UP is expected
