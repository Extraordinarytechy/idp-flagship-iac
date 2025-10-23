---

# Project 1: Flagship IDP - Infrastructure (idp-flagship-iac)

Welcome!
This repository holds the Terraform code responsible for building the cloud infrastructure for the Flagship Internal Developer Platform (IDP) project.
This is the foundation upon which our FastAPI application (**idp-flagship-app**) gets deployed via a GitOps workflow managed in the **idp-k8s-manifests** repository.

The goal here is to create a reliable, repeatable, and secure multi-environment setup (starting with `dev`) on AWS using Infrastructure as Code.

---

## Architecture Overview

This Terraform configuration provisions the following core components in AWS:

* **VPC & Networking:**
  A custom Virtual Private Cloud (VPC) with public and private subnets across multiple Availability Zones, NAT Gateway for outbound private traffic, and necessary routing.
  Subnets are specifically tagged so EKS knows how to use them.

* **EKS Cluster:**
  An Elastic Kubernetes Service (EKS) cluster, including the control plane and managed node groups (EC2 instances) launched into private subnets.
  IRSA (IAM Roles for Service Accounts) is enabled for secure pod-level permissions.

* **RDS Database:**
  A PostgreSQL database instance running in the private subnets, configured with a dedicated security group allowing access only from the EKS cluster.

* **ECR Repository:**
  An Elastic Container Registry (ECR) repository to store the Docker images built by our CI/CD pipeline.

* **IAM Roles:**

  * Roles for the EKS cluster and node groups.
  * An OIDC-integrated role for GitHub Actions, allowing secure, keyless authentication for pushing images to ECR.
  * An IRSA role stub for a potential RDS Snapshot Manager (part of the original blueprint, implementation details might be added later).

---

## Overall Project Flow

```
graph LR
    A[Developer pushes code to idp-flagship-app] --> B(GitHub Action Triggered);
    B --> C{Build & Push Docker Image};
    C --> D[AWS ECR];
    B --> E{Checkout idp-k8s-manifests};
    E --> F{Update Image Tag in patch-deployment.yml};
    F --> G[Push Commit to idp-k8s-manifests];
    H(ArgoCD on EKS) -- Watches --> G;
    H --> I{Detects Change};
    I --> J[Pulls Manifests];
    J --> K(Applies Manifests to EKS);
    K --> L[App Deployed/Updated on EKS];
    D -- Image Pulled By --> L;
```

---

## Tech Stack

* **Cloud Provider:** AWS
* **Infrastructure as Code:** Terraform (v1.3+)
* **Core AWS Services:** EKS, RDS (PostgreSQL), VPC, EC2, ECR, IAM, S3 (for Terraform state), DynamoDB (for Terraform state locking)
* **Container Orchestration:** Kubernetes
* **Terraform Modules:** terraform-aws-modules for VPC, EKS, and RDS

---

## Repository Structure

This project follows a **multi-repo strategy:**

