provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

data "aws_availability_zones" "available" {}

#-------------VPC-----------

resource "aws_vpc" "myapp_vpc" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags {
    Name = "myapp_vpc"
  }
}

# Internet gateway

resource "aws_internet_gateway" "myapp_internet_gateway" {
  vpc_id = "${aws_vpc.myapp_vpc.id}"

  tags {
    Name = "myapp_igw"
  }
}

# Route tables

resource "aws_route_table" "myapp_public_rt" {
  vpc_id = "${aws_vpc.myapp_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.myapp_internet_gateway.id}"
  }

  tags {
    Name = "myapp_public"
  }
}

resource "aws_default_route_table" "myapp_private_rt" {
  default_route_table_id = "${aws_vpc.myapp_vpc.default_route_table_id}"

  tags {
    Name = "myapp_private"
  }
}

resource "aws_subnet" "myapp_public1_subnet" {
  vpc_id                  = "${aws_vpc.myapp_vpc.id}"
  cidr_block              = "${var.cidrs["public1"]}"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "myapp_public1"
  }
}

resource "aws_subnet" "myapp_public2_subnet" {
  vpc_id                  = "${aws_vpc.myapp_vpc.id}"
  cidr_block              = "${var.cidrs["public2"]}"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "myapp_public2"
  }
}

resource "aws_subnet" "myapp_private1_subnet" {
  vpc_id                  = "${aws_vpc.myapp_vpc.id}"
  cidr_block              = "${var.cidrs["private1"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "myapp_private1"
  }
}

resource "aws_subnet" "myapp_private2_subnet" {
  vpc_id                  = "${aws_vpc.myapp_vpc.id}"
  cidr_block              = "${var.cidrs["private2"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "myapp_private2"
  }
}

# Subnet Associations

resource "aws_route_table_association" "myapp_public_assoc" {
  subnet_id      = "${aws_subnet.myapp_public1_subnet.id}"
  route_table_id = "${aws_route_table.myapp_public_rt.id}"
}

resource "aws_route_table_association" "myapp_public2_assoc" {
  subnet_id      = "${aws_subnet.myapp_public2_subnet.id}"
  route_table_id = "${aws_route_table.myapp_public_rt.id}"
}

resource "aws_db_subnet_group" "myapp_rds_subnetgroup" {
  name = "myapp_rds_subnetgroup"

  subnet_ids = ["${aws_subnet.myapp_private1_subnet.id}",
    "${aws_subnet.myapp_private2_subnet.id}",
  ]

  tags {
    Name = "myapp_rds_sng"
  }
}

# Create EC2 Role (aka Instance profiles) and Policy
resource "aws_iam_role" "ec2_role" {
  name = "EC2_COMMON_ROLE"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "write_only_backups_s3" {
  name        = "WRITE_ONLY_TO_BACKUPS_BUCKET"
  description = "Write-only access to ${var.s3_backups_bucket}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1416670692010",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:ListBucketMultipartUploads",
        "s3:ListMultipartUploadParts",
        "s3:AbortMultipartUpload"
      ],
      "Resource": [
        "arn:aws:s3:::${var.s3_backups_bucket}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "attachment_push_to_cloudwatch" {
  role       = "${aws_iam_role.ec2_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "attachment_write_only_backups_s3" {
  role       = "${aws_iam_role.ec2_role.name}"
  policy_arn = "${aws_iam_policy.write_only_backups_s3.arn}"
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = "${aws_iam_role.ec2_role.name}"
}

# Security groups

# Prod Jenkins SG
resource "aws_security_group" "jenkins_prod_sg" {
  name        = "JENKINS_CI"
  description = "Used for access to the prod jenkins instance"
  vpc_id      = "${aws_vpc.myapp_vpc.id}"

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.localip}"]
  }

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ELB SG
resource "aws_security_group" "myapp_elb_sg" {
  name        = "myapp_PROD_ELB"
  description = "Used for public load balancer"
  vpc_id      = "${aws_vpc.myapp_vpc.id}"

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Prod myapp SG
resource "aws_security_group" "myapp_prod_sg" {
  name        = "PROD_myapp"
  description = "Used for access to the prod instance"
  vpc_id      = "${aws_vpc.myapp_vpc.id}"

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.localip}"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = ["${aws_security_group.jenkins_prod_sg.id}"]
  }

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.localip}"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = ["${aws_security_group.myapp_elb_sg.id}"]
  }

  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS Security Group
