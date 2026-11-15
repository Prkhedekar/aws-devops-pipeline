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

## Requests failing during a deploy

**Measure it:** run a probe loop against the public URL during a rollout and count non-200 responses.

```bash
end=$((SECONDS+120)); ok=0; bad=0
while [ $SECONDS -lt $end ]; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 http://<public_ip>/health)
  [ "$code" = 200 ] && ok=$((ok+1)) || { bad=$((bad+1)); echo "$(date +%T) FAIL $code"; }
  sleep 0.25
done; echo "ok=$ok failed=$bad"
# in another terminal:  kubectl rollout restart deployment/taskapi-taskapi
```

**Symptoms:** `502` from Traefik, or dropped connections (`000`), only while old pods terminate.

**Cause:** Kubernetes removes a terminating pod from the Service and sends it SIGTERM *at the same time*.
The ingress can still route requests to a pod that has already exited.

**Fix:** a `preStop` sleep (10s) so the pod keeps serving until routing updates, with
`terminationGracePeriodSeconds: 30` to cover it.

> **Measured results**
>
> | Rollout | Requests | Failed |
> |---|---|---|
> | Before fix | 185 | 2 (1 × 502, 1 dropped) |
> | Rolling out the fix itself | 200 | 2: the pods being replaced did not have the hook yet |
> | After fix (`rollout restart`) | 256 | **0** |
>
> The hook runs on the pod being *shut down*, so it only protects rollouts that replace pods which already have it.

## CI image job failing

| Error | Cause | Fix |
|---|---|---|
| `Unable to resolve action ... unable to find version` | Upstream deleted or renamed the tag | Pin the action to a commit SHA from the action's tags list |
| Trivy step fails with a CVE table | Fixable HIGH/CRITICAL vulnerability in the image | Upgrade the package to the "Fixed Version" Trivy shows; OS packages are patched by `apt-get upgrade` in the Dockerfile |
| `docker push` → `denied` | New GHCR package not linked to the repo | Image needs the `org.opencontainers.image.source` label (set in `ci.yml`) |
| Workflows don't run after the first push | Path filters skip the first push of a new repo | Use *Actions → Run workflow* (`workflow_dispatch`) |

## Site unreachable

1. Is the instance running? `aws ec2 describe-instances --filters Name=tag:Name,Values=taskapi-dev`
2. `kubectl get ingress` and `kubectl -n kube-system get pods`: is Traefik running?
3. Did your home IP change? SSH and kubectl only accept `allowed_cidr`. Update `terraform.tfvars` and re-apply.

## Rollback a bad release

```bash
helm history taskapi
helm rollback taskapi <revision>
```
