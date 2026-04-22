# CloudNative Task Manager — End-to-End DevOps Project

> **A freelance infrastructure engagement delivering a production-grade, cloud-native deployment pipeline on AWS — covering containerisation, Kubernetes orchestration, Infrastructure as Code, CI/CD automation, and observability.**

---

## Table of Contents

1. [Problem Statement](#1-problem-statement)
2. [Solution Overview](#2-solution-overview)
3. [Technology Stack](#3-technology-stack)
4. [Project Structure](#4-project-structure)
5. [Project Sections](#5-project-sections)
   - [Section 0 — Bootstrap: OIDC Trust & IAM Roles for CI/CD](#section-0--bootstrap-oidc-trust--iam-roles-for-cicd)
   - [Section 1 — Application Development & Containerisation](#section-1--application-development--containerisation)
   - [Section 2 — AWS Infrastructure with Terraform (IaC)](#section-2--aws-infrastructure-with-terraform-iac)
   - [Section 3 — Container Registry (AWS ECR)](#section-3--container-registry-aws-ecr)
   - [Section 4 — Kubernetes Workloads on EKS](#section-4--kubernetes-workloads-on-eks)
   - [Section 5 — CI/CD Pipeline with GitHub Actions](#section-5--cicd-pipeline-with-github-actions)
   - [Section 6 — Monitoring with Prometheus & Grafana](#section-6--monitoring-with-prometheus--grafana)
6. [Architecture Diagram](#6-architecture-diagram)
7. [Getting Started](#7-getting-started)
8. [Environment Variables](#8-environment-variables)
9. [Lessons Learned & Engineering Decisions](#9-lessons-learned--engineering-decisions)
10. [Author](#10-author)

---

## 1. Problem Statement

### Context

A growing startup had been running their task management web application on a single EC2 instance — a setup that served them well in early days but had become a critical liability as the product scaled. The engineering team was shipping features faster than the infrastructure could keep up, and deployments had become a manual, error-prone process that required someone to SSH into the server, pull the latest code, and restart services by hand.

### The Pains

The client came with four specific, measurable problems:

**1. Deployment downtime.** Every release — no matter how small — took the application offline for several minutes. Customers noticed. Support tickets spiked on release days. The team began avoiding deployments, which caused releases to batch up and become riskier.

**2. Zero fault tolerance.** When the single EC2 instance experienced a hardware fault or an OS-level crash (which happened twice in six months), the application was completely unavailable until a developer manually provisioned and configured a replacement. There was no automated recovery.

**3. No infrastructure reproducibility.** The server had been hand-configured over eighteen months. Nobody had a complete record of what was installed, what version, or how it was configured. "It works on the server" was a real and frequent phrase. Spinning up a staging environment meant a full day of guesswork.

**4. No visibility.** When the application slowed down or users reported errors, the team had no dashboards, no alerting, and no historical metrics. Debugging meant tailing logs on a live server and hoping to catch the problem in the act.

### The Engagement

The client engaged me as a freelance DevOps/Cloud Engineer to design and implement a modern, cloud-native infrastructure that would solve all four problems without requiring a full-time infrastructure team to maintain it. The solution needed to be:

- **Automated** — deployments triggered by code pushes, not human intervention
- **Resilient** — self-healing workloads that recover from failures automatically
- **Reproducible** — all infrastructure defined as code, so any environment can be recreated in minutes
- **Observable** — real-time dashboards and alerting so the team can see what the system is doing at all times

### What This Project Delivers

This repository is the complete implementation of that engagement. It covers every layer of the stack: a containerised two-tier application, cloud infrastructure provisioned entirely with Terraform, workloads orchestrated on AWS EKS (Kubernetes), a GitHub Actions CI/CD pipeline that runs on every commit, and a Prometheus + Grafana monitoring stack running inside the cluster. It is intentionally built **without** packaging abstractions like Helm in order to develop deep, first-principles understanding of Kubernetes manifests before introducing templating layers.

---

## 2. Solution Overview

```
Developer pushes code to GitHub
        │
        ▼
GitHub Actions CI/CD Pipeline
  ├── Runs tests
  ├── Builds Docker images (frontend + backend)
  ├── Tags images with Git commit SHA
  ├── Pushes images to AWS ECR
  └── Applies updated Kubernetes manifests to EKS
        │
        ▼
AWS EKS Cluster (Terraform-provisioned VPC)
  ├── Frontend Deployment  ──► Service ──► Ingress ──► Internet
  ├── Backend Deployment   ──► Service (ClusterIP)
  ├── PostgreSQL StatefulSet ──► PersistentVolumeClaim (EBS)
  └── Monitoring Namespace
        ├── Prometheus  (scrapes all pods)
        └── Grafana     (dashboards + alerts)
```

---

## 3. Technology Stack

| Layer | Tool / Service | Purpose |
|---|---|---|
| Application — Frontend | React (Vite) | User interface |
| Application — Backend | Node.js + Express | REST API |
| Application — Database | PostgreSQL 16 | Persistent data store |
| Containerisation | Docker | Build and package application images |
| Local Dev | Docker Compose | Run full stack locally |
| IaC | Terraform | Provision all AWS infrastructure |
| Container Registry | AWS ECR | Store and version Docker images |
| Orchestration | AWS EKS (Kubernetes) | Run, scale, and heal workloads |
| K8s Manifests | Raw YAML (no Helm) | Intentional — learn manifests first |
| CI/CD | GitHub Actions | Automate build, push, deploy on every push |
| Monitoring — Metrics | Prometheus | Scrape and store cluster metrics |
| Monitoring — Dashboards | Grafana | Visualise metrics, configure alerts |
| Cloud Provider | AWS | VPC, EKS, ECR, EBS, IAM, ALB |
| AWS Auth (CI/CD) | OIDC (keyless) | GitHub Actions → AWS, no static keys |

---

## 4. Project Structure

```
cloudnative-task-manager/
│
├── README.md                          ← You are here
│
├── app/                               ← Application source code
│   ├── frontend/                      ← React (Vite) frontend
│   │   ├── public/
│   │   ├── src/
│   │   │   ├── components/
│   │   │   ├── pages/
│   │   │   ├── App.jsx
│   │   │   └── main.jsx
│   │   ├── Dockerfile                 ← Multi-stage: build → nginx serve
│   │   ├── nginx.conf                 ← Custom nginx config for SPA routing
│   │   ├── package.json
│   │   └── .dockerignore
│   │
│   └── backend/                       ← Node.js + Express REST API
│       ├── src/
│       │   ├── routes/
│       │   ├── controllers/
│       │   ├── models/
│       │   └── index.js
│       ├── Dockerfile                 ← Multi-stage: install → run
│       ├── package.json
│       └── .dockerignore
│
├── docker-compose.yml                 ← Local full-stack development
├── .env.example                       ← Environment variable template
│
├── terraform/                         ← All AWS infrastructure as code
│   ├── main.tf                        ← Root module — calls all child modules
│   ├── variables.tf                   ← Input variable declarations
│   ├── outputs.tf                     ← Exported values (cluster name, ECR URLs etc.)
│   ├── versions.tf                    ← Terraform + provider version locks
│   ├── terraform.tfvars.example       ← Variable values template
│   │
│   └── modules/
│       ├── vpc/                       ← VPC, subnets, IGW, NAT GW, route tables
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       │
│       ├── eks/                       ← EKS cluster, node groups, IAM roles
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       │
│       └── ecr/                       ← ECR repositories for frontend + backend
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
│
├── bootstrap/                         ← ⚠️  RUN ONCE MANUALLY before everything else
│   │                                      Sets up the trust between GitHub Actions and AWS
│   │                                      so the pipeline never needs stored AWS credentials
│   │
│   ├── main.tf                        ← Root: calls oidc + github_role modules
│   ├── variables.tf                   ← github_org, github_repo, aws_region, project_name
│   ├── outputs.tf                     ← Prints the role ARN to paste into GitHub Secrets
│   ├── versions.tf                    ← Pinned provider versions (separate from main tf)
│   ├── terraform.tfvars.example       ← Template — copy to terraform.tfvars, never commit
│   │
│   └── modules/
│       │
│       ├── oidc_provider/             ← Creates the GitHub OIDC Identity Provider in AWS IAM
│       │   ├── main.tf                ← aws_iam_openid_connect_provider resource
│       │   │                              thumbprint: GitHub's TLS cert fingerprint
│       │   │                              url: https://token.actions.githubusercontent.com
│       │   ├── variables.tf
│       │   └── outputs.tf             ← Outputs the OIDC provider ARN
│       │
│       └── github_actions_role/       ← IAM Role that GitHub Actions will assume via OIDC
│           ├── main.tf                ← Three resources live here:
│           │                          │
│           │                          │  1. aws_iam_role  (the role itself)
│           │                          │     Trust policy: allows sts:AssumeRoleWithWebIdentity
│           │                          │     Condition: token sub must match
│           │                          │     "repo:<org>/<repo>:ref:refs/heads/main"
│           │                          │     (only YOUR repo's main branch can assume this)
│           │                          │
│           │                          │  2. aws_iam_policy  (what the role is allowed to do)
│           │                          │     Permissions granted:
│           │                          │       - ecr:GetAuthorizationToken
│           │                          │       - ecr:BatchCheckLayerAvailability
│           │                          │       - ecr:PutImage (push images)
│           │                          │       - ecr:InitiateLayerUpload / UploadLayerPart
│           │                          │       - eks:DescribeCluster (get kubeconfig)
│           │                          │       - sts:GetCallerIdentity (verify identity)
│           │                          │
│           │                          │  3. aws_iam_role_policy_attachment
│           │                          │     Attaches the policy to the role
│           │                          │
│           ├── variables.tf           ← oidc_provider_arn, github_org, github_repo
│           └── outputs.tf             ← role_arn (copy this into GitHub → Settings → Secrets)
│   │
│   ├── namespaces/
│   │   └── namespaces.yaml            ← production + monitoring namespaces
│   │
│   ├── frontend/
│   │   ├── deployment.yaml            ← Frontend Deployment (replicas, probes, limits)
│   │   ├── service.yaml               ← ClusterIP Service
│   │   ├── hpa.yaml                   ← HorizontalPodAutoscaler
│   │   └── configmap.yaml             ← Frontend runtime config (API base URL etc.)
│   │
│   ├── backend/
│   │   ├── deployment.yaml            ← Backend Deployment
│   │   ├── service.yaml               ← ClusterIP Service
│   │   ├── hpa.yaml                   ← HorizontalPodAutoscaler
│   │   ├── configmap.yaml             ← Non-sensitive config (DB host, port, name)
│   │   └── secret.yaml                ← DB credentials (base64, gitignored)
│   │
│   ├── database/
│   │   ├── statefulset.yaml           ← PostgreSQL StatefulSet
│   │   ├── service.yaml               ← Headless + ClusterIP Service
│   │   ├── pvc.yaml                   ← PersistentVolumeClaim (EBS StorageClass)
│   │   ├── configmap.yaml             ← DB init config
│   │   └── secret.yaml                ← DB root password (gitignored)
│   │
│   ├── ingress/
│   │   ├── ingress.yaml               ← Ingress resource (AWS LB Controller)
│   │   └── ingress-class.yaml         ← IngressClass definition
│   │
│   └── monitoring/
│       ├── namespace.yaml
│       ├── prometheus/
│       │   ├── configmap.yaml         ← prometheus.yml scrape config
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   ├── pvc.yaml               ← Persistent storage for metrics
│       │   ├── rbac.yaml              ← ClusterRole + ClusterRoleBinding
│       │   └── servicemonitor.yaml    ← Which services Prometheus scrapes
│       │
│       └── grafana/
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── pvc.yaml
│           ├── configmap.yaml         ← Grafana datasource + dashboard config
│           └── secret.yaml            ← Admin password (gitignored)
│
├── .github/
│   └── workflows/
│       ├── ci.yml                     ← PR check: build + test (no deploy)
│       └── cd.yml                     ← Main branch: build → ECR → EKS deploy
│
├── scripts/
│   ├── bootstrap.sh                   ← First-time cluster setup (metrics-server, LB controller)
│   ├── port-forward-grafana.sh        ← Quick local access to Grafana
│   └── destroy.sh                     ← Tear down everything cleanly
│
└── docs/
    ├── architecture.png               ← Architecture diagram
    ├── grafana-dashboard.png          ← Screenshot of monitoring dashboard
    └── runbook.md                     ← How to deploy, rollback, debug, scale
```

---

## 5. Project Sections

---

### Section 0 — Bootstrap: OIDC Trust & IAM Roles for CI/CD

> **This section is run once, manually, from your local machine before any other section. It is a prerequisite for Section 5. Nothing in the CI/CD pipeline can work until this is done.**

**The problem it solves:**

GitHub Actions needs to talk to AWS — to push images to ECR and to deploy to EKS. The naive approach is to create an IAM user, generate an Access Key + Secret Key, and paste them into GitHub Secrets. This works, but it is a significant security liability: static credentials that never expire, stored in plaintext in GitHub, that if leaked give an attacker permanent AWS access until someone manually rotates them.

The correct approach is **OIDC (OpenID Connect)** — a keyless authentication mechanism where GitHub Actions proves its identity to AWS using a short-lived cryptographically signed token, AWS verifies the token against a trusted Identity Provider, and issues a temporary role session that expires when the workflow finishes. No credentials are ever stored anywhere.

**What OIDC actually does — the trust chain:**

```
Your GitHub repo (org/repo, branch: main)
        │
        │  GitHub generates a signed JWT token for this workflow run
        │  Token contains: repo name, branch, workflow name, run ID
        │
        ▼
AWS IAM — OIDC Identity Provider
        │
        │  AWS verifies the JWT signature against GitHub's public keys
        │  AWS checks the token's "sub" claim matches the condition
        │  in the IAM Role's trust policy:
        │  "repo:your-org/your-repo:ref:refs/heads/main"
        │
        ▼
AWS IAM Role (github-actions-role)
        │
        │  AWS issues temporary credentials (valid ~1 hour)
        │  STS: AccessKeyId + SecretAccessKey + SessionToken
        │  These are injected into the workflow environment
        │
        ▼
GitHub Actions workflow now has AWS access
  - Can push to ECR
  - Can call eks:DescribeCluster to get kubeconfig
  - Can run kubectl apply against EKS
  - Credentials expire automatically when job finishes
```

**Deliverables:**
- `bootstrap/modules/oidc_provider/` — Creates the GitHub OIDC Identity Provider in your AWS account (one per account, ever)
- `bootstrap/modules/github_actions_role/` — Creates the IAM Role with a least-privilege policy and a trust policy scoped to your exact repo and branch
- After `terraform apply`, the role ARN is printed as an output — you paste it into one GitHub Secret: `AWS_ROLE_ARN`
- That single secret is the only thing GitHub ever needs. No access keys. No secret keys.

**What you learn:**
- How OIDC federation works between an external identity provider (GitHub) and AWS IAM
- How IAM trust policies differ from permission policies — trust says *who can assume the role*, permissions say *what the role can do*
- Why scoping the trust condition to a specific repo and branch (`ref:refs/heads/main`) matters — without this condition, any GitHub Actions workflow anywhere could assume your role
- The principle of least privilege applied to CI/CD — the role can push to ECR and read EKS cluster config, nothing more. It cannot create EC2 instances, modify IAM, or access S3
- Why this bootstrap module is intentionally **separate state** from the main `terraform/` directory — the OIDC provider and role are account-level infrastructure with a different lifecycle. You create them once and never touch them again, whereas the VPC and EKS cluster get iterated on

**Why this section is Section 0 and not Section 5:**

The bootstrap IAM role must exist before the main `terraform/` infrastructure is applied, because `terraform/modules/eks/` will reference the role ARN to configure EKS access entries (which control which IAM principals can authenticate to the cluster). The dependency flows: bootstrap → terraform → k8s → CI/CD. You cannot skip ahead.

**Execution — run once from your local machine:**

```bash
# You must have AWS credentials configured locally with admin-level permissions
# (this is the only time in the project you use a personal IAM user)
aws sts get-caller-identity   # confirm you're authenticated

cd bootstrap
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars:
#   github_org  = "your-github-username-or-org"
#   github_repo = "cloudnative-task-manager"
#   aws_region  = "us-east-1"
#   project_name = "taskmanager"

terraform init
terraform plan
terraform apply

# After apply, copy the output:
# github_actions_role_arn = "arn:aws:iam::123456789012:role/taskmanager-github-actions-role"
```

**Then in your GitHub repository:**

```
GitHub repo → Settings → Secrets and variables → Actions → New repository secret

Name:  AWS_ROLE_ARN
Value: arn:aws:iam::123456789012:role/taskmanager-github-actions-role

Name:  AWS_REGION
Value: us-east-1

Name:  ECR_REGISTRY
Value: 123456789012.dkr.ecr.us-east-1.amazonaws.com

Name:  EKS_CLUSTER_NAME
Value: taskmanager-cluster
```

That is all. The CI/CD pipeline in `.github/workflows/cd.yml` references `AWS_ROLE_ARN` and uses the `aws-actions/configure-aws-credentials` action to assume it via OIDC at runtime.

**Key files:**
```
bootstrap/main.tf
bootstrap/modules/oidc_provider/main.tf
bootstrap/modules/github_actions_role/main.tf
bootstrap/outputs.tf                          ← prints the role ARN after apply
```

---

### Section 1 — Application Development & Containerisation

**Deliverables:**
- A working two-tier application: React frontend + Node.js/Express backend + PostgreSQL
- `Dockerfile` for frontend (multi-stage: Vite build → nginx)
- `Dockerfile` for backend (multi-stage: npm install → production run)
- `docker-compose.yml` for local full-stack development
- All images verified locally before any cloud infrastructure is touched

**What you learn:**
- Multi-stage Docker builds and why they matter (build image vs runtime image — the difference can be a 1 GB image vs a 120 MB image)
- The `.dockerignore` file and how it affects layer caching
- How containers communicate with each other on a Docker network
- Environment variable injection into containers at runtime
- Why `docker-compose` is your local Kubernetes before you have a cluster

**Why this section exists:**

Every decision you make in infrastructure — how pods communicate, how secrets are injected, what ports are exposed — is anchored in how the application actually works. If you provision a cluster before you understand your app's container behaviour, you will debug infrastructure and application problems at the same time, which is the fastest path to wasted hours. This section ensures the application runs perfectly in containers locally before a single line of Terraform is written.

**Key files:**
```
app/frontend/Dockerfile
app/backend/Dockerfile
docker-compose.yml
.env.example
```

---

### Section 2 — AWS Infrastructure with Terraform (IaC)

**Deliverables:**
- A production-grade VPC with public and private subnets across 2 Availability Zones
- Internet Gateway (public traffic in) + NAT Gateway (private pods reach internet for ECR pulls)
- EKS Cluster with a managed node group (EC2 t3.medium) in private subnets
- IAM roles for the cluster, node groups, and CI/CD pipeline (least-privilege)
- Remote Terraform state stored in an S3 bucket with DynamoDB state locking
- All infrastructure reproducible with a single `terraform apply`

**What you learn:**
- How AWS networking actually works: VPCs, CIDR blocks, route tables, subnets, gateways
- Why EKS nodes run in **private** subnets (they should never be directly internet-accessible)
- How IAM roles for service accounts (IRSA) work — how a Kubernetes pod gets AWS permissions without storing credentials
- Terraform module structure, `depends_on`, remote state, `terraform plan` vs `terraform apply`
- Why state locking matters (what happens if two people run `terraform apply` simultaneously)

**Why this section exists:**

Infrastructure that was clicked together in the AWS Console cannot be reproduced, audited, reviewed in a pull request, or version-controlled. IaC is not a nice-to-have — it is the baseline expectation of any serious engineering team. This section builds the habit of never touching the AWS Console to create resources. If it isn't in Terraform, it doesn't exist.

**VPC Architecture:**
```
Region: us-east-1
│
└── VPC (10.0.0.0/16)
    │
    ├── Public Subnets (10.0.1.0/24, 10.0.2.0/24)  — AZ-a, AZ-b
    │   ├── Internet Gateway
    │   ├── NAT Gateway (one per AZ for HA)
    │   └── AWS Load Balancer (ALB) lives here
    │
    └── Private Subnets (10.0.3.0/24, 10.0.4.0/24) — AZ-a, AZ-b
        └── EKS Worker Nodes live here
            (they pull images from ECR via NAT Gateway)
```

**Key files:**
```
terraform/main.tf
terraform/modules/vpc/
terraform/modules/eks/
terraform/modules/ecr/
```

---

### Section 3 — Container Registry (AWS ECR)

**Deliverables:**
- Two ECR repositories provisioned via Terraform: `taskmanager/frontend` and `taskmanager/backend`
- Images tagged with the Git commit SHA (not `latest` — never `latest` in production)
- Image lifecycle policies to automatically delete images older than 30 days (cost control)
- ECR scan-on-push enabled (free vulnerability scanning on every image push)

**What you learn:**
- Why `latest` is an anti-pattern in production (you lose traceability — you can't tell which code is running)
- How ECR authentication works with Docker (`aws ecr get-login-password`)
- How the CI/CD pipeline authenticates to ECR using OIDC (no static AWS keys stored in GitHub Secrets)
- Image lifecycle management and how uncontrolled ECR growth affects your AWS bill

**Why this section exists:**

The gap between "my image works on my machine" and "that exact image is running in production" is the container registry. ECR is the source of truth for what gets deployed. Understanding how to push, tag, pull, and manage images in a private registry is a fundamental skill for any cloud-native workflow.

**Image tagging strategy:**
```
# Bad (untraceable):
docker push 123456789.dkr.ecr.us-east-1.amazonaws.com/taskmanager/frontend:latest

# Good (every deploy is traceable to a Git commit):
docker push 123456789.dkr.ecr.us-east-1.amazonaws.com/taskmanager/frontend:a3f92c1
```

**Key files:**
```
terraform/modules/ecr/main.tf
.github/workflows/cd.yml  (push step)
```

---

### Section 4 — Kubernetes Workloads on EKS

**Deliverables:**
- `production` and `monitoring` namespaces
- Frontend: Deployment + Service + HorizontalPodAutoscaler + ConfigMap
- Backend: Deployment + Service + HPA + ConfigMap + Secret
- PostgreSQL: StatefulSet + Headless Service + PersistentVolumeClaim (EBS-backed)
- Ingress resource routing external traffic to the frontend service (via AWS Load Balancer Controller)
- All pods configured with readiness and liveness probes, resource requests and limits

**What you learn:**

*Deployments vs StatefulSets* — Why you can't just run PostgreSQL as a Deployment. StatefulSets give pods stable network identities and stable storage. Pod `postgres-0` always gets the same PVC. A Deployment gives no such guarantees.

*Services and ClusterIP* — How pods find each other inside the cluster. The backend pod doesn't connect to `10.0.3.47` — it connects to `postgres-service.production.svc.cluster.local`. Kubernetes DNS handles the rest.

*PersistentVolumeClaims* — How Kubernetes requests storage from AWS EBS. If a pod dies and is rescheduled, the same EBS volume reattaches. Your data survives.

*Secrets and ConfigMaps* — The difference between config (non-sensitive, goes in ConfigMap) and credentials (sensitive, goes in Secret). How both are injected into pods as environment variables.

*Readiness vs Liveness Probes* — Readiness gates traffic; Liveness gates restarts. Getting this wrong causes either cascading failures or pods that receive traffic before they're ready.

*HPA* — How Kubernetes automatically scales your Deployment based on CPU or memory, and why this requires the Metrics Server to be installed in the cluster.

**Why this section exists:**

This is the heart of the project and the section that separates engineers who have "used Kubernetes" from those who understand it. By writing raw YAML manifests without Helm, you are forced to understand every field — there is no template hiding the complexity. The frustrations you encounter here (wrong indentation, selector mismatches, probe failures, pod pending due to no PVC) are the exact frustrations that Helm was designed to abstract. You cannot appreciate the solution without living through the problem.

**Pod communication map:**
```
Internet
  │
  ▼
ALB (public subnet)
  │
  ▼
Ingress (k8s/ingress/ingress.yaml)
  │
  ├──► frontend-service (ClusterIP :80)
  │         │
  │         ▼
  │    frontend pods (nginx serving React build)
  │         │ (API calls to /api/*)
  │         ▼
  └──► backend-service (ClusterIP :3000)
            │
            ▼
       backend pods (Express API)
            │
            ▼
       postgres-service (Headless :5432)
            │
            ▼
       postgres-0 pod (StatefulSet)
            │
            ▼
       PersistentVolumeClaim → EBS Volume
```

**Key files:**
```
k8s/namespaces/
k8s/frontend/
k8s/backend/
k8s/database/
k8s/ingress/
```

---

### Section 5 — CI/CD Pipeline with GitHub Actions

**Deliverables:**
- `ci.yml` — runs on every pull request: installs dependencies, runs tests, builds Docker images (no push)
- `cd.yml` — runs on merge to `main`: builds images, tags with commit SHA, pushes to ECR, updates image tags in Kubernetes manifests, applies manifests to EKS cluster
- AWS authentication via OIDC (no static AWS Access Keys stored in GitHub Secrets)
- Deployment rollback documented in runbook

**What you learn:**
- GitHub Actions workflow syntax: triggers, jobs, steps, environment variables, secrets
- OIDC-based AWS authentication — how GitHub Actions proves its identity to AWS without storing credentials (this is the production-correct approach and most tutorials skip it)
- The difference between CI (validate) and CD (deploy) and why they are separate workflows
- Image tag propagation — how the pipeline gets the commit SHA into the Kubernetes manifest and applies it
- Why you never run `kubectl apply` from a developer's laptop in a team environment

**Why this section exists:**

Manual deployments are the enemy of reliability. Every manual step is an opportunity for human error, and every deployment that requires a developer's local environment to succeed is a deployment that can only happen when that developer is available. This section replaces the startup's original "SSH and restart" process with a fully automated, auditable pipeline where every deployment is triggered by a Git commit, traceable to a specific commit SHA, and logged in GitHub Actions.

**Pipeline flow:**
```
Push to main branch
        │
        ▼
┌──────────────────────────────────┐
│  Job 1: test                     │
│  - npm install                   │
│  - npm test                      │
└──────────────┬───────────────────┘
               │ (only if tests pass)
               ▼
┌──────────────────────────────────┐
│  Job 2: build-and-push           │
│  - Configure AWS credentials     │
│    (OIDC — no static keys)       │
│  - docker build frontend         │
│  - docker build backend          │
│  - docker push → ECR (SHA tag)   │
└──────────────┬───────────────────┘
               │
               ▼
┌──────────────────────────────────┐
│  Job 3: deploy                   │
│  - aws eks update-kubeconfig     │
│  - kubectl set image             │
│    deployment/frontend ...       │
│  - kubectl set image             │
│    deployment/backend  ...       │
│  - kubectl rollout status        │
│    (waits for success/failure)   │
└──────────────────────────────────┘
```

**Key files:**
```
.github/workflows/ci.yml
.github/workflows/cd.yml
```

---

### Section 6 — Monitoring with Prometheus & Grafana

**Deliverables:**
- Prometheus deployed in the `monitoring` namespace with persistent storage (EBS-backed PVC)
- RBAC configured so Prometheus can scrape metrics from all namespaces
- Prometheus scrape config targeting: all application pods, kube-state-metrics, node-exporter
- Grafana deployed with Prometheus as a pre-configured datasource
- Dashboards for: cluster resource usage, pod CPU/memory, HTTP request rates, PostgreSQL metrics, HPA scaling activity
- At least one alert rule: `PodCrashLooping` — fires if a pod restarts more than 3 times in 10 minutes

**What you learn:**
- The Prometheus pull model — Prometheus reaches out to scrape targets, targets don't push (this is the opposite of many monitoring systems and has important architectural implications)
- PromQL — Prometheus Query Language for writing metric queries and alert conditions
- How Grafana connects to data sources and how dashboards are defined in JSON (and version-controlled)
- Kubernetes RBAC for monitoring — why Prometheus needs a ClusterRole to scrape metrics across namespaces
- The difference between metrics (numbers over time — Prometheus) and logs (events — would use CloudWatch or Loki)
- Why monitoring is not optional: you cannot operate a system you cannot see

**Why this section exists:**

The client's original problem included zero visibility into application behaviour. This section directly solves that. More broadly, this section teaches a truth that only becomes obvious after you've been paged at 2am because of a problem that had been silently building for hours: **an unmonitored system is not a production system.** Knowing how to instrument, query, and alert on a Kubernetes cluster is one of the most valuable and most underrated skills in cloud engineering.

**What we monitor:**

| Metric | Why it matters |
|---|---|
| Pod CPU & memory usage | Catch resource exhaustion before pods are OOMKilled |
| Pod restart count | A restarting pod is a silent failure |
| HTTP request rate & latency | User-facing performance |
| HPA replica count over time | Understand scaling patterns and costs |
| PVC usage | Catch disk full before Postgres crashes |
| Node CPU & memory | Know when to scale the node group |

**Key files:**
```
k8s/monitoring/prometheus/
k8s/monitoring/grafana/
```

---

## 6. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        DEVELOPER WORKFLOW                        │
│                                                                  │
│   git push → GitHub → GitHub Actions CI/CD                      │
│                              │                                   │
│              ┌───────────────┴───────────────┐                  │
│              ▼                               ▼                  │
│         Run Tests                    Build Docker Images         │
│              │                               │                  │
│              └───────────────┬───────────────┘                  │
│                              ▼                                   │
│                     Push to AWS ECR                              │
│                     (tagged: :a3f92c1)                           │
│                              │                                   │
│                              ▼                                   │
│                  kubectl apply → EKS                             │
└──────────────────────────────┬──────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────┐
│                    AWS CLOUD (Terraform)                         │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                  VPC (10.0.0.0/16)                       │    │
│  │                                                          │    │
│  │  Public Subnets          Private Subnets                 │    │
│  │  ┌─────────────┐         ┌──────────────────────────┐   │    │
│  │  │ IGW + ALB   │────────►│   EKS Worker Nodes       │   │    │
│  │  │ NAT Gateway │         │   (EC2 t3.medium)        │   │    │
│  │  └─────────────┘         │                          │   │    │
│  │                          │  ┌────────────────────┐  │   │    │
│  │                          │  │  namespace:         │  │   │    │
│  │                          │  │  production         │  │   │    │
│  │                          │  │                     │  │   │    │
│  │                          │  │  [frontend pods]    │  │   │    │
│  │                          │  │  [backend pods ]    │  │   │    │
│  │                          │  │  [postgres-0    ]   │  │   │    │
│  │                          │  └────────────────────┘  │   │    │
│  │                          │  ┌────────────────────┐  │   │    │
│  │                          │  │  namespace:         │  │   │    │
│  │                          │  │  monitoring         │  │   │    │
│  │                          │  │                     │  │   │    │
│  │                          │  │  [prometheus   ]    │  │   │    │
│  │                          │  │  [grafana      ]    │  │   │    │
│  │                          │  └────────────────────┘  │   │    │
│  │                          └──────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  AWS ECR                AWS EBS               AWS IAM            │
│  (image store)          (PVC storage)         (OIDC roles)       │
└─────────────────────────────────────────────────────────────────┘
```

---

## 7. Getting Started

### Prerequisites

```bash
# Required tools
aws --version          # AWS CLI v2
terraform --version    # >= 1.6.0
docker --version       # >= 24.0
kubectl version        # >= 1.28
git --version
```

### Step 0 — Bootstrap IAM trust (run once, before anything else)

```bash
# Confirm your local AWS credentials have admin permissions
aws sts get-caller-identity

cd bootstrap
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set github_org, github_repo, aws_region, project_name

terraform init
terraform plan
terraform apply

# Copy the printed role ARN into GitHub:
# Repo → Settings → Secrets → AWS_ROLE_ARN
```

> After this step, your local AWS credentials are no longer needed for deployments.
> All subsequent AWS interactions happen through the GitHub Actions role.

### Step 1 — Clone and configure environment

```bash
git clone https://github.com/your-username/cloudnative-task-manager.git
cd cloudnative-task-manager
cp .env.example .env
# Edit .env with your values
```

### Step 2 — Run locally with Docker Compose

```bash
docker-compose up --build
# Frontend: http://localhost:3000
# Backend:  http://localhost:5000
# Postgres: localhost:5432
```

### Step 3 — Provision AWS infrastructure

```bash
cd terraform

# Initialise — downloads providers, configures remote state
terraform init

# Preview what will be created
terraform plan -var-file="terraform.tfvars"

# Create all infrastructure (~12 minutes for EKS)
terraform apply -var-file="terraform.tfvars"
```

### Step 4 — Configure kubectl

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name taskmanager-cluster

kubectl get nodes   # verify connection
```

### Step 5 — Deploy Kubernetes workloads

```bash
# Apply in dependency order
kubectl apply -f k8s/namespaces/
kubectl apply -f k8s/database/
kubectl apply -f k8s/backend/
kubectl apply -f k8s/frontend/
kubectl apply -f k8s/ingress/
kubectl apply -f k8s/monitoring/prometheus/
kubectl apply -f k8s/monitoring/grafana/

# Verify everything is running
kubectl get all -n production
kubectl get all -n monitoring
```

### Step 6 — Access Grafana

```bash
# Port-forward Grafana to your machine
./scripts/port-forward-grafana.sh
# Then open: http://localhost:3000
# Default credentials are in k8s/monitoring/grafana/secret.yaml
```

### Teardown

```bash
# Delete K8s resources first (releases EBS volumes and Load Balancers)
kubectl delete -f k8s/ --recursive

# Then destroy Terraform infrastructure
cd terraform
terraform destroy -var-file="terraform.tfvars"
```

---

## 8. Environment Variables

| Variable | Used in | Description |
|---|---|---|
| `POSTGRES_HOST` | backend, k8s ConfigMap | Database hostname |
| `POSTGRES_PORT` | backend, k8s ConfigMap | Database port (default: 5432) |
| `POSTGRES_DB` | backend, k8s ConfigMap | Database name |
| `POSTGRES_USER` | k8s Secret | Database user |
| `POSTGRES_PASSWORD` | k8s Secret | Database password |
| `API_BASE_URL` | frontend ConfigMap | Backend API URL |
| `AWS_REGION` | CI/CD | Target AWS region |
| `ECR_REGISTRY` | CI/CD | ECR registry URL |
| `EKS_CLUSTER_NAME` | CI/CD | EKS cluster name for kubeconfig |

> ⚠️ Never commit `.env`, `terraform.tfvars`, or any `secret.yaml` files containing real values. All are listed in `.gitignore`.

---

## 9. Lessons Learned & Engineering Decisions

**Why a separate bootstrap Terraform module instead of putting IAM in the main terraform/?**
The OIDC Identity Provider and GitHub Actions IAM role are account-level infrastructure — they are created once and never destroyed for the life of the project (even if you tear down the VPC and EKS cluster 10 times). Mixing them with application infrastructure creates a dangerous coupling: a `terraform destroy` on the main stack could delete the IAM role mid-pipeline, locking you out of all future deployments. Separate state, separate lifecycle, separate concern. This mirrors how real infrastructure teams manage foundational IAM separately from workload infrastructure.

**Why no Helm?**
Helm is the Kubernetes package manager and is used in virtually every production environment. This project intentionally avoids it. Writing raw YAML manifests forces you to understand every field, every selector relationship, every API object from first principles. The frustrations — repetitive YAML, error-prone image tag updates, no templating — are instructional. Once you have felt these pains, Helm's value is immediately obvious and its abstractions make sense rather than being magic.

**Why PostgreSQL as a StatefulSet and not a Deployment?**
Deployments do not guarantee that a pod gets the same persistent volume when rescheduled. StatefulSets do. For any stateful workload (databases, message queues, search indices), this guarantee is not optional — losing it means potential data loss or corruption.

**Why OIDC for CI/CD instead of AWS Access Keys?**
Static AWS credentials stored in GitHub Secrets are a security liability — they never expire, they can be leaked in logs, and rotating them is manual. OIDC lets GitHub Actions assume an IAM role dynamically for the duration of a workflow run with no credentials stored anywhere. This is the AWS-recommended approach and the pattern used in professional environments.

**Why private subnets for EKS nodes?**
Worker nodes should never be directly reachable from the internet. Placing them in private subnets means all inbound traffic must pass through the Load Balancer, which is the only internet-facing component. NAT Gateways allow nodes to initiate outbound connections (to pull images from ECR) without being publicly addressable.



**Why terraform apply is not in the CD pipeline:
Infrastructure changes carry a different risk profile than
application changes. A bad app deployment is rolled back in
seconds with kubectl rollout undo. A bad terraform apply can
delete a VPC, a database, or an IAM role — recovery takes
hours and may involve data loss. The correct pattern is:
automated plan on PR, human-approved apply on merge.


**Why tag images with the commit SHA?**
The `latest` tag is meaningless for operations. If a pod is running `:latest`, you cannot tell which version of the code is deployed without inspecting the image itself. Tagging with the commit SHA makes every deployment fully traceable: you can look at a running pod, see its image tag, and find the exact Git commit — and therefore the exact code, the exact diff, and the exact pull request — that produced it.

---

## 10. Author

**[Your Name]**
Freelance DevOps & Cloud Engineer
- GitHub: [@your-username](https://github.com/your-username)
- LinkedIn: [your-linkedin](https://linkedin.com/in/your-profile)

---

*This project was built as a freelance engagement and is maintained as a public reference for end-to-end cloud-native infrastructure on AWS. All infrastructure costs approximately $X/month at the scale described. Remember to run `terraform destroy` when not in use.*
