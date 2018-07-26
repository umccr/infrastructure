output "compute_env_arn" {
  value = "${aws_batch_compute_environment.batch.arn}"
}

/*output "underlying_ecs_cluster" {
  value = "${aws_batch_compute_environment.batch.ecs_cluster_arn}"
}
*/

