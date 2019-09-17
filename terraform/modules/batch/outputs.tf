output "compute_env_arn" {
  # we need to use the splat syntax, since 
  # value = "${aws_batch_compute_environment.batch.0.arn}"
  value = "${concat(aws_batch_compute_environment.batch.*.arn, aws_batch_compute_environment.batch_ondemand.*.arn)}"
}

/*output "underlying_ecs_cluster" {
  value = "${aws_batch_compute_environment.batch.ecs_cluster_arn}"
}
*/

