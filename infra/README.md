# CloudNotes infrastructure as code (Terraform)

| File | Holds |
|---|---|
| `main.tf` | Root: calls `modules/network` twice (web and app), then defines **compute** (app VM + service account) and **storage** (assets bucket + least-privilege IAM) |
| `variables.tf` | Root inputs, each with a type and description |
| `outputs.tf` | Useful values, including outputs read from the network module |
| `modules/network/` | Reusable module: one VPC, one subnet, and one firewall rule. Inputs in `variables.tf`, outputs in `outputs.tf` |
| `terraform.tfvars.example` | placeholder values. Copy to `terraform.tfvars`, which is git-ignored |

**Zero cost:** the google provider uses a placeholder `access_token`, so `init`, `validate` and `plan` run offline with no GCP account. We stop at `plan` and never run `apply`.

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
terraform fmt          # or ./tf.sh fmt    (runs Terraform in Docker)
terraform init         # or ./tf.sh init
terraform validate     # or ./tf.sh validate
terraform plan         # or ./tf.sh plan   -> Plan: 10 to add, 0 to change, 0 to destroy
```

**Known limit:** the web and app networks are separate VPCs with no peering, so they can't reach each other yet. This refactor proves the module is reusable. Connecting the tiers is later work.
