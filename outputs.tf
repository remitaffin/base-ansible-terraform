output "db_hostname" {
  value = "${aws_db_instance.myapp_db.address}"
}

output "elb_hostname" {
  value = "${aws_elb.myapp_elb.dns_name}"
}

output "jenkins_hostname" {
  value = "${aws_instance.jenkins.public_dns}"
}
