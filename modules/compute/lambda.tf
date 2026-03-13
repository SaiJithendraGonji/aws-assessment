data "archive_file" "greeter" {
  type        = "zip"
  source_file = "${path.module}/lambda/greeter/index.py"
  output_path = "${path.module}/lambda/greeter/greeter.zip"
}

data "archive_file" "dispatcher" {
  type        = "zip"
  source_file = "${path.module}/lambda/dispatcher/index.py"
  output_path = "${path.module}/lambda/dispatcher/dispatcher.zip"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "greeter" {
  name               = "unleash-live-greeter-${var.region}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Name = "unleash-live-greeter-${var.region}"
  }
}

resource "aws_iam_role_policy_attachment" "greeter_basic" {
  role       = aws_iam_role.greeter.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "greeter_permissions" {
  statement {
    sid       = "DynamoDBWrite"
    effect    = "Allow"
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.greeting_logs.arn]
  }

  statement {
    sid       = "SNSPublishCrossAccount"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [var.sns_verification_topic_arn]
  }
}

resource "aws_iam_role_policy" "greeter_permissions" {
  name   = "greeter-permissions"
  role   = aws_iam_role.greeter.id
  policy = data.aws_iam_policy_document.greeter_permissions.json
}

resource "aws_iam_role" "dispatcher" {
  name               = "unleash-live-dispatcher-${var.region}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Name = "unleash-live-dispatcher-${var.region}"
  }
}

resource "aws_iam_role_policy_attachment" "dispatcher_basic" {
  role       = aws_iam_role.dispatcher.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "dispatcher_permissions" {
  statement {
    sid       = "ECSRunTask"
    effect    = "Allow"
    actions   = ["ecs:RunTask"]
    resources = [aws_ecs_task_definition.sns_publisher.arn]
  }

  statement {
    sid     = "PassRoleToECS"
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      aws_iam_role.ecs_task_execution.arn,
      aws_iam_role.ecs_task.arn,
    ]
  }
}

resource "aws_iam_role_policy" "dispatcher_permissions" {
  name   = "dispatcher-permissions"
  role   = aws_iam_role.dispatcher.id
  policy = data.aws_iam_policy_document.dispatcher_permissions.json
}

resource "aws_cloudwatch_log_group" "greeter" {
  name              = "/aws/lambda/unleash-live-greeter-${var.region}"
  retention_in_days = 7

  tags = {
    Name = "unleash-live-greeter-${var.region}"
  }
}

resource "aws_cloudwatch_log_group" "dispatcher" {
  name              = "/aws/lambda/unleash-live-dispatcher-${var.region}"
  retention_in_days = 7

  tags = {
    Name = "unleash-live-dispatcher-${var.region}"
  }
}

resource "aws_lambda_function" "greeter" {
  function_name = "unleash-live-greeter-${var.region}"
  role          = aws_iam_role.greeter.arn
  handler       = "index.handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory

  filename         = data.archive_file.greeter.output_path
  source_code_hash = data.archive_file.greeter.output_base64sha256

  environment {
    variables = {
      DYNAMODB_TABLE  = aws_dynamodb_table.greeting_logs.name
      SNS_TOPIC_ARN   = var.sns_verification_topic_arn
      CANDIDATE_EMAIL = var.candidate_email
      GITHUB_REPO     = var.github_repo
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.greeter,
    aws_iam_role_policy_attachment.greeter_basic,
  ]

  tags = {
    Name = "unleash-live-greeter-${var.region}"
  }
}

resource "aws_lambda_function" "dispatcher" {
  function_name = "unleash-live-dispatcher-${var.region}"
  role          = aws_iam_role.dispatcher.arn
  handler       = "index.handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory

  filename         = data.archive_file.dispatcher.output_path
  source_code_hash = data.archive_file.dispatcher.output_base64sha256

  environment {
    variables = {
      ECS_CLUSTER_ARN       = aws_ecs_cluster.this.arn
      ECS_TASK_DEFINITION   = aws_ecs_task_definition.sns_publisher.arn
      ECS_SUBNET_IDS        = join(",", aws_subnet.public[*].id)
      ECS_SECURITY_GROUP_ID = aws_security_group.fargate_tasks.id
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.dispatcher,
    aws_iam_role_policy_attachment.dispatcher_basic,
  ]

  tags = {
    Name = "unleash-live-dispatcher-${var.region}"
  }
}