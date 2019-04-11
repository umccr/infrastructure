# instance ID
output "instance_id" {
  value = "${aws_instance.worker_instance.id}"
}
