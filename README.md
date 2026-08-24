# DevOps Pipeline Project — Node.js App → AWS EC2 via CodeDeploy

A complete CI/CD pipeline for a Node.js/Express application using **GitHub Actions**, **Docker**, and **AWS** (EC2 + CodeDeploy + ECR + S3). Infrastructure is defined with **Terraform** (IaC).

> **Runs fully locally right now** — no AWS account needed. The AWS deployment is triggered automatically once you add your credentials as GitHub Secrets.

---

## Architecture

```
                GitHub Actions (CI/CD)
   ┌──────────────────────────────────────────────┐
   │  push to main                                │
   │    │                                         │
   │    ├─ CI:  npm ci → npm test → docker build  │
   │    │        → Trivy vulnerability scan       │
   │    │                                         │
   │    └─ CD:  build image → push to ECR         │
   │             → package app → upload to S3     │
   │             → CodeDeploy deploy → health     │
   └──────────────────────────────────────────────┘
                        │
                        ▼
              ┌──────────────────┐
              │  AWS EC2 (t3.micro) │  ← CodeDeploy agent pulls & runs
              │  Docker container    │     the image from ECR
              │  on port 3000        │
              └──────────────────┘
```

## Project Structure

```
PROJECT3/
├── app/                        # Node.js/Express application
│   ├── src/                    # App source code
│   │   ├── app.js              # Express app (routes)
│   │   └── server.js           # Entry point
│   ├── test/                   # Jest unit tests (100% coverage)
│   ├── Dockerfile              # Multi-stage build, non-root user
│   └── package.json
├── .github/workflows/
│   ├── ci.yml                  # CI: install, test, build, scan
│   └── cd.yml                  # CD: ECR push + CodeDeploy deploy
├── deployment/
│   ├── appspec.yml             # CodeDeploy lifecycle hooks
│   └── scripts/                # stop/install/start/validate hooks
├── infra/                      # Terraform (AWS resources)
│   ├── main.tf                 # VPC, SG, EC2, IAM, S3, CodeDeploy, EIP
│   ├── variables.tf
│   ├── outputs.tf
│   └── user-data.sh            # EC2 bootstrap (installs CodeDeploy agent)
├── docker-compose.yml          # Run locally with a single command
└── README.md
```

## Run Locally (No AWS Required)

```bash
# 1. Run tests (Jest, 100% coverage)
cd app
npm install
npm test

# 2. Run the app in Docker
docker compose up -d

# 3. Verify
curl http://localhost:3000/health
curl http://localhost:3000/api/info
curl "http://localhost:3000/api/greet?name=DevOps"

# 4. Stop
docker compose down
```

**API Endpoints**

| Endpoint | Description |
|----------|-------------|
| `GET /health` | Health check (used by CodeDeploy `ValidateService`) |
| `GET /api/info` | App name, version, environment |
| `GET /api/greet?name=X` | Returns a greeting |

## CI/CD Pipeline

### Continuous Integration (`.github/workflows/ci.yml`)
Runs on every push/PR to `main`:
1. Checkout code
2. Setup Node 20
3. `npm ci` (clean, reproducible install)
4. `npm test` (Jest unit tests)
5. Build Docker image
6. **Trivy** vulnerability scan (fails build on HIGH/CRITICAL)

### Continuous Deployment (`.github/workflows/cd.yml`)
Runs on push to `main` **only when AWS secrets are configured** (auto-skips otherwise):
1. Build & push image to **Amazon ECR**
2. Package app + deployment scripts into a tarball
3. Upload revision to **S3**
4. Create **CodeDeploy** deployment (in-place on EC2)
5. Wait for success + verify `/health` on the EC2 endpoint

### CodeDeploy lifecycle (`.github/../deployment/appspec.yml`)
`ApplicationStop → BeforeInstall → ApplicationStart → ValidateService`

## Terraform Infrastructure (`infra/`)

Provisioned when you get AWS access:

| Resource | Purpose |
|----------|---------|
| Security Group | HTTP (80), app (3000), SSH (22) |
| IAM Role + Instance Profile | Lets EC2 talk to CodeDeploy |
| EC2 instance (t3.micro) | Runs the CodeDeploy agent + container |
| S3 bucket | Stores deployment revisions |
| CodeDeploy App + Group | In-place deploy, EC2 tag filter |
| Elastic IP | Stable public endpoint |

```bash
cd infra
terraform init
terraform plan
terraform apply -auto-approve   # replace suffix in variables.tf first
```

> Note: `infra/user-data.sh` hardcodes the `ap-south-1` region for the CodeDeploy agent installer — update it if you use a different region.

## Setting Up AWS (When You Get Access)

1. Run `terraform apply` to provision everything.
2. Add GitHub repository **Secrets**:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_REGION` (e.g. `ap-south-1`)
   - `S3_BUCKET` (from Terraform output)
   - `EC2_PUBLIC_DNS` (from Terraform output)
3. Push to `main` — the CD workflow deploys automatically.

> Use a scoped IAM user with least-privilege (ECR, S3, CodeDeploy permissions) rather than your root keys.

## Interview Talking Points

- **CI/CD**: Automated test → build → scan → deploy pipeline on GitHub Actions.
- **Security**: Multi-stage Docker build, non-root container user, Trivy image scanning, IAM least privilege.
- **Infrastructure as Code**: Entire AWS stack via Terraform (reproducible, reviewable).
- **Deployment strategy**: In-place CodeDeploy with health-check validation and zero-downtime container restarts.
- **Observability**: `/health` endpoint wired into deployment validation; container healthchecks.
