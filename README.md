# Terraform Boilerplate Templates

![Static Badge](https://img.shields.io/badge/Terraform-1.5.0-blue)
[![GPLv3 License](https://img.shields.io/badge/License-GPL%20v3-yellow.svg)](https://opensource.org/licenses/)

Official documentation 👉 https://developer.hashicorp.com/terraform

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