| Repository                        | Description                                                                                             |
|----------------------------------|---------------------------------------------------------------------------------------------------------|
| [idp-flagship-app](https://github.com/Extraordinarytechy/idp-flagship-app)             | Contains the FastAPI application code, Dockerfile, and GitHub Actions CI/CD workflow.                   |
| [idp-flagship-iac](https://github.com/Extraordinarytechy/idp-flagship-iac) (this repo) | Contains Terraform code to build the AWS infrastructure.                                                |
| [idp-k8s-manifests](https://github.com/Extraordinarytechy/idp-k8s-manifests)            | Contains Kubernetes manifests (using Kustomize overlays) defining desired app state, watched by ArgoCD. |

---

## Setup & Prerequisites

### 1. AWS Account Setup

* **IAM User for Terraform:**
  Create an IAM user (e.g., `terraform-admin`) with `AdministratorAccess` (acceptable for this portfolio setup, not for production).
  Generate an Access Key and Secret Key for this user.

* **Configure AWS CLI:**
  Run:

  ```bash
  aws configure
  ```

  Provide the keys from above.

* **S3 Backend Bucket:**
  Create a bucket named `backend-proj-terra-form` (or update `backend.tf` accordingly).
  Enable **versioning**.

* **DynamoDB Lock Table:**
  Create a DynamoDB table named `terraform-state-lock` with partition key `LockID` (String).

* **GitHub OIDC Provider:**
  In the AWS IAM console → **Identity providers**, add:

  * Provider URL: `token.actions.githubusercontent.com`
  * Audience: `sts.amazonaws.com`

---

### 2. Local Tools

Install the following:

* Terraform (v1.3+)
* AWS CLI
* kubectl
* aws-iam-authenticator

---

### 3. GitHub Setup

* **Create Repositories:**

  * `idp-flagship-app`
  * `idp-flagship-iac`
  * `idp-k8s-manifests`

* **Personal Access Token (PAT):**
  Generate a classic PAT with `repo` and `workflow` scopes.

* **Add Repository Secrets** (in `idp-flagship-app` → Settings → Secrets and variables → Actions):

  | Secret              | Description                                   |
  | ------------------- | --------------------------------------------- |
  | `AWS_REGION`        | AWS region (e.g., `us-east-1`)                |
  | `GH_PAT`            | The PAT created above                         |
  | `MANIFESTS_REPO`    | e.g., `YourUsername/idp-k8s-manifests`        |
  | `AWS_ROLE_DEV_ARN`  | Placeholder (to be updated after first apply) |
  | `AWS_ROLE_PROD_ARN` | Placeholder or same as dev if only testing    |

* **Production Environment Rule:**
  Go to **Settings > Environments**, create an environment named `production`, and add yourself as a required reviewer.

---

### 4. Initial Code Push

* Add appropriate `.gitignore` files to each repository (especially ignore `*.tfvars` in infra repo).
* Push your initial code to all repositories.
* The first workflow run in `idp-flagship-app` may fail — this is expected.

---

## Deployment Workflow

### 1. Deploy Infrastructure (Dev)

```bash
terraform init
terraform workspace new dev     
terraform workspace select dev
terraform apply -var-file="dev.tfvars"
```

After apply completes:

* Copy the output `github_actions_role_arn`
* Update `AWS_ROLE_DEV_ARN` secret in `idp-flagship-app` repo.

---

### 2. Connect kubectl & Install ArgoCD

```bash
aws eks update-kubeconfig --name <cluster-name>
kubectl get nodes
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Then in your local `idp-k8s-manifests` repo:

```bash
kubectl apply -f argocd/app-of-apps-dev.yaml
```

---

### 3. Trigger Application Deployment (Dev)

* Make a code change in `idp-flagship-app`
* Commit and push:

  ```bash
  git push origin main
  ```
* GitHub Actions builds → pushes → updates manifests → ArgoCD deploys to EKS.

Check pods:

```bash
kubectl get pods -n default
```

---

### 4. Deploying to Production (Conceptual)

```bash
terraform workspace select prod
terraform apply -var-file="prod.tfvars"
```

Install ArgoCD in prod cluster and apply:

```bash
kubectl apply -f argocd/app-of-apps-prod.yaml
```

Trigger deployment:

```bash
git tag v1.0.1
git push origin v1.0.1
```

Approve deployment in GitHub Actions UI.

---

### 5. Shutdown (Dev Environment)

To stop charges:

```bash
terraform destroy -var-file="dev.tfvars"
```

---

## Notes & Troubleshooting

Common issues and fixes during setup:

| Issue                             | Cause                                              | Fix                                                                                 |
| --------------------------------- | -------------------------------------------------- | ----------------------------------------------------------------------------------- |
| **AWS Provider Version Conflict** | AWS provider v6 incompatible with older EKS module | Add constraint `~> 5.40` in `providers.tf`                                          |
| **RDS Module Family Missing**     | Missing `family` argument                          | Add `family = "postgres15"`                                                         |
| **OIDC Policy Missing Action**    | Missing `sts:AssumeRoleWithWebIdentity`            | Add it to trust policy                                                              |
| **Reserved Username**             | PostgreSQL reserves `admin`                        | Use `dbadmin`                                                                       |
| **EKS Timeout**                   | Default 30m not enough                             | Add `cluster_timeouts` block with 60m                                               |
| **VPC/Subnet Mismatch**           | EKS creating separate VPC due to missing tags      | Add `public_subnet_tags` and `private_subnet_tags` with `kubernetes.io/cluster/...` |
| **kubectl i/o timeout**           | EKS API private                                    | Enable `cluster_endpoint_public_access = true`                                      |
| **kubectl credentials error**     | Missing `aws-iam-authenticator`                    | Install and re-run `aws eks update-kubeconfig`                                      |
| **ECR Push 403**                  | Missing permissions                                | Add granular ECR actions in IAM policy                                              |
| **Workflow file mismatch**        | Filename typo                                      | Rename to `patch-deployment.yml` or fix env variable                                |
| **Manual cleanup needed**         | Orphaned AWS resources                             | Manually delete before next `apply`                                                 |

---

## Future Improvements

* Integrate AWS Secrets Manager for RDS password
* Add automated tests for CI/CD pipeline
* Introduce monitoring & alerting (Observability Hub, Ansible)
* Add staging environment
* Explore ArgoCD ApplicationSets for multi-app management


