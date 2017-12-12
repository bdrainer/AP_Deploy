# Item Authoring Deployment
 
* [Installation Guide](InstallationGuide.md) - installing the IAT system  

* [Maintenance Guide](MaintenanceGuide.md) - maintenance releases and upgrades   

## Before Starting

### Docker Repository

The IAT system is made up of docker images.  The K8s cluster pulls these images from docker hub.

Installation and maintenance requires a docker hub repository. 

The scripts are configured with a default repository of `smarterbalanced`.  You can change this. 

### AWS Region

https://aws.amazon.com/about-aws/global-infrastructure/regional-product-services/

It is required to use an AWS region that supports EFS as not all regions do.

EFS is limited to three regions: 
* us-east-2 US East (Ohio)	
* us-east-1 US East (N. Virginia)	
* us-west-2 US West (Oregon)

### Admin Account on AWS

An AWS account is required.  The account should have access to the console.

The account must have these permissions at the least.

```
AmazonEC2FullAccess
AmazonRoute53FullAccess
AmazonS3FullAccess
IAMFullAccess
AmazonVPCFullAccess
```

### Tools

The following tools are required to perform the installation.

The docs ['Installing Kubernetes on AWS with kops'](https://kubernetes.io/docs/getting-started-guides/kops/)
and [Kubernetes kops](https://github.com/kubernetes/kops/blob/master/docs/aws.md) are worth reading.

They describe a lot of what is required to run/install Kubernetes on AWS.

#### kops

Before we can bring up the cluster we need to [install the CLI tool `kops`](https://github.com/kubernetes/kops/blob/master/docs/install.md) .

#### kubectl

In order to control Kubernetes clusters we need to [install the CLI tool `kubectl`](https://kubernetes.io/docs/tasks/tools/install-kubectl/).

#### AWS CLI

The [aws guide](http://docs.aws.amazon.com/cli/latest/userguide/awscli-install-linux.html).

### S3 Bucket 

An S3 bucket is required.  It is the Kubernetes state store.

Kops needs a state store to store cluster information.

The S3 bucket is used when running ```kops``` commands.

### Registered Domain / Hosted Zone

The item authoring tool and item viewing service require public URLs.

A registered domain (e.g. hosted zone) in AWS is required.  

An example of a registered domain is "smarterbalanced.org".  

### Register SSL Certificate for Domain

The item authoring tool and item viewing service require HTTPS.

### Spring Boot CLI

Secrets are encrypted in the YAML config files served by the configuration service.

The spring boot cli is used to encrypt secrets.  For example: `spring encrypt --key=secret foo`

https://docs.spring.io/spring-boot/docs/current/reference/html/getting-started-installing-spring-boot.html 
* see section 'Installing the Spring Boot CLI'  
* install the cloud plugin: `spring install org.springframework.cloud:spring-cloud-cli:1.3.2.RELEASE`

## Architecture

![System Architecture](/images/system-architecture.png)