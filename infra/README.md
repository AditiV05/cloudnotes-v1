# CloudNotes infrastructure as code (Terraform)

| File | Holds |
|---|---|
| `main.tf` | terraform/provider settings and resources: **network** (VPC, subnet, 2 firewall rules), **compute** (app VM + service account), **storage** (assets bucket + least-privilege IAM) |
| `variables.tf` | every environment-specific input, each with a type and description (some with validation) |
| `outputs.tf` | useful values: instance IP/name, bucket name/URL, network, subnet CIDR, service account |
| `terraform.tfvars.example` | placeholder values. Copy to `terraform.tfvars`, which is git-ignored |

**Zero cost:** the google provider uses a placeholder `access_token`, so `init`, `validate` and `plan` run offline with no GCP account. We stop at `plan` and never run `apply`.

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
terraform fmt          # or ./tf.sh fmt    (runs Terraform in Docker)
terraform init         # or ./tf.sh init
terraform validate     # or ./tf.sh validate
terraform plan         # or ./tf.sh plan   -> Plan: 8 to add, 0 to change, 0 to destroy
```
