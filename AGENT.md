# AGENT.md

Instructions for an agent working in this repository.

## What this repository is

Seven stacks for internal testing of the run observability dashboard. Each
stack runs healthy, then gets slow, fails or gets findings for one known reason. `README.md` lists
the reason per stack. Keep that table correct.

## Layout

| Path                         | Purpose                                                                                 |
| ---------------------------- | --------------------------------------------------------------------------------------- |
| `slow-runs-a/` … `-c/`       | Slow cases: a resource, a hook, provider downloads.                                     |
| `failed-runs-a/` … `-c/`     | Failed cases: a data source, a hook, a provider.                                        |
| `findings-a/`                | Provider findings: a version change and a version conflict.                             |
| `modules/workload/`          | The decoy resources. Every case calls it.                                               |
| `hooks/step.sh`              | Every hook. Sleeps, and is slow or fails on an issue.                                   |
| `hooks/add-providers.sh`     | Adds providers before init in the `-c` cases. Removes them after init in `slow-runs-c`. |
| `hooks/provider-findings.sh` | Pins and installs `hashicorp/random` in `findings-a`.                                   |
| `spacelift/`                 | Not a case. Creates the space, the stacks and the runs.                                 |

## Rules

1. **One culprit per case.** Every case has the same decoys. Only one item
   misbehaves, and only in an issue run.
2. **`TF_VAR_trigger_issue=true` marks an issue run.** Terraform reads it as a
   variable. The hooks read it from the environment. A healthy run leaves it
   unset.
3. **Every case changes on every run.** `terraform_data.trigger` takes
   `timestamp()`, and the other resources replace through it.
4. **The hooks run from the project root.** They call `../hooks/...`.
5. **Commit no lock file and no state.** `.gitignore` covers them, and the
   `*_override.tf` files that `add-providers.sh` writes.

## Verifying a change

```bash
terraform fmt -recursive -check

cd <case>
tofu init && tofu apply -auto-approve
TF_VAR_trigger_issue=true TF_VAR_slow_seconds=8 tofu apply -auto-approve
```

For a `-c` case, run `TF_VAR_trigger_issue=true sh ../hooks/add-providers.sh <slow|fail>`
before init. For a `-b` case, run the hook from `spacelift/main.tf` by hand.
Delete `.terraform/`, the lock file, the state and `*_override.tf` afterwards.

## The `spacelift/` directory

**Do not apply it without asking.** It creates real stacks in a real account.
`terraform init -backend=false` and `terraform validate` are safe.
