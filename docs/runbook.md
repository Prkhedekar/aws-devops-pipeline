# Runbook — Task API

How to diagnose and fix common problems. Add an entry every time you solve something new.

## Quick health check

```bash
curl http://<public_ip>/health      # is the app process up?
curl http://<public_ip>/ready       # can the app reach the database?
kubectl get pods                     # are pods Running and Ready?
kubectl get hpa                      # current replica count and CPU usage
```

## API returns 503 on `/ready`

**Meaning:** the app is running but cannot reach Postgres.

1. `kubectl get pods -l app.kubernetes.io/component=postgres`: is Postgres running?
2. `kubectl logs statefulset/taskapi-taskapi-postgres`: look for startup or disk errors.
3. `kubectl describe pvc`: is the volume bound? Is the disk full?
4. Check the DB secret: `kubectl get secret taskapi-taskapi-db -o jsonpath='{.data.url}'` (base64).

## Pods stuck in `ImagePullBackOff`

1. `kubectl describe pod <pod>`: read the *Events* section.
2. Does the tag exist in GHCR? Check the CI run that should have pushed it.
3. Is the GHCR package public? Private packages need an image pull secret.

## Pods in `CrashLoopBackOff` or restarting

1. `kubectl logs <pod> --previous`: logs from the crashed container.
2. `kubectl get pod <pod> -o jsonpath='{.status.containerStatuses[0].lastState.terminated}'`
   - **exit 3** with `Application startup failed`: the app itself failed. Read the log.
   - **exit 137**: Kubernetes killed it. Check events for `Liveness probe failed`.
3. `kubectl get events --field-selector involvedObject.name=<pod>`: probe failures and kills.
4. Common causes: wrong `DATABASE_URL`, Postgres not ready yet, or a probe that is too strict for startup time.

> **Seen in practice:** on first deploy both replicas ran `CREATE TABLE` at once and one crashed
> (`UniqueViolation ... tasks_id_seq already exists`). Fixed with a Postgres advisory lock in
> `init_db()`. Next, slow Postgres volume provisioning made the liveness probe kill pods still
> waiting for the DB (exit 137). Fixed with a `startupProbe` and a 5s DB `connect_timeout`.

## Site unreachable

1. Is the instance running? `aws ec2 describe-instances --filters Name=tag:Name,Values=taskapi-dev`
2. `kubectl get ingress` and `kubectl -n kube-system get pods`: is Traefik running?
3. Did your home IP change? SSH and kubectl only accept `allowed_cidr`. Update `terraform.tfvars` and re-apply.

## Rollback a bad release

```bash
helm history taskapi
helm rollback taskapi <revision>
```
