variable "external_id" {
  description = "The external ID used for sts:AssumeRole"
  type        = string
}

variable "role_name" {
  description = "The name of the IAM role."
  type        = string
  default     = "Forward_Enterprise"
}

output "role_arn" {
  description = "The ARN of the created IAM role"
  value       = aws_iam_role.this.arn
}

resource "aws_iam_role" "this" {
  name = var.role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::453418124061:root"
        },
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "custom_policy" {
  name        = "${var.role_name}_custom_policy"
  description = "Custom policy for IAM role"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "directconnect:Describe*",
          "ec2:Describe*",
          "ec2:Get*",
          "ec2:Search*",
          "elasticloadbalancing:Describe*",
          "globalaccelerator:List*",
          "network-firewall:Describe*",
          "network-firewall:List*",
          "organizations:Describe*",
          "workspaces:Describe*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "custom_policy_attachment" {
  policy_arn = aws_iam_policy.custom_policy.arn
  role       = aws_iam_role.this.name
}