################################################################################
# Deployment pipeline configurations

locals {
  github_repo_client = "data-portal-client"
  github_repo_apis   = "data-portal-apis"

  codebuild_project_name_client = "data-portal-client-${terraform.workspace}"
  codebuild_project_name_apis   = "data-portal-apis-${terraform.workspace}"
}

data "aws_ssm_parameter" "codestar_github_arn" {
  name = "codestar_github_arn"
}

data "aws_ssm_parameter" "unsplash_client_id" {
  name = "/${local.stack_name_us}/unsplash/client_id"
}

data "aws_ssm_parameter" "cog_user_pool_id" {
  name = "${local.ssm_param_key_client_prefix}/cog_user_pool_id"
}

data "aws_ssm_parameter" "cog_identity_pool_id" {
  name = "${local.ssm_param_key_client_prefix}/cog_identity_pool_id"
}

data "aws_ssm_parameter" "oauth_domain" {
  name = "${local.ssm_param_key_client_prefix}/oauth_domain"
}

data "aws_ssm_parameter" "cog_app_client_id_stage" {
  name = "${local.ssm_param_key_client_prefix}/cog_app_client_id_stage"
}

data "aws_ssm_parameter" "oauth_redirect_in_stage" {
  name = "${local.ssm_param_key_client_prefix}/oauth_redirect_in_stage"
}

data "aws_ssm_parameter" "oauth_redirect_out_stage" {
  name = "${local.ssm_param_key_client_prefix}/oauth_redirect_out_stage"
}

data "aws_ssm_parameter" "htsget_domain" {
  name = "/htsget/domain"
}

data "aws_ssm_parameter" "gpl_submit_job" {
  name = "/gpl/submit_job_lambda_fn_url"
}

data "aws_ssm_parameter" "gpl_submit_job_manual" {
  name = "/gpl/submit_job_manual_lambda_fn_url"
}

# As of GPL v0.2.0, Do not deploy LINX plotting Lambda
# See https://github.com/umccr/gridss-purple-linx-nf/commit/a015146e95e1b7cd3de3bc639cbc600887ba42ff
# FIXME If re-enable, also uncomment env var in client CodeBuild -- search GPL_CREATE_LINX_PLOT
#data "aws_ssm_parameter" "gpl_create_linx_plot" {
#  name = "/gpl/create_linx_plot_lambda_fn_url"
#}

# Bucket storing codepipeline artifacts (both client and apis)
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "${local.org_name}-${local.stack_name_dash}-build-${terraform.workspace}"
  tags   = merge(local.default_tags)
}

resource "aws_s3_bucket_acl" "codepipeline_bucket" {
  bucket = aws_s3_bucket.codepipeline_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "codepipeline_bucket" {
  bucket = aws_s3_bucket.codepipeline_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_iam_role" "codepipeline_base_role" {
  name = "${local.stack_name_us}_codepipeline_base_role"
  path = local.iam_role_path

  # Base IAM role for codepipeline service
  assume_role_policy = templatefile("policies/codepipeline_base_role_assume_role_policy.json", {})

  tags = merge(local.default_tags)
}

resource "aws_iam_role_policy" "codepipeline_base_role_policy" {
  name = "${local.stack_name_us}_codepipeline_base_role_policy"
  role = aws_iam_role.codepipeline_base_role.id

  # Base IAM policy for codepiepline service role
  policy = templatefile("policies/codepipeline_base_role_policy.json", {
    codepipeline_bucket_arn              = aws_s3_bucket.codepipeline_bucket.arn
    codepipeline_codestar_connection_arn = data.aws_ssm_parameter.codestar_github_arn.value
  })
}

# Codepipeline for client
resource "aws_codepipeline" "codepipeline_client" {
  name     = "${local.stack_name_dash}-client-${terraform.workspace}"
  role_arn = aws_iam_role.codepipeline_base_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      output_artifacts = ["SourceArtifact"]
      version          = "1"

      configuration = {
        ConnectionArn    = data.aws_ssm_parameter.codestar_github_arn.value
        FullRepositoryId = "${local.org_name}/${local.github_repo_client}"
        BranchName       = var.github_branch_frontend[terraform.workspace]
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["SourceArtifact"]
      version         = "1"

      configuration = {
        ProjectName = local.codebuild_project_name_client
      }
    }
  }

  tags = merge(local.default_tags)
}

