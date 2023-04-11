terraform {
  required_providers {
    forwardnetworks = {
      source  = "local/hashicorp/forwardnetworks"
      version = ">= 1.0.0"
    }
  }
  required_version = ">= 0.13"
}

provider "forwardnetworks" {
  username = var.fwduser
  password = var.fwdpassword
  apphost = var.apphost
# insecure = true
}

data "aws_organizations_organization" "org" {}

data "aws_caller_identity" "current" {}

locals {
  account_names = [for account in data.aws_organizations_organization.org.accounts : account.name]
  account_ids = [for account in data.aws_organizations_organization.org.accounts : account.id]
  auth_header = "Basic ${base64encode("${var.fwduser}:${var.fwdpassword}")}"
  mgmt_account = data.aws_caller_identity.current.account_id
}

resource "local_file" "providers_tf" {
  content  = templatefile("${path.module}/providers.tmpl", { accounts = local.account_ids })
  filename = "${path.module}/providers.tf"
}

resource "local_file" "role_tf" {
  content  = templatefile("${path.module}/role.tmpl", { accounts = local.account_ids })
  filename = "${path.module}/role.tf"
}

resource "local_file" "outputs_tf" {
  content  = templatefile("${path.module}/outputs.tmpl", { 
    accounts = local.account_ids,
    networkid = var.networkid
   })
  filename = "${path.module}/outputs.tf"
}
