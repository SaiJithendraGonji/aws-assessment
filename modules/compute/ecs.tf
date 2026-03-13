resource "aws_ecs_cluster" "this" {
  name = "unleash-live-${var.region}"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = {
    Name = "unleash-live-${var.region}"
  }
}

data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "unleash-live-ecs-execution-${var.region}"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = {
    Name = "unleash-live-ecs-execution-${var.region}"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name               = "unleash-live-ecs-task-${var.region}"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = {
    Name = "unleash-live-ecs-task-${var.region}"
  }
}

data "aws_iam_policy_document" "ecs_task_permissions" {
  statement {
    sid    = "SNSPublishCrossAccount"
    effect = "Allow"
    actions = [
      "sns:Publish",
    ]
    resources = [var.sns_verification_topic_arn]
  }
}

resource "aws_iam_role_policy" "ecs_task_permissions" {
  name   = "ecs-task-sns-publish"
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.ecs_task_permissions.json
}

resource "aws_cloudwatch_log_group" "ecs_task" {
  name              = "/ecs/unleash-live-sns-publisher-${var.region}"
  retention_in_days = 7

  tags = {
    Name = "unleash-live-sns-publisher-${var.region}"
  }
}

resource "aws_ecs_task_definition" "sns_publisher" {
  family                   = "unleash-live-sns-publisher-${var.region}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "sns-publisher"
      image = "public.ecr.aws/aws-cli/aws-cli:latest"

      command = [
        "sns", "publish",
        "--topic-arn", var.sns_verification_topic_arn,
        "--region", "us-east-1",
        "--message", jsonencode({
          email  = var.candidate_email
          source = "ECS"
          region = var.region
          repo   = var.github_repo
        })
      ]

      environment = [
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.region
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_task.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "sns-publisher"
        }
      }

      essential = true
    }
  ])

  tags = {
    Name = "unleash-live-sns-publisher-${var.region}"
  }
}
