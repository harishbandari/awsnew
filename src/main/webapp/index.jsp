<html>
<body>
<h2>Hello World!</h2>

{
  "AWSTemplateFormatVersion" : "2010-09-09",
  
  "Description" : "CloudFormation Template to provision a Jenkins instance",
  
  "Parameters" : {
      
    "KeyName" : {
      "Description" : "Name of an existing EC2 KeyPair to enable SSH access to the instances",
      "Type" : "String",
	  "Default" : "harish1",
      "MinLength": "1",
      "MaxLength": "64",
      "AllowedPattern" : "[-_ a-zA-Z0-9]*",
      "ConstraintDescription" : "can contain only alphanumeric characters, spaces, dashes and underscores."
    },

    "InstanceType" : {
      "Description" : "WebServer EC2 instance type",
      "Type" : "String",
      "Default" : "t2.micro",
      "AllowedValues" : [ "t2.micro"],
      "ConstraintDescription" : "must be a valid EC2 instance type."
    }
  
  },
  
  "Mappings" : {
    "AWSInstanceType2Arch" : {
      "t2.micro"    : { "Arch" : "64" },
      "m1.small"    : { "Arch" : "32" },
      "m1.large"    : { "Arch" : "64" },
      "m1.xlarge"   : { "Arch" : "64" },
      "m2.xlarge"   : { "Arch" : "64" },
      "m2.2xlarge"  : { "Arch" : "64" },
      "m2.4xlarge"  : { "Arch" : "64" },
      "c1.medium"   : { "Arch" : "32" },
      "c1.xlarge"   : { "Arch" : "64" },
      "cc1.4xlarge" : { "Arch" : "64" }
    },
    "AWSRegionArch2AMI" : {
      "us-east-1"      : { "32" : "ami-b73b63a0)", "64" : "ami-b73b63a0" },
      "us-west-1"      : { "32" : "ami-951945d0", "64" : "ami-971945d2" },
      "us-west-2"      : { "32" : "ami-16fd7026", "64" : "ami-10fd7020" },
      "eu-west-1"      : { "32" : "ami-24506250", "64" : "ami-20506254" },
      "ap-southeast-1" : { "32" : "ami-74dda626", "64" : "ami-7edda62c" },
      "ap-northeast-1" : { "32" : "ami-dcfa4edd", "64" : "ami-e8fa4ee9" }
    }
  },
    
  "Resources" : {     
      
    "CfnUser" : {
      "Type" : "AWS::IAM::User",
      "Properties" : {
        "Path": "/",
        "Policies": [{
          "PolicyName": "root",
          "PolicyDocument": { "Statement":[{
            "Effect":"Allow",
            "Action":"cloudformation:DescribeStackResource",
            "Resource":"*"
          }]}
        }]
      }
    },

    "HostKeys" : {
      "Type" : "AWS::IAM::AccessKey",
	  "Default" : "2ccnNQAKF4JaKagDySQ3SkL7Q42iG3J+nJ8TuzUT"
      "Properties" : {
        "UserName" : {"Ref": "CfnUser"}
      }
    },

    "WebServer": {  
      "Type": "AWS::EC2::Instance",
      "Metadata" : {
        "AWS::CloudFormation::Init" : {
          "config" : {
            "packages" : {
              "yum" : {
                "java-1.6.0-openjdk"    : [],
                "tomcat7"   			: []
              }
            },

			"files" : {
	          "/usr/share/tomcat7/webapps/jenkins.war" : { 
		        "source" : "http://mirrors.jenkins-ci.org/war-rc/latest/jenkins.war", 
		        "mode" : "000500", 
		        "owner" : "tomcat7",
		        "group" : "tomcat7" 
		      }
		    },

            "services" : { 
			  "sysvinit" : {
				"tomcat7" : { 
				  "enabled" : "true", 
				  "ensureRunning" : "true" ,
			      "sources" : ["/usr/share/tomcat7/webapps"]
				}
			  }
		    }
          }
        }
      },
      "Properties": {
        "ImageId" : { "Fn::FindInMap" : [ "AWSRegionArch2AMI", { "Ref" : "AWS::Region" },
                          { "Fn::FindInMap" : [ "AWSInstanceType2Arch", { "Ref" : "InstanceType" }, "Arch" ] } ] },
        "InstanceType"   : { "Ref" : "InstanceType" },
        "SecurityGroups" : [ {"Ref" : "FrontendGroup"} ],
        "KeyName"        : { "Ref" : "KeyName" },
        "UserData"       : { "Fn::Base64" : { "Fn::Join" : ["", [
          "#!/bin/bash -v\n",
          "yum update -y aws-cfn-bootstrap\n",

          "# Install packages\n",
          "/opt/aws/bin/cfn-init -s ", 
		  "       --stack  ",{ "Ref" : "AWS::StackName" }, 
		  "     --resource WebServer ",
          "    --access-key ",  { "Ref" : "HostKeys" },
          "    --secret-key ", {"Fn::GetAtt": ["HostKeys", "SecretAccessKey"]},
          "    --region ", { "Ref" : "AWS::Region" }, "\n" " || error_exit 'Failed to run cfn-init'\n",

		  "chown -R tomcat:tomcat /usr/share/tomcat7/\n",
		  "service tomcat7 start"
        ]]}}        
      }
    },
	

    "IPAddress" : {
      "Type" : "AWS::EC2::EIP"
    },
    
    "IPAssoc" : {
      "Type" : "AWS::EC2::EIPAssociation",
      "Properties" : {
        "InstanceId" : { "Ref" : "WebServer" },
        "EIP" : { "Ref" : "IPAddress" }
       }
    },
    
    "FrontendGroup" : {
      "Type" : "AWS::EC2::SecurityGroup",
      "Properties" : {
        "GroupDescription" : "Enable SSH and access to Apache and Tomcat",
        "SecurityGroupIngress" : [
          {"IpProtocol" : "tcp", "FromPort" : "22", "ToPort" : "22", "CidrIp" : "0.0.0.0/0"},
	      {"IpProtocol" : "tcp", "FromPort" : "80", "ToPort" : "80", "CidrIp" : "0.0.0.0/0"},
		  {"IpProtocol" : "tcp", "FromPort" : "8080", "ToPort" : "8080", "CidrIp" : "0.0.0.0/0"}
        ]
      }      
    }          
  },
  
  "Outputs" : {
    "ApacheSite" : {
      "Value" : { "Fn::Join" : ["", ["http://", { "Ref" : "IPAddress" }]] },
      "Description" : "URL for newly created Apache Test website"
    },
    "InstanceIPAddress" : {
      "Value" : { "Ref" : "IPAddress" }
    }
  }
}
</body>
</html>
