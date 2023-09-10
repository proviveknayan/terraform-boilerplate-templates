terraform {
  required_version = "~> 1.5.0"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}

provider "github" {
  token = var.token
}

# create and initialise a public GitHub repository / GNU General Public License and a Visual Studio .gitignore file

resource "github_repository" "repo" {
  name               = "terraform-boilerplate-templates"
  description        = ""
  topics             = "DevOps Terraform"
  visibility         = "public"
  has_issues         = false
  has_wiki           = false
  has_discussion     = false
  has_projects       = false
  auto_init          = true
  license_template   = "lgpl-3"
  gitignore_template = "VisualStudio"
}

# set 'main' as default branch

resource "github_branch_default" "main" {
  repository = github_repository.repo.name
  branch     = "main"
}

resource "github_branch" "stage" {
  repository = github_repository.repo.name
  branch     = "stage"
}

# create branch protection rule for default branch

resource "github_branch_protection" "default" {
  repository_id                   = github_repository.repo.id
  pattern                         = github_branch_default.main.branch
  require_conversation_resolution = true
  enforce_admins                  = true

  required_pull_request_reviews {
    required_approving_review_count = 1
  }
}