# Terraform Script for AWS Organizations - Forward Networks On-Prem customers only

This Terraform script automates the process of creating AWS accounts, IAM roles, and policies for an AWS organization.  It will attempt POST the cloud account setup to the Forward Networks API, if the current cloud setup does not exist.

## Requirements

- [Terraform](https://www.terraform.io/) 0.13 or higher
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials

## Usage

1. Clone the repository and navigate to the root directory.
2. Run `terraform init` to initialize the working directory and download the required providers.
3. Run `terraform plan` to preview the template create process.
4. Run `terraform init --upgrade` to initialize the new providers from the AWS accounts.
4. Run `terraform apply` to create the infrastructure resources.

The script creates IAM roles and policies for each account in the AWS organization, and creates a new cloud account on AWS. The IAM roles allow the specified AWS account to assume the roles.

## Files

- `generate_account_code.tf`: Terraform file to define the template creation process
- `iam_role/main.tf`: Defines the IAM role and policy resources.
- `providers.tmpl`: A template file used to generate the configuration files for AWS providers.
- `role.tmpl`: A template file used to generate the configuration files for IAM roles.
- `outputs.tmpl`: A template file used to generate the output values.

## Variables

- `var.fwduser`: The username for the FWD API authentication.
- `var.fwdpassword`: The password for the FWD API authentication.
- `var.setupid`: The name of the new cloud account.
- `var.region_names`: A list of AWS regions to include in the new cloud account.
- `var.networkid`: The ID of the network associated with the new cloud account.

## Outputs

- `forward_role_arn`: The ARN of the IAM role created by the script.

## Authors

- [Craig Johnson](https://github.com/fracticated)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