resource "aws_security_group" "myapp_rds_sg" {
  name        = "PROD_myapp_RDS"
  description = "Used for MySQL RDS instances"
  vpc_id      = "${aws_vpc.myapp_vpc.id}"

  # MySQL
  ingress {
    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"
    security_groups = ["${aws_security_group.myapp_prod_sg.id}"]
  }
  ingress {
    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"
    security_groups = ["${aws_security_group.jenkins_prod_sg.id}"]
  }

  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#--------- Compute -----------

resource "aws_db_instance" "myapp_db" {
  identifier                      = "prod-myapp-mysql"
  allocated_storage               = 10
  engine                          = "mysql"
  engine_version                  = "5.7.23"
  instance_class                  = "${var.db_instance_class}"
  name                            = "${var.dbname}"
  username                        = "${var.dbuser}"
  password                        = "${var.dbpassword}"
  db_subnet_group_name            = "${aws_db_subnet_group.myapp_rds_subnetgroup.name}"
  vpc_security_group_ids          = ["${aws_security_group.myapp_rds_sg.id}"]
  skip_final_snapshot             = true
  publicly_accessible             = false
  auto_minor_version_upgrade      = false
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]
  backup_retention_period         = 7
  backup_window                   = "08:00-08:30" # UTC
  apply_immediately               = true

  # To improve High Availability purposes, we could create a read replica in a
  # separate Availability Zone using the option below (multi_az).
  # However, since the multi-AZ feature is not on the free tier, I kept this
  # commented out. It can easily be changed if required.
  # multi_az               = false
}

# Key pair
resource "aws_key_pair" "master_key_pair" {
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

# Launch jenkins server
resource "aws_instance" "jenkins" {
  instance_type = "${var.prod_instance_type}"
  ami           = "${var.prod_ami}"

  tags {
    Name = "jenkins"
  }

  key_name               = "${aws_key_pair.master_key_pair.id}"
  vpc_security_group_ids = ["${aws_security_group.jenkins_prod_sg.id}"]
  iam_instance_profile   = "${aws_iam_instance_profile.ec2_instance_profile.id}"
  subnet_id              = "${aws_subnet.myapp_public1_subnet.id}"

  # Create volume for temporary backups
  # The volume would ideally be an instance store/ephemeral type,
  # but t2.micro doesn't give any ephemeral storage.
  # Upgrading the instance type would allow me to use ephemeral type, but in
  # order to stay in Amazon's free tier, I will keep using t2.micro.
  ebs_block_device {
    device_name = "/dev/sdb"
    volume_type = "gp2"
    volume_size = 2
  }
  # Create volume for jenkins data
  ebs_block_device {
    device_name = "/dev/sdf"
    volume_type = "gp2"
    volume_size = 5
  }

  provisioner "local-exec" {
    command = <<EOD
cat <<EOF > ansible/aws_hosts
[jenkins]
${self.public_ip}
EOF
EOD
  }

  provisioner "local-exec" {
    command = "aws ec2 wait instance-status-ok --instance-ids ${self.id} --profile ${var.aws_profile} --region ${var.aws_region}"
  }

  # Python-minimal is required to run ansible
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get install -y python-minimal"
    ]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file(var.private_key_path)}"
    }
  }

  provisioner "local-exec" {
    command = "cd ansible && ansible-playbook -i aws_hosts jenkins.yml --extra-vars 'hostgroup=jenkins' --vault-password-file .ansiblevaultpass --private-key ${var.private_key_path}"
  }
}

