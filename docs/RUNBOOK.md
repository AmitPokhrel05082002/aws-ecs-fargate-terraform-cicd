# Runbook

Day-to-day operations for the ECS platform. Everything here can be done by any engineer with access to the GitHub repository; production deploys need approval from a required reviewer.

## Deploy a change

1. Open a pull request. CI runs app tests, builds the Docker image and checks the Terraform.
2. Merge to `main`. The **Deploy** workflow:
   1. builds the image and tags it with the first 12 characters of the git SHA,
   2. deploys it to **staging** and waits until the service is stable,
   3. pauses for approval on **production**.
3. Check staging: `curl http://<staging-alb>/` should show the new `version`.
4. In the workflow run, click **Review deployments → production → Approve**.
5. The same image is deployed to production. The job finishes only when the new tasks pass health checks.

If new tasks fail their health checks, ECS rolls back to the previous version automatically (deployment circuit breaker) and the workflow fails.

## Roll back

1. Find the last good image tag: the **Deploy** run summary shows it, or run
   ```bash
   aws ecr describe-images --repository-name sample-saas \
     --query 'sort_by(imageDetails,&imagePushedAt)[-10:].imageTags' --output text
   ```
2. **Actions → Deploy → Run workflow**, choose the environment and paste the tag.
3. For production, approve the deployment.

## Change infrastructure

1. Edit the modules in `infra/modules` (both environments) or a `terraform.tfvars` (one environment).
2. Open a pull request so CI checks formatting and validity.
3. After merge, apply staging first, then production:
   ```bash
   make plan ENV=staging     # review the plan
   make apply ENV=staging
   make plan ENV=production
   make apply ENV=production
   ```

Changes to task settings (CPU, memory, environment variables) create a new task definition revision. They go live on the **next app deploy**, which copies the latest revision. To apply them immediately, re-run the last deploy for that environment.

## Logs and debugging

| What | Where |
|---|---|
| App logs | CloudWatch log group `/ecs/sample-saas-<env>` |
| Deploy events | ECS console → cluster → service → **Deployments** and **Events** |
| Database logs | CloudWatch log group `/aws/rds/instance/sample-saas-<env>/postgresql` |

```bash
aws logs tail /ecs/sample-saas-staging --follow
```

### Common problems

| Symptom | Likely cause | Fix |
|---|---|---|
| Deploy job fails at "Check the image exists" | Wrong or mistyped tag | Copy the tag from the Deploy run summary |
| `AccessDenied` on `sts:AssumeRoleWithWebIdentity` | GitHub environment name or repository does not match the IAM trust policy | Check `github_repo` in bootstrap and the environment names |
| Tasks stop with `CannotPullContainerError` | Tasks can't reach ECR (NAT or route problem) | Check the NAT gateway and the private app route table |
| Targets unhealthy in the ALB | App not listening on 8080 or `/health` failing | Check app logs; confirm the security group allows ALB → app on 8080 |
| `/db` returns 503 | Secret, TLS or security group issue | Check app logs for the error; confirm the DB security group allows the app security group |

## Secrets and key rotation

- **Database password:** generated and rotated by RDS in Secrets Manager. No action needed. The app caches the secret for 5 minutes and re-reads it automatically if authentication fails after a rotation.
- **KMS key:** automatic yearly rotation is enabled. Old key material stays available, so existing S3 objects and RDS data remain readable.
- **CI credentials:** none stored. GitHub Actions gets temporary credentials through OIDC for each run.

## Onboarding a new engineer

1. Give them write access to the GitHub repository.
2. To approve production deploys, add them to the `production` environment's required reviewers.
3. To run Terraform, give them an AWS IAM role with permissions to manage this stack and access to the state bucket.
