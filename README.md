# Sentinel

Sentinel is a small web-based Cyber Asset and Vulnerability Management application. It lets an administrator keep track of IT assets such as servers, laptops and network devices, record vulnerabilities against them, give those vulnerabilities a severity level, and mark them as either open or fixed.

The dashboard gives a quick overview of the number of assets and vulnerabilities currently stored in the system.

# Assignment 2: AWS deployment

For Assignment 2, Sentinel has been moved from the local Vagrant setup used in Assignment 1 to Amazon Web Services.

The AWS version uses:

| Component | What it does |
|---|---|
| EC2 `sentinel-frontend` | Runs the React frontend on port 3000 |
| EC2 `sentinel-backend` | Runs the Node.js/Express API on port 5000 |
| RDS `sentinel-db` | Stores the asset and vulnerability data in PostgreSQL |
| SNS `sentinel-alerts` | Sends an email when a Critical vulnerability is added |

The frontend and backend run on separate EC2 instances. The browser loads the frontend from the frontend instance, then sends API requests directly to the backend.

The backend is the only part of the application that connects to the database.

# Requirements

To deploy the project you need:

- Terraform, tested with version 1.16.2
- AWS CLI v2, tested with version 2.36.44
- An AWS Academy Learner Lab account with an active session
- A shell that can run bash scripts, such as Git Bash on Windows

# AWS setup

The deployment uses the AWS region:

`us-east-1`

The main resources are named:

- `sentinel-frontend`
- `sentinel-backend`
- `sentinel-db`
- `sentinel-alerts`

# Deploying Sentinel

From the repository:

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
```

Open `terraform.tfvars` and enter the database password and the email address that should receive Critical vulnerability alerts.

Then run:

```bash
terraform init
terraform apply
```

The deployment normally takes a few minutes, with the RDS database usually taking the longest to create.

After the first deployment there is one manual step.

AWS SNS sends a confirmation email to the email address entered in `terraform.tfvars`. The link in this email must be clicked before SNS will actually send Critical vulnerability notifications.

# Accessing the application

Once Terraform has finished, run:

```bash
cd infra
terraform output frontend_public_ip
```

Then open:

```text
http://<frontend-ip>:3000
```

in a browser.

# Checking that the deployment works

The repository includes a script called:

```bash
./verify-cloud.sh
```

Run it from the root of the repository.

The script checks that both EC2 instances are running, that the RDS database is available, and that both the frontend and backend can be reached.

It also performs a real application test by creating an asset through the API, reading the assets back to make sure it was saved in the database, and then deleting the test asset again.

This checks that the application is actually working, rather than only checking that the AWS resources exist.

# Redeploying after a code change

The EC2 instances clone the project from GitHub when they are first created.

This means that if a new commit is pushed to GitHub, an already-running EC2 instance will not automatically download the new version.

To recreate either the backend or frontend instance, run:

```bash
terraform apply -replace="aws_instance.backend"
```

or:

```bash
terraform apply -replace="aws_instance.frontend"
```

Terraform will delete that EC2 instance and create a new one, which causes the boot script to run again and clone the latest version of the project.

# Security and trust boundaries

There are a few different parts of the system that have different levels of access.

## Frontend and backend

The frontend is publicly reachable on port 3000.

The backend is also publicly reachable on port 5000 because the browser sends API requests directly to it.

This means the backend is not hidden behind the frontend.

## Database

The RDS database is not publicly accessible.

It only accepts PostgreSQL connections on port 5432 from the backend EC2 instance.

This means someone on the internet cannot connect directly to the database, even if they know the database address.

The frontend also has no direct access to the database.

## Passwords and other secrets

The database password and notification email are stored in:

```text
infra/terraform.tfvars
```

This file is ignored by Git and is not committed to the repository.

A `terraform.tfvars.example` file is included instead, which shows which values are required without including the real values.

Terraform passes the database details to the backend during startup, and the backend reads them from its environment configuration.

There are no AWS access keys stored in the project.

The backend uses the AWS Academy `LabInstanceProfile` attached to the EC2 instance, which allows the AWS SDK to get temporary credentials automatically when it needs to publish a message to SNS.

One limitation of this setup is that Terraform also stores some sensitive values in its state file.

The Terraform state file is also ignored by Git and is not committed.

For this assignment this was a reasonable setup, but in a real production application I would use a dedicated secret storage service such as AWS Secrets Manager or Parameter Store instead.

# Removing the deployment

To remove all of the AWS resources, run:

```bash
cd infra
terraform destroy
```

This removes:

- both EC2 instances
- the RDS database
- the SNS topic
- the SNS subscription
- the networking and security groups created by Terraform

The RDS database is configured with:

```text
skip_final_snapshot = true
```

This means that destroying the deployment also permanently deletes the database and all of the Sentinel data stored inside it.

No final database backup is created.

This was done deliberately for the assignment because the deployment is intended to be recreated rather than kept permanently.

# Repository structure

```text
infra/
  main.tf
  variables.tf
  terraform.tfvars.example
  backend-user-data.sh.tpl
  frontend-user-data.sh.tpl

verify-cloud.sh
```

`main.tf` contains the AWS infrastructure.

`variables.tf` defines the values Terraform needs.

`terraform.tfvars.example` shows the required variables without containing real passwords or email addresses.

`backend-user-data.sh.tpl` contains the startup script for the backend EC2 instance.

`frontend-user-data.sh.tpl` contains the startup script for the frontend EC2 instance.

`verify-cloud.sh` checks that the deployed application is working.