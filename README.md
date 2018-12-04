# Packer Test AMI

#### Before you build
- The following packages should be install and available in your PATH.
  - packer
  - awscli
  - jq (optional)
- You must have the AWS permissions required to create an AMI. Packer will look at
  the default location for AWS credentials.
  
#### How to build
- Make sure packer is in your PATH.
- Clone the repo
- Run `./create_ami.sh`.
