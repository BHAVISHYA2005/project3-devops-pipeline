# DevOps Pipeline Project — Node.js → Docker → AWS EC2

A CI/CD reference project: a small Express app delivered by GitHub Actions to
EC2 through Amazon ECR, S3 and CodeDeploy, with all infrastructure defined in
Terraform.

The app is intentionally trivial. The subject of the repo is the delivery
pipeline around it.

---

## Architecture

```
                    GitHub Actions (one workflow, two jobs)
   push / PR  ──►  ┌──────────────────────────────────────────────┐
                   │ build-test                                   │
                   │   npm ci → npm test → docker build → Trivy   │
                   │   on main: push the scanned image to ECR     │
                   │   outputs: image digest                      │
                   └───────────────────────┬──────────────────────┘
                                           │ needs (main only)
                   ┌───────────────────────▼──────────────────────┐
                   │ deploy                                       │
                   │   bundle hooks → S3 → CodeDeploy → verify    │
                   └───────────────────────┬──────────────────────┘
                                           │
                                           ▼
             ┌──────────────────────────────────────────────┐
             │ EC2 t3.micro (Elastic IP)                    │
             │   CodeDeploy agent pulls the bundle from S3  │
             │   runs 4 hooks → docker pull by digest       │
             │   container on :3000                         │
             └──────────────────────────────────────────────┘
```

The image that Trivy scans is the image that gets deployed: `build-test` pushes
it once and `deploy` ships it by digest, so there is no second build.

## API

| Endpoint | Purpose |
|---|---|
| `GET /health` | Liveness. Used by Docker, CodeDeploy and the post-deploy check |
| `GET /api/info` | App name, version (git SHA), environment, Node version |
| `GET /api/greet?name=X` | Returns a greeting; defaults to `World` |

Unknown routes return a JSON `404`.

## Run locally

```bash
cd app
npm install
npm test                              # Jest, coverage thresholds enforced

docker compose up -d                  # http://localhost:3000
curl localhost:3000/health
docker compose down
```

## Pipeline

`.github/workflows/pipeline.yml` runs on every push and pull request.

**`build-test`** — install, test, build the image, scan it with Trivy
(HIGH/CRITICAL, `ignore-unfixed`). On a push to `main` it also pushes the image
to ECR and exposes the digest as a job output.

**`deploy`** — runs only when `AWS_ENABLED` is `true` and only on `main`.
It writes the image reference into the deployment bundle, uploads it to S3,
triggers CodeDeploy, waits for the result, then asserts that `/api/info` reports
the commit SHA that was just built.

No AWS credentials are needed for a fork or a pull request: every AWS step is
conditional and the `deploy` job is skipped.

## Infrastructure

`infra/` provisions the whole stack:

| Resource | Purpose |
|---|---|
| ECR repository | Stores images, keeps the last 10, scans on push |
| S3 bucket | Stores CodeDeploy revision bundles (private, versioned) |
| EC2 instance | Runs the CodeDeploy agent and the container |
| IAM instance profile | CodeDeploy + ECR pull permissions, no static keys |
| IAM service role | Permissions for CodeDeploy itself |
| Security group | HTTP, app port 3000, SSH |
| CodeDeploy app + group | In-place deploy, targets by `Name` tag, auto-rollback |
| Elastic IP | Stable endpoint for the health check |

## First-time AWS setup

1. Create the Terraform state bucket (`devops-pipeline-tfstate`) once, by hand.
2. `cd infra && terraform init && terraform apply`. Note the outputs.
3. Add repository **secrets**: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`,
   `AWS_REGION`, `S3_BUCKET`, `EC2_PUBLIC_DNS`.
4. Add repository **variable** `AWS_ENABLED` = `true`.
   Deployments are skipped while it is unset.
5. Push to `main`.

Use a scoped IAM user for CI (ECR push, S3 put, CodeDeploy create) rather than
root keys, and prefer OIDC federation over long-lived keys once you can.

## Deployment lifecycle on the instance

| Hook | Script | What it does |
|---|---|---|
| `ApplicationStop` | `stop.sh` | `docker rm -f` the old container (no-op on first deploy) |
| `BeforeInstall` | `install.sh` | Ensure Docker exists, prune images older than 7 days |
| `ApplicationStart` | `start.sh` | ECR login, pull by digest, run with limits and log rotation |
| `ValidateService` | `validate.sh` | Poll `/health`, dump container logs and fail on timeout |

Every hook is idempotent, because rollback re-runs them.

## Known limits

- **In-place deploys are not zero-downtime.** The old container is removed
  before the new one starts. Blue/green behind an ALB is the fix.
- Uses the **default VPC** and leaves SSH open by default — set
  `allowed_ssh_cidr`, and move to a dedicated VPC for anything real.
- Terraform state has **no locking** (no DynamoDB table); fine for one operator.
- The app has no database or persistence — this is a pipeline demo, not a
  service.
