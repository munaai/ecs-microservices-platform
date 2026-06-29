terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_iam_policy_document" "ecs_tasks_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = var.execution_role_name
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = merge(var.tags, {
    Name = var.execution_role_name
  })
}

resource "aws_iam_role_policy_attachment" "execution_policy" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  for_each = var.task_roles

  name               = each.value.name
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = merge(var.tags, {
    Name = each.value.name
  })
}

data "aws_iam_policy_document" "task_policy" {
  for_each = var.task_roles

  dynamic "statement" {
    for_each = length(each.value.secret_arns) > 0 ? [1] : []

    content {
      effect = "Allow"

      actions = [
        "secretsmanager:GetSecretValue"
      ]

      resources = each.value.secret_arns
    }
  }

  dynamic "statement" {
    for_each = length(each.value.sqs_queue_arns) > 0 ? [1] : []

    content {
      effect = "Allow"

      actions = [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl"
      ]

      resources = each.value.sqs_queue_arns
    }
  }
}

resource "aws_iam_policy" "task_policy" {
  for_each = var.task_roles

  name   = "${each.value.name}-policy"
  policy = data.aws_iam_policy_document.task_policy[each.key].json

  tags = merge(var.tags, {
    Name = "${each.value.name}-policy"
  })
}

resource "aws_iam_role_policy_attachment" "task_policy" {
  for_each = var.task_roles

  role       = aws_iam_role.task[each.key].name
  policy_arn = aws_iam_policy.task_policy[each.key].arn
}