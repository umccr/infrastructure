################################################################################
# RDS DB configurations

resource "aws_db_subnet_group" "rds" {
  name = "${local.stack_name_us}_db_subnet_group"
  subnet_ids = data.aws_subnets.database_subnets_ids.ids
  tags = merge(local.default_tags)
}

resource "aws_rds_cluster_parameter_group" "db_parameter_group" {
  name        = "${local.stack_name_dash}-db-parameter-group"
  family      = "aurora-mysql8.0"
  description = "${local.stack_name_us} RDS Aurora cluster parameter group"

  parameter {
    # Set to max 1GB. See https://dev.mysql.com/doc/refman/8.0/en/packet-too-large.html
    name  = "max_allowed_packet"
    value = 1073741824
  }

  parameter {
    # Set to 3x. See https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_net_read_timeout
    name  = "net_read_timeout"
    value = 30 * 3  # 30s (default) * 3
  }

  parameter {
    # Set to 3x. See https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_net_write_timeout
    name  = "net_write_timeout"
    value = 60 * 3  # 60s (default) * 3
  }

  tags = merge(local.default_tags)
}

resource "aws_rds_cluster" "db" {
  cluster_identifier  = "${local.stack_name_dash}-aurora-cluster"
  # Engine & Mode. See https://docs.aws.amazon.com/AmazonRDS/latest/APIReference/API_DescribeDBEngineVersions.html
  engine              = "aurora-mysql"
  engine_mode         = "provisioned"
  engine_version      = "8.0.mysql_aurora.3.04.1"
  skip_final_snapshot = true

  database_name   = local.stack_name_us
  master_username = data.aws_ssm_parameter.rds_db_username.value
  master_password = data.aws_ssm_parameter.rds_db_password.value

  vpc_security_group_ids = [aws_security_group.rds_security_group.id]

  db_subnet_group_name = aws_db_subnet_group.rds.name

  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.db_parameter_group.name

  serverlessv2_scaling_configuration {
    # See https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2-administration.html
    min_capacity = var.rds_min_capacity[terraform.workspace]
    max_capacity = var.rds_max_capacity[terraform.workspace]
  }

  backup_retention_period = var.rds_backup_retention_period[terraform.workspace]

  deletion_protection = true
  storage_encrypted   = true

  tags = merge(local.default_tags)
}

resource "aws_rds_cluster_instance" "db_instance" {
  cluster_identifier = aws_rds_cluster.db.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.db.engine
  engine_version     = aws_rds_cluster.db.engine_version

  db_subnet_group_name = aws_rds_cluster.db.db_subnet_group_name
  publicly_accessible  = false
  monitoring_interval  = var.rds_monitoring_interval[terraform.workspace]

  tags = merge(local.default_tags)
}

# Composed database url for backend to use
resource "aws_ssm_parameter" "ssm_full_db_url" {
  name        = "${local.ssm_param_key_backend_prefix}/full_db_url"
  type        = "SecureString"
  description = "Database url used by the Django app"
  value       = "mysql://${data.aws_ssm_parameter.rds_db_username.value}:${data.aws_ssm_parameter.rds_db_password.value}@${aws_rds_cluster.db.endpoint}:${aws_rds_cluster.db.port}/${aws_rds_cluster.db.database_name}"

  tags = merge(local.default_tags)
}
