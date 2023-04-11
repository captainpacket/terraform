terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

variable "mgmt_account" {
  type = string
}

resource "aws_iam_role" "forward_role" {
  name_prefix = "ForwardAccessToAccounts_"
  assume_role_policy = jsonencode({
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${var.mgmt_account}:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
 })

lifecycle {
    ignore_changes = [name]
  }
}

resource "aws_iam_policy" "forward_policy" {
  name_prefix        = "Forward_Enterprise_"
  policy = file("${path.module}/forward_policy.json")

  lifecycle {
    ignore_changes = [name]
  }
}

resource "aws_iam_role_policy_attachment" "readonly_attachment" {
  policy_arn = aws_iam_policy.forward_policy.arn
  role       = aws_iam_role.forward_role.name
}

output "forward_role_arn" {
  value = aws_iam_role.forward_role.arn
}