# Codepipeline for apis
resource "aws_codepipeline" "codepipeline_apis" {
  name     = "${local.stack_name_dash}-apis-${terraform.workspace}"
  role_arn = aws_iam_role.codepipeline_base_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      output_artifacts = ["SourceArtifact"]
      version          = "1"

      configuration = {
        ConnectionArn    = data.aws_ssm_parameter.codestar_github_arn.value
        FullRepositoryId = "${local.org_name}/${local.github_repo_apis}"
        BranchName       = var.github_branch_backend[terraform.workspace]
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["SourceArtifact"]
      version         = "1"

      configuration = {
        ProjectName = local.codebuild_project_name_apis
      }
    }
  }

  tags = merge(local.default_tags)
}

resource "aws_iam_role" "codebuild_client_role" {
  name = "${local.stack_name_us}_codebuild_client_service_role"
  path = local.iam_role_path

  # IAM role for code build (client)
  assume_role_policy = templatefile("policies/codebuild_client_role_assume_role_policy.json", {})

  tags = merge(local.default_tags)
}

resource "aws_iam_role" "codebuild_apis_role" {
  name = "${local.stack_name_us}_codebuild_apis_service_role"
  path = local.iam_role_path

  # IAM role for code build (api)
  assume_role_policy = templatefile("policies/codebuild_apis_role_assume_role_policy.json", {})

  tags = merge(local.default_tags)
}

resource "aws_iam_policy" "codebuild_apis_policy" {
  name        = "${local.stack_name_us}_codebuild_apis_service_policy"
  description = "Policy for CodeBuild for backend side of data portal"

  # IAM policy specific for the apis side
  policy = templatefile("policies/codebuild_apis_policy.json", {
    subnet_id0 = sort(data.aws_subnets.private_subnets_ids.ids)[0],
    subnet_id1 = sort(data.aws_subnets.private_subnets_ids.ids)[1],
    subnet_id2 = sort(data.aws_subnets.private_subnets_ids.ids)[2],

    region     = data.aws_region.current.name,
    account_id = data.aws_caller_identity.current.account_id
  })
}

# Attach the base policy to the code build role for client
resource "aws_iam_role_policy_attachment" "codebuild_client_role_attach_base_policy" {
  role       = aws_iam_role.codebuild_client_role.name
  policy_arn = aws_iam_policy.codebuild_base_policy.arn
}

# Attach the base policy to the code build role for apis
resource "aws_iam_role_policy_attachment" "codebuild_apis_role_attach_base_policy" {
  role       = aws_iam_role.codebuild_apis_role.name
  policy_arn = aws_iam_policy.codebuild_base_policy.arn
}

# Attach specific policies to the code build ro for apis
resource "aws_iam_role_policy_attachment" "codebuild_apis_role_attach_specific_policy" {
  role       = aws_iam_role.codebuild_apis_role.name
  policy_arn = aws_iam_policy.codebuild_apis_policy.arn
}

resource "aws_iam_policy" "codebuild_base_policy" {
  name        = "codebuild-${local.stack_name_dash}-base-service-policy"
  description = "Base policy for CodeBuild for data portal site"

  # Base IAM policy for code build
  policy = templatefile("policies/codebuild_base_policy.json", {})
}

