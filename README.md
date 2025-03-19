# Deploy Java Application on AWS 3-Tier Architecture

![AWS](https://imgur.com/b9iHwVc.png)

## Table of Contents

1. [Goal](#goal)
2. [Pre-Requisites](#pre-requisites)
3. [Pre-Deployment](#pre-deployment)
4. [VPC Deployment](#vpc-deployment)
5. [Maven (Build)](#maven-build)
6. [3-Tier Architecture](#3-tier-architecture)
7. [Application Deployment](#application-deployment)
8. [Post-Deployment](#post-deployment)
9. [Validation](#validation)

---

![3-tier application](https://imgur.com/3XF0tlJ.png)

---

# Project Overview

## Goal

The primary objective of this project is to deploy a scalable, highly available, and secure Java application using a 3-tier architecture. The application will be hosted on AWS, utilizing various services like EC2, RDS, and VPC to ensure its availability, scalability, and security. The application will be accessible to end-users via the public internet.

# AWS 3-Tier Java Application Deployment Guide

This guide provides step-by-step instructions for deploying a Java application on AWS using a 3-tier architecture. The architecture consists of:
1. Frontend Tier (Nginx)
2. Backend Tier (Apache Tomcat)
3. Database Tier (MySQL RDS)

## Prerequisites

Before starting, ensure you have the following:

1. **AWS Free Tier Account**
   - Sign up at https://aws.amazon.com/free/
   - Install AWS CLI locally and configure with `aws configure`

2. **GitHub Account**
   - Create account at https://github.com/join
   - Fork the Java application from https://github.com/NotHarshhaa/DevOps-Projects/blob/master/DevOps-Project-01/Java-Login-App

3. **SonarCloud Account**
   - Create account at https://sonarcloud.io/
   - Generate a token for GitHub integration

4. **JFrog Cloud Account**
   - Sign up at https://jfrog.com/start-free/
   - Set up a Maven repository

## Step 1: Pre-Deployment

### 1.1 Create Base AMI

1. Launch an EC2 instance with Amazon Linux 2
2. Connect to the instance via SSH
3. Install common agents:

```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update

# Install CloudWatch Agent
sudo yum install amazon-cloudwatch-agent -y
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a start

# Install AWS Systems Manager Agent
sudo yum install amazon-ssm-agent -y
sudo systemctl start amazon-ssm-agent
sudo systemctl enable amazon-ssm-agent
```

4. Create an AMI from this instance (call it "BaseAMI")

### 1.2 Create Nginx AMI

1. Launch an EC2 instance using the BaseAMI
2. Install Nginx:

```bash
sudo yum install nginx -y
sudo systemctl start nginx
sudo systemctl enable nginx
```

3. Create memory usage monitoring script:

```bash
sudo vi /usr/local/bin/memory-monitor.sh
```

Paste the memory monitoring script from the README.

```bash
sudo chmod +x /usr/local/bin/memory-monitor.sh
sudo crontab -e
```

Add the following line to run the script every minute:
```
* * * * * /usr/local/bin/memory-monitor.sh >> /var/log/memory-monitor.log 2>&1
```

4. Create an AMI from this instance (call it "NginxAMI")

### 1.3 Create Tomcat AMI

1. Launch an EC2 instance using the BaseAMI
2. Install Tomcat 9:

```bash
sudo vi /usr/local/bin/install-tomcat.sh
```

Paste the Tomcat installation script from the README.

```bash
sudo chmod +x /usr/local/bin/install-tomcat.sh
sudo /usr/local/bin/install-tomcat.sh
```

3. Create an AMI from this instance (call it "TomcatAMI")

### 1.4 Create Maven AMI

1. Launch an EC2 instance using the BaseAMI
2. Install Maven and Git:

```bash
sudo yum install git maven java-1.8.0-amazon-corretto-devel -y
```

3. Create an AMI from this instance (call it "MavenAMI")

## Step 2: VPC and Network Setup

### 2.1 Create VPCs and Subnets

1. Create two VPCs:

```bash
# Create Application VPC
aws ec2 create-vpc --cidr-block 192.168.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=AppVPC}]' --region us-east-1

# Create Database VPC
aws ec2 create-vpc --cidr-block 172.32.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=DBVPC}]' --region us-east-1
```

2. Create subnets for each VPC:

```bash
# Create public subnets in AppVPC
aws ec2 create-subnet --vpc-id vpc-app-id --cidr-block 192.168.1.0/24 --availability-zone us-east-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=AppPublicSubnet1}]'
aws ec2 create-subnet --vpc-id vpc-app-id --cidr-block 192.168.2.0/24 --availability-zone us-east-1b --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=AppPublicSubnet2}]'

# Create private subnets in AppVPC
aws ec2 create-subnet --vpc-id vpc-app-id --cidr-block 192.168.3.0/24 --availability-zone us-east-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=AppPrivateSubnet1}]'
aws ec2 create-subnet --vpc-id vpc-app-id --cidr-block 192.168.4.0/24 --availability-zone us-east-1b --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=AppPrivateSubnet2}]'

# Create subnets in DBVPC
aws ec2 create-subnet --vpc-id vpc-db-id --cidr-block 172.32.1.0/24 --availability-zone us-east-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=DBSubnet1}]'
aws ec2 create-subnet --vpc-id vpc-db-id --cidr-block 172.32.2.0/24 --availability-zone us-east-1b --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=DBSubnet2}]'
```

### 2.2 Create Internet Gateway and NAT Gateway

1. Create Internet Gateway for AppVPC:

```bash
aws ec2 create-internet-gateway --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=AppIGW}]'
aws ec2 attach-internet-gateway --vpc-id vpc-app-id --internet-gateway-id igw-id
```

2. Create NAT Gateway:

```bash
# Allocate Elastic IP
aws ec2 allocate-address --domain vpc

# Create NAT Gateway in a public subnet
aws ec2 create-nat-gateway --subnet-id subnet-public1-id --allocation-id eipalloc-id --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=AppNATGW}]'
```

### 2.3 Create Route Tables

1. Create and configure route tables for public subnets:

```bash
aws ec2 create-route-table --vpc-id vpc-app-id --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=AppPublicRT}]'
aws ec2 create-route --route-table-id rtb-public-id --destination-cidr-block 0.0.0.0/0 --gateway-id igw-id
aws ec2 associate-route-table --subnet-id subnet-public1-id --route-table-id rtb-public-id
aws ec2 associate-route-table --subnet-id subnet-public2-id --route-table-id rtb-public-id
```

2. Create and configure route tables for private subnets:

```bash
aws ec2 create-route-table --vpc-id vpc-app-id --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=AppPrivateRT}]'
aws ec2 create-route --route-table-id rtb-private-id --destination-cidr-block 0.0.0.0/0 --nat-gateway-id natgw-id
aws ec2 associate-route-table --subnet-id subnet-private1-id --route-table-id rtb-private-id
aws ec2 associate-route-table --subnet-id subnet-private2-id --route-table-id rtb-private-id
```

### 2.4 Create Transit Gateway

1. Create Transit Gateway:

```bash
aws ec2 create-transit-gateway --description "Transit Gateway for connection between VPCs" --tag-specifications 'ResourceType=transit-gateway,Tags=[{Key=Name,Value=AppDBTGW}]'
```

2. Attach VPCs to Transit Gateway:

```bash
aws ec2 create-transit-gateway-vpc-attachment --transit-gateway-id tgw-id --vpc-id vpc-app-id --subnet-ids subnet-private1-id subnet-private2-id --tag-specifications 'ResourceType=transit-gateway-attachment,Tags=[{Key=Name,Value=AppVPCAttachment}]'

aws ec2 create-transit-gateway-vpc-attachment --transit-gateway-id tgw-id --vpc-id vpc-db-id --subnet-ids subnet-db1-id subnet-db2-id --tag-specifications 'ResourceType=transit-gateway-attachment,Tags=[{Key=Name,Value=DBVPCAttachment}]'
```

3. Update route tables to use Transit Gateway:

```bash
# App VPC private route table
aws ec2 create-route --route-table-id rtb-private-id --destination-cidr-block 172.32.0.0/16 --transit-gateway-id tgw-id

# DB VPC route table
aws ec2 create-route-table --vpc-id vpc-db-id --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=DBPrivateRT}]'
aws ec2 create-route --route-table-id rtb-db-id --destination-cidr-block 192.168.0.0/16 --transit-gateway-id tgw-id
aws ec2 associate-route-table --subnet-id subnet-db1-id --route-table-id rtb-db-id
aws ec2 associate-route-table --subnet-id subnet-db2-id --route-table-id rtb-db-id
```

### 2.5 Create Security Groups

1. Create security group for Bastion Host:

```bash
aws ec2 create-security-group --group-name BastionSG --description "Security group for Bastion Host" --vpc-id vpc-app-id --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=BastionSG}]'
aws ec2 authorize-security-group-ingress --group-id sg-bastion-id --protocol tcp --port 22 --cidr YOUR_IP/32
```

2. Create security group for Nginx:

```bash
aws ec2 create-security-group --group-name NginxSG --description "Security group for Nginx servers" --vpc-id vpc-app-id --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=NginxSG}]'
aws ec2 authorize-security-group-ingress --group-id sg-nginx-id --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id sg-nginx-id --protocol tcp --port 443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id sg-nginx-id --protocol tcp --port 22 --source-group sg-bastion-id
```

3. Create security group for Tomcat:

```bash
aws ec2 create-security-group --group-name TomcatSG --description "Security group for Tomcat servers" --vpc-id vpc-app-id --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=TomcatSG}]'
aws ec2 authorize-security-group-ingress --group-id sg-tomcat-id --protocol tcp --port 8080 --source-group sg-nginx-id
aws ec2 authorize-security-group-ingress --group-id sg-tomcat-id --protocol tcp --port 22 --source-group sg-bastion-id
```

4. Create security group for RDS:

```bash
aws ec2 create-security-group --group-name RDSSG --description "Security group for RDS" --vpc-id vpc-db-id --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=RDSSG}]'
aws ec2 authorize-security-group-ingress --group-id sg-rds-id --protocol tcp --port 3306 --source-group sg-tomcat-id
```

### 2.6 Create Bastion Host

```bash
aws ec2 run-instances --image-id ami-amazonlinux2 --count 1 --instance-type t2.micro --key-name MyKeyPair --security-group-ids sg-bastion-id --subnet-id subnet-public1-id --associate-public-ip-address --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=BastionHost}]'
```

## Step 3: Database Tier Setup

### 3.1 Create RDS Subnet Group

```bash
aws rds create-db-subnet-group --db-subnet-group-name db-subnet-group --db-subnet-group-description "DB subnet group" --subnet-ids subnet-db1-id subnet-db2-id --tags 'Key=Name,Value=DBSubnetGroup'
```

### 3.2 Create RDS Instance

```bash
aws rds create-db-instance --db-instance-identifier mydbinstance --db-instance-class db.t2.micro --engine mysql --engine-version 8.0 --allocated-storage 20 --master-username admin --master-user-password YourPassword123 --vpc-security-group-ids sg-rds-id --db-subnet-group-name db-subnet-group --availability-zone us-east-1a --backup-retention-period 7 --port 3306 --multi-az --tags 'Key=Name,Value=AppDB'
```

## Step 4: Build and Deploy Application

### 4.1 Set Up Maven Build Server

1. Launch an EC2 instance using the MavenAMI:

```bash
aws ec2 run-instances --image-id ami-maven-id --count 1 --instance-type t2.micro --key-name MyKeyPair --security-group-ids sg-bastion-id --subnet-id subnet-public1-id --associate-public-ip-address --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MavenBuildServer}]'
```

2. Connect to the instance via Bastion Host and clone the repository:

```bash
ssh -i MyKeyPair.pem ec2-user@bastion-public-ip
ssh -i MyKeyPair.pem ec2-user@maven-private-ip
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
cd YOUR_REPO
```

3. Update `pom.xml` with SonarCloud and JFrog details:

```xml
<properties>
    <sonar.projectKey>YOUR_PROJECT_KEY</sonar.projectKey>
    <sonar.organization>YOUR_ORGANIZATION</sonar.organization>
    <sonar.host.url>https://sonarcloud.io</sonar.host.url>
</properties>

<distributionManagement>
    <repository>
        <id>jfrog-repository</id>
        <name>JFrog Maven Repository</name>
        <url>https://YOUR_JFROG_REPO_URL/artifactory/maven-releases</url>
    </repository>
</distributionManagement>
```

4. Create `settings.xml` for Maven:

```xml
<settings>
    <servers>
        <server>
            <id>jfrog-repository</id>
            <username>YOUR_JFROG_USERNAME</username>
            <password>YOUR_JFROG_PASSWORD</password>
        </server>
    </servers>
</settings>
```

5. Build the application:

```bash
mvn clean install -s settings.xml
```

6. Run SonarCloud analysis:

```bash
mvn sonar:sonar -Dsonar.login=YOUR_SONAR_TOKEN
```

7. Deploy to JFrog:

```bash
mvn deploy -s settings.xml
```

### 4.2 Set Up Backend Tier (Tomcat)

1. Create a launch template for Tomcat instances:

```bash
aws ec2 create-launch-template --launch-template-name TomcatLaunchTemplate --version-description "Initial version" --launch-template-data '{"ImageId":"ami-tomcat-id","InstanceType":"t2.micro","KeyName":"MyKeyPair","SecurityGroupIds":["sg-tomcat-id"],"UserData":"#!/bin/bash\naws s3 cp s3://mybucket/tomcat-setup.sh /tmp/\nchmod +x /tmp/tomcat-setup.sh\n/tmp/tomcat-setup.sh","TagSpecifications":[{"ResourceType":"instance","Tags":[{"Key":"Name","Value":"TomcatServer"}]}]}'
```

2. Create an Auto Scaling Group for Tomcat:

```bash
aws autoscaling create-auto-scaling-group --auto-scaling-group-name TomcatASG --launch-template "LaunchTemplateName=TomcatLaunchTemplate,Version=1" --min-size 2 --max-size 4 --desired-capacity 2 --vpc-zone-identifier "subnet-private1-id,subnet-private2-id" --target-group-arns "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/tomcat-tg/abcdef1234567890" --health-check-type ELB --health-check-grace-period 300
```

3. Create a Network Load Balancer for Tomcat:

```bash
aws elbv2 create-load-balancer --name TomcatNLB --scheme internal --type network --subnets subnet-private1-id subnet-private2-id --tags Key=Name,Value=TomcatNLB
```

4. Create a target group for Tomcat:

```bash
aws elbv2 create-target-group --name tomcat-tg --protocol TCP --port 8080 --vpc-id vpc-app-id --target-type instance --health-check-protocol TCP --health-check-port 8080
```

5. Create a listener for the NLB:

```bash
aws elbv2 create-listener --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/TomcatNLB/abcdef1234567890 --protocol TCP --port 8080 --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/tomcat-tg/abcdef1234567890
```

### 4.3 Set Up Frontend Tier (Nginx)

1. Create a launch template for Nginx instances:

```bash
aws ec2 create-launch-template --launch-template-name NginxLaunchTemplate --version-description "Initial version" --launch-template-data '{"ImageId":"ami-nginx-id","InstanceType":"t2.micro","KeyName":"MyKeyPair","SecurityGroupIds":["sg-nginx-id"],"UserData":"#!/bin/bash\naws s3 cp s3://mybucket/nginx-setup.sh /tmp/\nchmod +x /tmp/nginx-setup.sh\n/tmp/nginx-setup.sh","TagSpecifications":[{"ResourceType":"instance","Tags":[{"Key":"Name","Value":"NginxServer"}]}]}'
```

2. Create an Auto Scaling Group for Nginx:

```bash
aws autoscaling create-auto-scaling-group --auto-scaling-group-name NginxASG --launch-template "LaunchTemplateName=NginxLaunchTemplate,Version=1" --min-size 2 --max-size 4 --desired-capacity 2 --vpc-zone-identifier "subnet-public1-id,subnet-public2-id" --target-group-arns "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/nginx-tg/abcdef1234567890" --health-check-type ELB --health-check-grace-period 300
```

3. Create a Network Load Balancer for Nginx:

```bash
aws elbv2 create-load-balancer --name NginxNLB --scheme internet-facing --type network --subnets subnet-public1-id subnet-public2-id --tags Key=Name,Value=NginxNLB
```

4. Create a target group for Nginx:

```bash
aws elbv2 create-target-group --name nginx-tg --protocol TCP --port 80 --vpc-id vpc-app-id --target-type instance --health-check-protocol TCP --health-check-port 80
```

5. Create a listener for the NLB:

```bash
aws elbv2 create-listener --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/NginxNLB/abcdef1234567890 --protocol TCP --port 80 --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/nginx-tg/abcdef1234567890
```

## Step 5: Configuration Files

### 5.1 Create Tomcat Setup Script

Create a file named `tomcat-setup.sh` and upload it to S3:

```bash
#!/bin/bash

# Download war file from JFrog
aws s3 cp s3://mybucket/credentials.properties /opt/tomcat9/conf/

# Create context.xml with database connection
cat > /opt/tomcat9/conf/context.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<Context>
    <Resource name="jdbc/mydb" auth="Container" type="javax.sql.DataSource"
              maxTotal="100" maxIdle="30" maxWaitMillis="10000"
              username="admin" password="YourPassword123" driverClassName="com.mysql.cj.jdbc.Driver"
              url="jdbc:mysql://mydbinstance.123456789012.us-east-1.rds.amazonaws.com:3306/mydatabase"/>
</Context>
EOF

# Download war file from JFrog
curl -u YOUR_JFROG_USERNAME:YOUR_JFROG_PASSWORD https://YOUR_JFROG_REPO_URL/artifactory/maven-releases/com/example/myapp/1.0/myapp-1.0.war -o /opt/tomcat9/webapps/ROOT.war

# Restart Tomcat
systemctl restart tomcat
```

### 5.2 Create Nginx Setup Script

Create a file named `nginx-setup.sh` and upload it to S3:

```bash
#!/bin/bash

# Configure Nginx
cat > /etc/nginx/conf.d/app.conf << EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://internal-TomcatNLB-1234567890.us-east-1.elb.amazonaws.com:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Restart Nginx
systemctl restart nginx
```

## Step 6: Setup Monitoring and Logging

### 6.1 Create CloudWatch Alarms

1. Create an alarm for high CPU utilization:

```bash
aws cloudwatch put-metric-alarm --alarm-name HighCPUUtilization --alarm-description "Alarm when CPU exceeds 80%" --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 300 --threshold 80 --comparison-operator GreaterThanThreshold --dimensions Name=AutoScalingGroupName,Value=TomcatASG --evaluation-periods 2 --alarm-actions arn:aws:sns:us-east-1:123456789012:AlertTopic
```

2. Create an alarm for database connections:

```bash
aws cloudwatch put-metric-alarm --alarm-name DBConnectionsHigh --alarm-description "Alarm when DB connections exceed 100" --metric-name DatabaseConnections --namespace AWS/RDS --statistic Average --period 300 --threshold 100 --comparison-operator GreaterThanOrEqualToThreshold --dimensions Name=DBInstanceIdentifier,Value=mydbinstance --evaluation-periods 1 --alarm-actions arn:aws:sns:us-east-1:123456789012:AlertTopic
```

### 6.2 Configure S3 for Logs

1. Create an S3 bucket for logs:

```bash
aws s3 mb s3://myapp-logs-bucket
```

2. Create a cron job to push logs to S3:

```bash
crontab -e
```

Add the following entry:

```
0 0 * * * /usr/bin/aws s3 cp /opt/tomcat9/logs s3://myapp-logs-bucket/tomcat-logs/$(date +\%Y-\%m-\%d)/ --recursive --region us-east-1 && rm -rf /opt/tomcat9/logs/catalina.out
```

## Step 7: Test and Validate

1. Get the DNS name of the public NLB:

```bash
aws elbv2 describe-load-balancers --names NginxNLB --query 'LoadBalancers[0].DNSName' --output text
```

2. Access the application using the NLB DNS name in a web browser.

3. Validate SSH access to EC2 instances via the Bastion Host:

```bash
ssh -i MyKeyPair.pem ec2-user@bastion-public-ip
ssh -i MyKeyPair.pem ec2-user@target-private-ip
```

4. Verify database connectivity:

```bash
mysql -h mydbinstance.123456789012.us-east-1.rds.amazonaws.com -u admin -p
```

5. Check CloudWatch metrics and logs to ensure everything is working properly.

## Conclusion

You have successfully deployed a Java application on AWS using a 3-tier architecture. The application is now:
- Highly available through multiple AZs
- Scalable via Auto Scaling Groups
- Secure with proper network segmentation and security groups
- Monitored with CloudWatch alarms and logging

Remember to regularly review and update your infrastructure to maintain security and performance.
