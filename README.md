# run-observability-internal-test-cases

Stacks for internal testing of the run observability dashboard. Each stack runs
healthy a few times, then gets slow or fails for one known reason. The tester
uses the dashboard to find that reason.

Nothing here costs money. The resources are `terraform_data`, `time_sleep` and
`random_id`. The large providers in `slow-runs-c` are downloaded, but no
resource uses them.

## Stacks

Every stack starts 4 runs: 3 healthy runs, then 1 issue run. An issue run sets
`TF_VAR_trigger_issue=true`. Terraform reads it as `var.trigger_issue`, and the
hooks read it from the environment.

Keep it at one issue run. The backend marks a run slow when a duration is more
than twice the P95 of the stack's earlier runs. A second slow run has the first
one in its P95, so the backend does not mark it slow.

| Stack                   | Issue run                                                                |
| ----------------------- | ------------------------------------------------------------------------ |
| `run-obs-slow-runs-a`   | `time_sleep.database_migration` takes 240 s instead of 5 s.              |
| `run-obs-slow-runs-b`   | The `after_plan` hook `policy-scan` takes 240 s instead of 2 s.          |
| `run-obs-slow-runs-c`   | Init downloads `hashicorp/aws`, `hashicorp/azurerm`, `hashicorp/google`. |
| `run-obs-failed-runs-a` | The plan fails. `data.external.image_lookup` exits 1.                    |
| `run-obs-failed-runs-b` | The `before_plan` hook `validate-config` exits 1.                        |
| `run-obs-failed-runs-c` | Init fails. `registry.acme.invalid/acme/platform` cannot resolve.        |

Every stack also has the same decoys, so the culprit is not the only item on
the dashboard:

- six `time_sleep` resources in `modules/workload`, 1 to 3 seconds each
- the hooks `fetch-secrets` (`before_init`), `render-config` (`before_plan`)
  and `notify` (`after_apply`)
- the providers `hashicorp/random` and `hashicorp/time`

## Getting started

This creates one bootstrap stack. The bootstrap stack creates the space, the
six stacks and their runs. The commands need spacectl v1.20.0 or later and a
spacectl profile.

**1. Create the bootstrap stack.** It reads this repository over the raw Git
vendor, so your account needs no VCS integration.

```bash
spacectl api --variables '{
  "input": {
    "name": "run-obs-int-bootstrap",
    "description": "Creates the run observability internal testing space and stacks.",
    "provider": "GIT",
    "repository": "run-observability-internal-test-cases",
    "repositoryURL": "https://github.com/michalrom089/run-observability-internal-test-cases.git",
    "namespace": "michalrom089",
    "branch": "main",
    "projectRoot": "spacelift",
    "space": "root",
    "autodeploy": true,
    "administrative": false,
    "labels": ["run-observability", "bootstrap"],
    "vendorConfig": {
      "opentofu": { "version": "1.10.6", "workflowTool": "OPENTOFU" }
    }
  },
  "manageState": true
}' 'mutation CreateBootstrap($input: StackInput!, $manageState: Boolean!) {
  stackCreate(input: $input, manageState: $manageState) { id name }
}'
```

**2. Give the stack permission to create the space and the stacks.** Attach the
`space-admin` system role in `root`. You need admin access to `root`.

```bash
ROLE_ID=$(spacectl api '{ roles { id slug } }' --raw \
  | jq -r '.data.roles[] | select(.slug == "space-admin") | .id')

spacectl api --variables "{
  \"input\": {
    \"stackID\": \"run-obs-int-bootstrap\",
    \"roleID\": \"$ROLE_ID\",
    \"spaceID\": \"root\"
  }
}" 'mutation AttachRole($input: StackRoleBindingInput!) {
  stackRoleBindingCreate(input: $input) { id }
}'
```

**3. Run it.**

```bash
spacectl stack deploy --id run-obs-int-bootstrap
```

The runs fire once, when the bootstrap stack creates the stacks. A slow issue
run takes about 4 minutes, so give the stacks about 15 minutes.

## Running more issue runs

Trigger a run with the issue from the stack's run environment, or locally:

```bash
cd slow-runs-a
TF_VAR_trigger_issue=true TF_VAR_slow_seconds=10 tofu apply
```

A hook reads the same variables. Run it from the case directory:

```bash
TF_VAR_trigger_issue=true sh ../hooks/step.sh validate-config 1 fail
```

## Changing a case

The stacks read this repository through the raw Git vendor. The vendor gets no
push events, so a push does not move a stack's tracked commit. After you push a
change to a case, sync each stack you changed:

```bash
spacectl stack sync-commit --id run-obs-slow-runs-a
```

Otherwise the stack runs new hooks against old code.
