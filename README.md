# Sentinel

Sentinel is a small web-based Cyber Asset & Vulnerability Management platform. It lets an administrator track IT assets (servers, laptops, network devices), record known vulnerabilities against those assets, assign severity levels, and monitor overall security posture through a dashboard.

## Assignment 2: Cloud deployment (AWS)

Sentinel deploys to AWS.

| Component | Role |
|---|---|
| EC2 `sentinel-backend` | Node.js/Express API (port 5000).
| EC2 `sentinel-frontend` | React (Vite) single-page app (port 3000). |
| RDS `sentinel-db` 
| SNS `sentinel-alerts` | Email alerts when a Critical vulnerability is added. Subscribers must confirm via an emailed link before delivery starts. |

Unlike the local version's single request chain, this is a client-side single-page app: the browser talks to `frontend` (to load the page) and to `backend` (for API calls) independently - the backend is not a hidden layer behind the frontend, so it's reachable on its own public IP.

## Host requirements (cloud)

- [Terraform](https://www.terraform.io/) (developed and tested with v1.16.2).
- [AWS CLI](https://aws.amazon.com/cli/) v2 (developed and tested with 2.36.44).
- An AWS Academy Learner Lab account with an active session.
- A bash-capable shell to run `verify-cloud.sh` (Git Bash on Windows).

## AWS configuration

- Region: `us-east-1` (fixed by AWS Academy Learner Lab; cannot be changed)
- Resource naming: `sentinel-frontend`, `sentinel-backend`, `sentinel-db`, `sentinel-alerts`

## Deploy (cloud)

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars   # then fill in db_password and alert_email
terraform init
terraform apply
```

Expected time: ~3–5 minutes (RDS is the slowest part).

**One manual step is required**: after applying, check the inbox for the `alert_email` address for an SNS subscription confirmation email and click the confirmation link. No Critical-vulnerability notifications are delivered until this is done.

## Verify (cloud)

```bash
./verify-cloud.sh
```

Run from the repository root. Checks that both EC2 instances and RDS are running, that the backend and frontend are reachable, and performs a real write-then-read of an asset through the API and RDS - confirming a genuine end-to-end interaction, not just that the resources exist.

## Access the application (cloud)

```bash
cd infra
terraform output frontend_public_ip
```

Then open `http://<that-ip>:3000` in a browser.

## Redeploying after a change (cloud)

Unlike the local Vagrant setup, the cloud instances fetch the application code by cloning the GitHub repository fresh at boot - they don't have a live synced folder, so an already-running instance won't pick up a new commit on its own. To redeploy after pushing a change:

```bash
terraform apply -replace="aws_instance.backend"   # or aws_instance.frontend
```

This destroys and recreates that instance

## Remove everything (cloud)

```bash
cd infra
terraform destroy
```

This deletes both EC2 instances, the RDS database, the SNS topic, and its subscription. The RDS instance is configured with `skip_final_snapshot = true`, so **all data is permanently deleted with no backup taken** - a deliberate simplification for this assignment, not an oversight.

## Repository structure (cloud)

```
infra/
  main.tf                      # All AWS resources: security groups, RDS, EC2 instances, SNS, IAM role reference
  variables.tf                 # Declares db_password and alert_email
  terraform.tfvars.example     # Documents the required variables (no real values)
  backend-user-data.sh.tpl     # Backend EC2 boot script
  frontend-user-data.sh.tpl    # Frontend EC2 boot script
verify-cloud.sh                # Automated check for the AWS deployment
```




