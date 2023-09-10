# Terraform Boilerplate Templates / GitHub

![Static Badge](https://img.shields.io/badge/Terraform-1.5.0-blue)
[![GPLv3 License](https://img.shields.io/badge/License-GPL%20v3-yellow.svg)](https://opensource.org/licenses/)

Official documentation 👉 https://registry.terraform.io/providers/integrations/github/latest/docs

#### Minimum permission required for GitHub PAT (Personal Access Token) are:
`"repo"` `"read:repo_hook"` `"read:org"` `"read:discussion"` `"delete_repo"`

## Build
```
terraform init
terraform plan -out deploy.tfplan
terraform apply deploy.tfplan
```
## Destroy
```
terraform plan -destroy -out destroy.tfplan
terraform apply destroy.tfplan
```
