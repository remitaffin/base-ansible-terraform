variable "aws_region" {}
variable "aws_profile" {}
variable "localip" {}
variable "vpc_cidr" {}

variable "cidrs" {
  type = "map"
}

variable "db_instance_class" {}
variable "dbname" {}
variable "dbuser" {}
variable "dbpassword" {}
variable "key_name" {}
variable "public_key_path" {}
variable "private_key_path" {}
variable "prod_instance_type" {}
variable "prod_ami" {}
variable "s3_backups_bucket" {}
variable "elb_healthy_threshold" {}
variable "elb_unhealthy_threshold" {}
variable "elb_timeout" {}
variable "elb_interval" {}
variable "asg_max" {}
variable "asg_min" {}
variable "asg_grace" {}
variable "asg_check_type" {}
variable "lc_instance_type" {}