# Load balancer

resource "aws_elb" "myapp_elb" {
  name = "myapp-elb"

  subnets = [
    "${aws_subnet.myapp_public1_subnet.id}",
    "${aws_subnet.myapp_public2_subnet.id}",
  ]

  security_groups = ["${aws_security_group.myapp_elb_sg.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = "${var.elb_healthy_threshold}"
    unhealthy_threshold = "${var.elb_unhealthy_threshold}"
    timeout             = "${var.elb_timeout}"
    target              = "TCP:80"
    interval            = "${var.elb_interval}"
  }

  instances                   = []
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags {
    Name = "myapp-elb"
  }
}

# S3
resource "aws_s3_bucket" "s3_backups_bucket" {
  bucket = "${var.s3_backups_bucket}"
  acl    = "private"

  lifecycle_rule {
    id      = "jenkins_backup_lifecycle"
    enabled = true
    prefix  = "jenkins/"

    tags {
      "rule" = "jenkins_backup_lifecycle"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }

    expiration {
      days = 90
    }
  }
}

# Launch configuration

data "aws_ami" "latest_packer_ami" {
  filter {
    name   = "state"
    values = ["available"]
  }
  filter {
    name   = "tag:Name"
    values = ["Packer-Ansible"]
  }
  most_recent = true
  owners      = ["self"]
}

resource "aws_launch_configuration" "myapp_lc" {
  name_prefix          = "myapp_lc-"
  image_id             = "${data.aws_ami.latest_packer_ami.id}"
  instance_type        = "${var.lc_instance_type}"
  security_groups      = ["${aws_security_group.myapp_prod_sg.id}"]
  iam_instance_profile = "${aws_iam_instance_profile.ec2_instance_profile.id}"
  key_name             = "${aws_key_pair.master_key_pair.id}"

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Groups

resource "aws_autoscaling_group" "myapp_asg" {
  name                      = "asg-${aws_launch_configuration.myapp_lc.id}"
  max_size                  = "${var.asg_max}"
  min_size                  = "${var.asg_min}"
  health_check_grace_period = "${var.asg_grace}"
  health_check_type         = "${var.asg_check_type}"
  force_delete              = true
  wait_for_elb_capacity     = 1
  load_balancers            = ["${aws_elb.myapp_elb.id}"]
  enabled_metrics           = [
    "GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity",
    "GroupInServiceInstances", "GroupPendingInstances",
    "GroupStandbyInstances", "GroupTerminatingInstances",
    "GroupTotalInstances"
  ]

  vpc_zone_identifier = [
    "${aws_subnet.myapp_public1_subnet.id}",
    "${aws_subnet.myapp_public2_subnet.id}",
  ]

  launch_configuration = "${aws_launch_configuration.myapp_lc.name}"

  tag {
    key                 = "Name"
    value               = "prod-${aws_launch_configuration.myapp_lc.id}"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "autopolicy_up" {
  name = "myapp-autoplicy-up"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 120
  autoscaling_group_name = "${aws_autoscaling_group.myapp_asg.name}"
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name = "myapp-alarm-high-cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "70"

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.myapp_asg.name}"
  }

  alarm_description = "This metric monitors EC2 instance CPU Utilization"
  alarm_actions = ["${aws_autoscaling_policy.autopolicy_up.arn}"]
}

#
resource "aws_autoscaling_policy" "autopolicy_down" {
  name = "myapp-autopolicy-down"
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.myapp_asg.name}"
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name = "myapp-low-cpu"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "20"

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.myapp_asg.name}"
  }

  alarm_description = "This metric monitors EC2 instance CPU Utilization"
  alarm_actions = ["${aws_autoscaling_policy.autopolicy_down.arn}"]
}
