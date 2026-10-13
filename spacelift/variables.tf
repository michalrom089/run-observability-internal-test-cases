variable "repository" {
  type        = string
  description = "Name of the GitHub repository that holds the cases."
  default     = "run-observability-internal-test-cases"
}

variable "git_url" {
  type        = string
  description = "HTTPS URL of the repository. The stacks read it through the raw Git vendor, so the account needs no VCS integration."
  default     = "https://github.com/michalrom089/run-observability-internal-test-cases.git"
}

variable "git_namespace" {
  type        = string
  description = "Namespace the raw Git vendor shows next to the repository name. Cosmetic only."
  default     = "michalrom089"
}

variable "branch" {
  type        = string
  description = "Branch the stacks track."
  default     = "main"
}

variable "parent_space_id" {
  type        = string
  description = "Space that holds the case space."
  default     = "root"
}

variable "tofu_version" {
  type        = string
  description = "OpenTofu version the stacks run."
  default     = "1.10.6"
}

variable "autodeploy" {
  type        = bool
  description = "Apply tracked runs without a confirmation."
  default     = true
}

variable "trigger_runs" {
  type        = bool
  description = "Start the runs after the stacks are created. The runs fire once, at create."
  default     = true
}

variable "healthy_runs" {
  type        = number
  description = "Healthy runs each stack starts with. They set the baseline."
  default     = 3
}

variable "issue_runs" {
  type        = number
  description = "Runs after the healthy ones that set TF_VAR_trigger_issue=true. Keep it at 1: the backend compares a run with the P95 of the stack's earlier runs, so a second slow run has the first one in its baseline and is not marked slow."
  default     = 1
}

variable "slow_seconds" {
  type        = number
  description = "Seconds the slow step takes in an issue run of slow-runs-a and slow-runs-b."
  default     = 240
}

variable "name_prefix" {
  type        = string
  description = "Prefix for the stack names."
  default     = "run-obs"
}
