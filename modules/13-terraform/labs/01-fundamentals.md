# Lab 13.01 — Fundamentals, without touching a cloud

**CORE · 40 min**

## Context

Everything that matters about Terraform's model — state, dependency graph, plan
semantics — can be learned against local providers, for free and in seconds
instead of minutes. Do that before spending money.

## The problem

### Part 1 — the state file, examined

```bash
mkdir -p modules/13-terraform/lab && cd $_
cat > main.tf <<'EOF'
terraform { required_providers { local = { source = "hashicorp/local", version = "2.5.2" } } }

resource "local_file" "example" {
  filename = "${path.module}/hello.txt"
  content  = "first"
}
EOF
terraform init && terraform apply -auto-approve
```

Now open `terraform.tfstate` and read it properly.

1. What does it contain besides the resource? Find the serial and the lineage.
2. Change `content` to `"second"` and apply. What changed in the state?
3. Delete `hello.txt` by hand and run `plan`. What does Terraform propose, and
   how did it find out?
4. Delete the **state file** instead and run `plan`. What does it propose now?

Question 4 is the important one: with no state, Terraform has no memory. It does
not scan for what exists — it only knows what it wrote down.

### Part 2 — the dependency graph

Add a second resource that references the first, then:

```bash
terraform graph | dot -Tsvg > graph.svg   # if graphviz is available
terraform plan -json | jq -r 'select(.type=="planned_change") | .change.resource.addr'
```

5. What determines the order? Is it file order?
6. Force a dependency Terraform cannot infer. How do you express it?
7. What is the risk of `depends_on` used liberally?

### Part 3 — plan semantics

Learn to read a plan precisely:

| Symbol | Means |
|---|---|
| `+` | |
| `-` | |
| `~` | |
| `-/+` | |
| `+/-` | |

8. Produce each one. `-/+` and `+/-` differ in **order** — which is which, and
   why does the distinction matter for a database?

### Part 4 — exit codes

```bash
terraform plan -detailed-exitcode; echo "exit: $?"
```

9. What do 0, 1 and 2 mean?
10. Write the CI check that fails the build when infrastructure has drifted.

## Expected outcome

The state file understood field by field, all five plan symbols produced, and a
drift check ready for CI.

## Staged hints

<details><summary>Hint 1 — question 8</summary>

`-/+` destroys then creates: downtime, and for a database, data loss unless it is
externally persisted. `+/-` creates then destroys — `create_before_destroy` —
which needs the resource to tolerate two existing at once (a name conflict makes
it impossible). Knowing which one a plan is proposing is the difference between
an outage and a rolling change.
</details>

<details><summary>Hint 2 — question 7</summary>

Explicit `depends_on` where Terraform could have inferred the dependency makes
the graph more serial than necessary, slowing applies, and it does not update
when you refactor. Use it only for dependencies that are real but invisible to
Terraform — an IAM permission that must exist before an API call succeeds.
</details>
