# Installation Guide

These are the steps for installing the __IAT system__ in an __AWS__ environment using __Kubernetes__ (K8s).

Before proceeding see [README](README.md).

## Fork

Forking the "source" repositories allow you to maintain your settings privately while
still being able to rebase against the "source" to pull in changes.  

The "source" files could add or delete settings, add or remove services, and
update the cluster configuration.  

You can sync your fork with the "source" - see [Syncing a Fork](https://help.github.com/articles/syncing-a-fork/)

Fork these repositories to your dev-ops environment.

* [AP_Deploy](https://github.com/SmarterApp/AP_Deploy.git) - Holds the cluster configuration. 

* [AP_Config](https://github.com/SmarterApp/AP_Config.git) - Holds the micro-service configuration.

## Initial Configuration

Here we will set properties to prepare for the first steps of the installation.

### Steps

1. Open [gradle.properties](gradle.properties)
1. set `encrypt_key`
    * !IMPORTANT! The value can be anything, but once set don't change it.
    * The value is used to encrypt secrets. They are decrypted by the config service.  The key you encrypt
    with must be the same the config service decrypts with.  
1. set `docker_repository`
    * The location the k8s cluster pulls docker images from.  Images like ims, iat, config-service, etc.  
    * Example: `smarterbalanced`
1. set `aws_state_store_name`
    * Example: `kops-iat-stage-state-store`
1. set `k8s_cluster_name`
    * Example: ap-iat.smarterbalanced.org
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
1. set `version_iat`
1. set `version_ims`
1. set `version_irj`
1. set `version_irs`
1. set `version_ivp`
1. set `version_ivs`
1. Save changes

## Existing Components

### Item Bank (GitLab)

The IAT system requires GitLab. 

IAT executes GIT commands like 'push' and 'merge' which require user credentials (username and password).

IAT executes GitLab API calls which requires an access token.

#### Steps

1. Open [gradle.properties](gradle.properties)
1. Run `./gen`
1. Set `gitlab_host` to the GitLab host instance 
1. Set `gitlab_group` to the name of the group
1. Run `sh encrypt.sh {gitlab_access_token}`  - replace with real value
1. Set `gitlab_access_token` to the encrypted value
1. Set `gitlab_user` to the name of the GitLab user
1. Run `sh encrypt.sh {gitlab_password}`  - replace with real value
1. Set `gitlab_password` to the encrypted value
1. Save changes

## SSO (OpenAM)

OpenAM is the identify provider in the SAML SSO configuration.  It must have users authorized to log into the IAT application.

Installers are required access to OpenAM so they can add the IAT service provider.

### Generate KeyStore File

A keystore file is used to secure the passwords use in the SAML authentication flow.

#### Steps

We are naming the keystore file __ap-iat-keystore.jks__.  It is important to keep this name.

We are using _ap-iat-sp_ as the alias value.  It is important to keep this name.

1. Choose two passwords.  We will need these for future steps. We will encrypt and include them in the config-repo.
    * Password 1: key entry password
    * Password 2: key store password 
1. Run `keytool -genkeypair -alias ap-iat-sp -keypass {key entry password} -keystore ap-iat-keystore.jks`
    * the first input after running the keytool command is to enter the **_key store password_**, make sure to enter the 
    key **store** password and not the key **entry** password 
1. Run `openssl s_client -connect sso-amptest.smarterbalanced.org:443 > sso-amptest.crt`
1. Edit `sso-amptest.crt`, delete everything that isn't between (and including) BEGIN/END lines (_the BEGIN/END **should** remain in the file, **do not delete them**_)
1. Import cert into keystore `keytool -import -trustcacerts -alias sso-amptest -file ./sso-amptest.crt -keystore ./ap-iat-keystore.jks`
1. Open [gradle.properties](gradle.properties)
1. Run `./gen`
1. Run `sh encrypt.sh {key entry password}`
1. Set `saml_pke_password` to the encrypted value generated from the **key entry password**
1. Run `sh encrypt.sh {key store password}`
1. Set `saml_ks_password` to the encrypted value generated from the **key store password**
1. Set `saml_pke_alias` to `ap-iat-sp` - this value was used in the keytool command
1. Set `saml_ks_file` to `ap-iat-keystore.jks` - this value was used in the keytool command
1. Set `saml_idp_metadata_url` to the OpenAM metadata URL
1. Set `saml_sp_entity_id_iat` to an logical sp entity ID, for example `ap-iat-stage` 
1. Set `saml_sp_entity_id_ivp` to an logical sp entity ID, for example `ap-ivp-stage`
1. Save changes.
1. Copy keystore file (ap-iat-keystore.jks) to `config-repo` in the Deploy Staging repository.
1. Add and commit config-repo/ap-iat-keystore.jks

## AWS Infrastructure

### Create Cluster

Perform the steps from the command line.  You should be in the root
of this repository.

#### Steps

1. Run `./gen`
1. Run `sh install-k8s-cluster.sh`

#### Verify

Verify the cluster is ready.

Run `kops validate cluster iatstg1.sbtds.org`

Between 5 and 10 minutes is the expected time it takes for the 
cluster to be ready.

### INSTALL K8s Base

Run `sh install-k8s-base.sh`

### INSTALL K8s Utilities

The utilities are for monitoring.

Before installing the utilities, make sure to navigate out of the "deploy" folder so you can clone a new Git repository.
We don't want to clone the new repo within the deploy repo.

#### Steps

The steps below ask you to modify the grafana.yaml file.  You will uncomment one line and comment out another line. 
 
```
git clone https://github.com/kubernetes/heapster.git
cd heapster
vi deploy/kube-config/influxdb/grafana.yaml
...
    - name: GF_SERVER_ROOT_URL
    # If you're only using the API Server proxy, set this value instead:
    value: /api/v1/proxy/namespaces/kube-system/services/monitoring-grafana/
    # value: /
kubectl create -f deploy/kube-config/influxdb
```

Navigate back to the Deploy Staging repository. 

## New Components

### Shared User Sessions (ElasticCache Redis)

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
    * Example: iat-staging.<hosted zone>
1. Create a CNAME record for the viewing service using the external-ip
    * Example: ivs-staging.<hosted zone>
1. Open [gradle.properties](gradle.properties)
1. Set `public_host_name_authoring_tool` to the full URL of the __authoring tool__ CNAME.
1. Set `public_host_name_viewing_service` to the full URL of the __viewing service__ CNAME.
1. Save changes

#### Install K8s Ingress

Users need access to the authoring tool and viewing service.  Here we setup the cluster's public entry
point.  

Ingress routes requests to the appropriate service. 

1. Run `./gen`
1. Run `sh install-k8s-iat-ingress.sh`

### Config Repo

The IAT services store their configuration in a git repository.  Here we will create the repository in GitHub.

#### Steps

1. Create a private GitHub repository for storing the configuration files.
1. Create a user the IAT system will use when connecting to this repository.
1. Open [gradle.properties](gradle.properties)
1. Set `config_service_repo_url` to the URL of the GitHub repository. 
1. Set `config_service_git_user` to the IAT system user you created. 
1. Set `config_service_git_password` to the password of the IAT system user you created. 
1. Save changes
1. Add the file config-repo/dummy.yml to the config repo.  It must be added, committed, and pushed to the master branch.

### Config Service

The config service uses the config repo created previously.  Here we will deploy the config service to the K8s cluster.

#### Steps

1. Open [gradle.properties](gradle.properties)
1. Confirm you are in the root of the Deploy Staging repository.
1. Run `./gen`
1. Run `sh install-k8s-config-service.sh`

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

Make sure you are in the root of the Deploy Staging repository.

When the MySQL instance is available you should have an endpoint for accessing it.  And you 
should have already created the DB app user.

1. Open [gradle.properties](gradle.properties)
1. Set `db_url` to the MySQL endpoint you have from creating the instance.
1. Run `./gen`  (_ensures the next step is ready_)
1. Run `sh encrypt.sh {db user}` substituting {db user} with the db app user you created.
1. Open [gradle.properties](gradle.properties)
1. Set `db_user` with the results of running the encrypt command on the db user.
1. Run `sh encrypt.sh {db password}` substituting {db password} with the db app user's password.
1. Open [gradle.properties](gradle.properties)
1. Set `db_password` with the results of running the encrypt command on the db user password.

#### Install IMS

1. Run `./gen`
1. Add the file config-repo/ap-ims.yml to the config repo.  It must be added, committed, and pushed to the master branch.
1. Run `sh install-k8s-ims.sh`

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

1. Run `./gen`
1. Add the file `config-repo/ap-item-viewer-proxy.yml` to the config repo.  It must be added, committed, and pushed to the master branch.
1. Run `sh install-k8s-item-viewer-proxy.sh`

#### Install IVS

1. Run `./gen`
1. Run `sh install-k8s-ivs.sh`

#### Install SSO

A service provider needs created in OpenAM for the viewer proxy.

##### Steps

Register SPs in ForgeRock OpenAM

1. Run `./gen`
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

1. Run `./gen`
1. Add the file `config-repo/ap-irs.yml` to the config repo.  It must be added, committed, and pushed to the master branch.
1. Run `sh install-k8s-irs.sh`

#### Verify
1. SSH into pod
1. Run `curl localhost:8080/manage/health`
    * UP is expected

### Item Authoring Tool (IAT) 

#### Install IAT


1. Clone https://github.com/SmarterApp/AP_ItemAuthoringTool.git
1. Open  AP_ItemAuthoringTool/deploy/config-repo/ap-iat.yml
1. Replace all setting values where you see @REPLACE@
1. Run `./gen`
1. Add the file `config-repo/ap-iat.yml` to the config repo.  It must be added, committed, and pushed to the master branch.
1. Run `sh install-k8s-iat.sh`

#### Install SSO

A service provider needs created in OpenAM for the authoring tool.

##### Steps

We need to register IAT as a service provider (SP) in ForgeRock OpenAM.  

1. Run `./gen`
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

1. Run `./gen`
1. Add the file `config-repo/ap-item-report-job.yml` to the config repo.  It must be added, committed, and pushed to the master branch.
1. Run `sh install-k8s-item-report-job.sh`

#### Verify

1. SSH into pod
1. Run `curl localhost:8080/manage/health`
    * UP is expected
