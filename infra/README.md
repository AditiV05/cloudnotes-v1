# CloudNotes infrastructure as code (Terraform)

The whole CloudNotes system as one root configuration, composed from five modules.

| Module | Provisions | Reads from |
|---|---|---|
| `network` | VPC, web/app/db subnets, firewall rules (security groups) | root variables |
| `storage` | private, versioned assets bucket | root variables |
| `iam` | app role, least-privilege bucket policy, instance profile | `storage` |
| `compute` | app instance in the app subnet | `network`, `iam` |
| `database` | managed PostgreSQL on private subnets | `network` |

## Validate at zero cost

LocalStack emulates the AWS API locally, so there is no cloud account and no bill. We stop at `plan`, and `tf.sh` blocks `apply`.

```bash
docker run -d --rm --name localstack -p 4566:4566 localstack/localstack:4.12
cd infra
cp terraform.tfvars.example terraform.tfvars
./tf.sh init
./tf.sh validate
./tf.sh plan
```

## Known limits

- A plan of brand-new resources makes no API calls, so it proves the design, not that LocalStack can run it. LocalStack's free edition doesn't emulate RDS anyway.
- CloudNotes runs on GCP in earlier modules. This config uses the AWS equivalents because LocalStack emulates AWS: VPC network to `aws_vpc`, firewall to `aws_security_group`, VM to `aws_instance`, Cloud SQL to `aws_db_instance`, Cloud Storage to `aws_s3_bucket`, service account to `aws_iam_role`.
- The design has no internet gateway, load balancer, or NAT yet. The web subnet is reserved for the load balancer. These are the next additions before any real apply.
