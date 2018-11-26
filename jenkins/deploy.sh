#!/bin/bash

set -e

export PYTHONUNBUFFERED=1

echo "$ANSIBLE_VAULT_PASS" > ansible/.ansiblevaultpass
mkdir -p ~/.aws
cat <<EOF > ~/.aws/credentials
[default]
aws_access_key_id = $AWS_ACCESS_KEY
aws_secret_access_key = $AWS_SECRET_KEY
EOF

cat <<EOF > terraform.tfvars
aws_profile             = "default"
aws_region              = "us-east-1"
localip                 = "173.77.205.41/32"
vpc_cidr                = "172.30.0.0/16"
cidrs                   = {
  public1  = "172.30.0.0/20"
  public2  = "172.30.16.0/20"
  private1 = "172.30.64.0/20"
  private2 = "172.30.80.0/20"
}
db_instance_class       = "db.t2.micro"
dbname                  = "$DB_NAME"
dbuser                  = "$DB_USER"
dbpassword              = "$DB_PASS"
key_name                = "master"
public_key_path         = "~/aws.pub"
private_key_path        = "~/aws.pub"
prod_instance_type      = "t2.micro"
prod_ami                = "ami-05aa248bfb1c99d0f"
s3_backups_bucket       = "backups.domain.com"
elb_healthy_threshold   = "2"
elb_unhealthy_threshold = "2"
elb_timeout             = "5"
elb_interval            = "10"
asg_max                 = "4"
asg_min                 = "1"
asg_grace               = "120"
asg_check_type          = "ELB"
lc_instance_type        = "t2.micro"
EOF

cat <<EOF > ~/aws.pub
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDEuPQ3Wg9ZsQpw8bv2jKpI6xuJ/LgjzKWzHR8N+21bEwcsIuzN9gCo1V8AyCIJeXCzROmbo0Be0Y1ffB8xh1yFeL7vOAbUf+B5qId9r9Wvin+l7tDZcsfV2tz/PG/yOCLJe30lFotsQUkRWT1ThBe0dnPDUl4pBlH3I2u3RPkxbybewczz4ajgJrfeT3Emag4hMSMqxiMxAsIvAFzOSB8TMaZ510OcLNT6zxUszA3ZuZnPPwXWCDEE4MHmRZ1vSGrvBfpAN47fMz6i01YkxSCQ+6UHLhigrM9Jkoc2p9LE2IzLuHkLHeuNbD+XhZOLhBLlUgbY0X2ch2Btcz2UDTxp
EOF

./jenkins/refresh_ami.sh

if [[ ! -d .terraform ]]; then
  echo "Initialize terraform..."
  terraform init
  echo "Done!"
fi

terraform apply \
    -target=aws_autoscaling_group.myapp_asg \
    -target=aws_launch_configuration.myapp_lc \
    -auto-approve