# Codebuild project for client
resource "aws_codebuild_project" "codebuild_client" {
  name         = local.codebuild_project_name_client
  service_role = aws_iam_role.codebuild_client_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:5.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "STAGE"
      value = terraform.workspace
    }

    environment_variable {
      name  = "S3"
      value = "s3://${aws_s3_bucket.client_bucket.bucket}"
    }

    environment_variable {
      name  = "API_URL"
      value = local.api_domain
      # FIXME: https://github.com/umccr/infrastructure/issues/272
      #value = local.api_domain2
    }

    environment_variable {
      name  = "HTSGET_URL"
      value = data.aws_ssm_parameter.htsget_domain.value
    }

    environment_variable {
      name  = "GPL_SUBMIT_JOB"
      value = data.aws_ssm_parameter.gpl_submit_job.value
    }

    environment_variable {
      name  = "GPL_SUBMIT_JOB_MANUAL"
      value = data.aws_ssm_parameter.gpl_submit_job_manual.value
    }

    #    environment_variable {
    #      name  = "GPL_CREATE_LINX_PLOT"
    #      value = data.aws_ssm_parameter.gpl_create_linx_plot.value
    #    }

    environment_variable {
      name  = "REGION"
      value = data.aws_region.current.name
    }

    environment_variable {
      name  = "COGNITO_USER_POOL_ID"
      value = data.aws_ssm_parameter.cog_user_pool_id.value
    }

    environment_variable {
      name  = "COGNITO_IDENTITY_POOL_ID"
      value = data.aws_ssm_parameter.cog_identity_pool_id.value
    }

    environment_variable {
      name  = "COGNITO_APP_CLIENT_ID_STAGE"
      value = data.aws_ssm_parameter.cog_app_client_id_stage.value
    }

    environment_variable {
      name  = "OAUTH_DOMAIN"
      value = data.aws_ssm_parameter.oauth_domain.value
    }

    environment_variable {
      name  = "OAUTH_REDIRECT_IN_STAGE"
      value = data.aws_ssm_parameter.oauth_redirect_in_stage.value
    }

    environment_variable {
      name  = "OAUTH_REDIRECT_OUT_STAGE"
      value = data.aws_ssm_parameter.oauth_redirect_out_stage.value
    }

    environment_variable {
      name  = "UNSPLASH_CLIENT_ID"
      value = data.aws_ssm_parameter.unsplash_client_id.value
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/${local.org_name}/${local.github_repo_client}.git"
    git_clone_depth = 1
  }

  tags = merge(local.default_tags)
}

# Codebuild project for apis
resource "aws_codebuild_project" "codebuild_apis" {
  name         = local.codebuild_project_name_apis
  service_role = aws_iam_role.codebuild_apis_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "STAGE"
      value = terraform.workspace
    }

    environment_variable {
      name  = "ICA_BASE_URL"      # this is used only within CodeBuild dind scope
      value = "http://localhost"
    }

    environment_variable {
      name  = "ICA_ACCESS_TOKEN"
      value = "any_value_work"  # this is used only within CodeBuild dind Prism mock stack for build test purpose only
    }
  }

  /* UNCOMMENT TO ADD VPC SUPPORT FOR CODEBUILD
  vpc_config {
    vpc_id = data.aws_vpc.main_vpc.id
    subnets = data.aws_subnet_ids.private_subnets_ids.ids
    security_group_ids = [
      aws_security_group.codebuild_apis_security_group.id,
    ]
  }
  */

  source {
    type            = "GITHUB"
    location        = "https://github.com/${local.org_name}/${local.github_repo_apis}.git"
    git_clone_depth = 1
  }

  tags = merge(local.default_tags)
}

################################################################################
# Notification: CodeBuild build status send through SNS topic to ChatBot to
# Slack channel #arteria-dev for DEV, #data-portal for PROD, #devops-alerts for STG

data "aws_sns_topic" "chatbot_topic" {
  name = "AwsChatBotTopic"
}

locals {
  notification_sns_topic_arn = {
    prod = aws_sns_topic.portal_ops_sns_topic.arn
    dev  = data.aws_sns_topic.chatbot_topic.arn
    stg  = data.aws_sns_topic.chatbot_topic.arn
  }
}

resource "aws_codestarnotifications_notification_rule" "apis_build_status" {
  name        = "${local.stack_name_us}_apis_code_build_status"
  resource    = aws_codebuild_project.codebuild_apis.arn
  detail_type = "BASIC"

  target {
    address = local.notification_sns_topic_arn[terraform.workspace]
  }

  event_type_ids = [
    "codebuild-project-build-state-failed",
    "codebuild-project-build-state-succeeded",
  ]

  tags = merge(local.default_tags)
}

resource "aws_codestarnotifications_notification_rule" "client_build_status" {
  name        = "${local.stack_name_us}_client_code_build_status"
  resource    = aws_codebuild_project.codebuild_client.arn
  detail_type = "BASIC"

  target {
    address = local.notification_sns_topic_arn[terraform.workspace]
  }

  event_type_ids = [
    "codebuild-project-build-state-failed",
    "codebuild-project-build-state-succeeded",
  ]

  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "notification_sns_topic_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/notification_sns_topic_arn"
  type  = "String"
  value = local.notification_sns_topic_arn[terraform.workspace]
  tags  = merge(local.default_tags)
}
