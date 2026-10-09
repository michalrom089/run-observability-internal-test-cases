# One stack per case. Every stack starts with healthy runs, then runs that set
# TF_VAR_trigger_issue=true and misbehave.
#
# Every stack runs the same decoy hooks. A case adds its culprit hook, if it
# has one, next to them. sh ../hooks/step.sh <name> <seconds> [slow|fail].
locals {
  decoy_hooks = {
    before_init = ["sh ../hooks/step.sh fetch-secrets 1"]
    after_init  = []
    before_plan = ["sh ../hooks/step.sh render-config 2"]
    after_plan  = []
    after_apply = ["sh ../hooks/step.sh notify 1"]
  }

  stack_entries = {
    "slow-runs-a" = {
      description = "The apply gets slow. One resource takes minutes."
    }
    "slow-runs-b" = {
      description = "The run gets slow. One hook takes minutes."
      after_plan  = ["sh ../hooks/step.sh policy-scan 2 slow"]
    }
    "slow-runs-c" = {
      description = "Init gets slow. It downloads three large providers."
      before_init = ["sh ../hooks/add-providers.sh slow"]
      after_init  = ["sh ../hooks/add-providers.sh clean"]
    }
    "failed-runs-a" = {
      description = "The plan fails. One data source fails to read."
    }
    "failed-runs-b" = {
      description = "The run fails. One hook exits 1."
      before_plan = ["sh ../hooks/step.sh validate-config 1 fail"]
    }
    "failed-runs-c" = {
      description = "Init fails. One provider cannot be downloaded."
      before_init = ["sh ../hooks/add-providers.sh fail"]
    }
    "findings-a" = {
      description = "The run finishes with findings. A provider changes version and resolves at two versions."
      before_init = ["sh ../hooks/provider-findings.sh pin"]
      after_init  = ["sh ../hooks/provider-findings.sh conflict"]
    }
  }

  stacks = {
    for key, entry in local.stack_entries : key => {
      description = entry.description
      before_init = concat(local.decoy_hooks.before_init, try(entry.before_init, []))
      after_init  = concat(local.decoy_hooks.after_init, try(entry.after_init, []))
      before_plan = concat(local.decoy_hooks.before_plan, try(entry.before_plan, []))
      after_plan  = concat(local.decoy_hooks.after_plan, try(entry.after_plan, []))
      after_apply = local.decoy_hooks.after_apply
    }
  }

  # One entry per run. The healthy runs come first. The issue runs follow, and
  # they depend on the healthy ones, so Spacelift queues them in that order.
  healthy_runs = merge([
    for key in keys(local.stacks) : {
      for index in range(var.healthy_runs) : "${key}-${index}" => key
    }
  ]...)

  issue_runs = merge([
    for key in keys(local.stacks) : {
      for index in range(var.healthy_runs, var.healthy_runs + var.issue_runs) : "${key}-${index}" => key
    }
  ]...)
}

# One space that holds every case stack.
resource "spacelift_space" "test_cases" {
  name             = var.repository
  parent_space_id  = var.parent_space_id
  description      = "Stacks for internal testing of run observability."
  inherit_entities = true

  labels = ["run-observability", "internal-testing"]
}

resource "spacelift_stack" "test_case" {
  for_each = local.stacks

  name        = "${var.name_prefix}-${each.key}"
  description = each.value.description

  # No VCS block. The stack uses the managed GitHub integration, and the
  # backend takes the namespace from the GitHub app installation.
  repository   = var.repository
  branch       = var.branch
  project_root = each.key

  # A native OpenTofu stack. The block replaces terraform_workflow_tool = "OPEN_TOFU".
  opentofu {
    version = var.tofu_version
  }

  before_init = each.value.before_init
  after_init  = each.value.after_init
  before_plan = each.value.before_plan
  after_plan  = each.value.after_plan
  after_apply = each.value.after_apply

  space_id   = spacelift_space.test_cases.id
  autodeploy = var.autodeploy

  labels = ["run-observability", "internal-testing"]
}

# The healthy runs. They set the baseline the issue runs differ from. The runs
# fire once, at create.
resource "spacelift_run" "healthy" {
  for_each = var.trigger_runs ? local.healthy_runs : {}

  stack_id = spacelift_stack.test_case[each.value].id
}

# The issue runs. TF_VAR_trigger_issue makes them misbehave. Terraform reads it
# as var.trigger_issue and the hooks read it from the environment.
resource "spacelift_run" "issue" {
  for_each = var.trigger_runs ? local.issue_runs : {}

  stack_id = spacelift_stack.test_case[each.value].id

  runtime_config {
    environment {
      key   = "TF_VAR_trigger_issue"
      value = "true"
    }
    environment {
      key   = "TF_VAR_slow_seconds"
      value = tostring(var.slow_seconds)
    }
  }

  depends_on = [spacelift_run.healthy]
}
