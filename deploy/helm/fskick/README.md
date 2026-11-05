# fskick Helm chart

Runs the same three pieces as `docker-compose.prod.yml` on Kubernetes:

| Compose | Kubernetes |
|---|---|
| `postgres` + `postgres_data` volume | `StatefulSet` `fskick-postgres` + PVC `fskick-postgres-data` + Service `fskick-postgres` |
| `init-eventstore-db.sh` mount | ConfigMap `fskick-postgres-init` (runs only on an empty data dir) |
| `migrate` (run once before `app`) | `migrate` initContainer in every app pod |
| `app` | Deployment `fskick` (2 replicas, rolling update) + Service + Ingress |
| `.env` | Secret `fskick-secrets`, created by hand (never part of the chart) |

## Migrations and zero-downtime rollouts

`/app/bin/migrate` (`Fskick.Release.migrate/0`) applies pending schema
migrations for the read model, the event store and the key repo, and creates
the event store on a fresh database. It runs before every new app pod starts
and does nothing when nothing is pending.

A rollout starts one new pod (`maxSurge: 1`), runs migrations, waits until
`/health/ready` passes, and only then stops an old pod (`maxUnavailable: 0`).
That means **old pods keep running against the migrated schema**, so
migrations must be backward-compatible with the previous release: add columns
and tables first, remove them in a later release (expand/contract).

Postgres itself is a single instance; restarting it is a short outage.

## First setup on a local cluster (k3d)

All commands run from the repository root.

1. **Create a data volume.** Postgres stores its data in a Docker volume that
   is mounted into the cluster node, so the data survives deleting and
   recreating the cluster. A new volume is empty, so Postgres initialises a
   fresh database on first start.

   ```bash
   docker volume create fskick-k8s-pgdata
   ```

2. **Create the cluster.**

   ```bash
   k3d cluster create fskick \
     --image rancher/k3s:v1.36.6-k3s1 \
     -p "8080:80@loadbalancer" \
     --volume fskick-k8s-pgdata:/var/lib/fskick/postgres@server:0
   kubectl config use-context k3d-fskick
   kubectl create namespace fskick
   ```

   - `--image` pins a current k3s. Older versions (k3d's default may be
     v1.21) ship a load balancer that fails on nf_tables-only kernels and a
     Traefik that ignores the chart's Ingress.
   - `-p` publishes port 8080 on your machine to the cluster's ingress
     controller (Traefik). Without it, only the Kubernetes API is reachable
     from outside the k3d containers.
   - `--volume` mounts the data volume at the path `values-local.yaml` points
     a hostPath PersistentVolume at.

   Wait until Traefik is up and has registered its IngressClass:

   ```bash
   kubectl -n kube-system get pods     # traefik-* and svclb-traefik-* Running
   kubectl get ingressclass            # lists "traefik"
   ```

3. **Create `.env` with the secrets.** Start from `.env.example` and replace
   every placeholder. Values must be unquoted: `--from-env-file` keeps quotes
   as part of the value.

   ```bash
   cp .env.example .env
   ```

   | Key | Value |
   |---|---|
   | `POSTGRES_USER` | database user, e.g. `fskick` |
   | `POSTGRES_PASSWORD` | `openssl rand -base64 24` |
   | `POSTGRES_DB` | read-model database, e.g. `fskick_prod` |
   | `EVENT_STORE_DB` | event-store database, e.g. `fskick_eventstore_prod` |
   | `SECRET_KEY_BASE` | `mix phx.gen.secret` (signs session cookies) |
   | `RELEASE_COOKIE` | `openssl rand -base64 32` (lets the app pods form an Erlang cluster) |

   `PHX_HOST` and `APP_VERSION` are only used by docker compose; the chart sets
   them from `host` in the values and from the image tag.

   Postgres takes the user, password and database names from the Secret only
   when it initialises an empty data directory. Changing them in `.env`
   later does not change the existing database.

4. **Create the Secret** from `.env`:

   ```bash
   kubectl -n fskick create secret generic fskick-secrets --from-env-file=.env
   ```

5. **Build the image, load it into the cluster, and install the chart.** The
   default image tag is `appVersion` from `Chart.yaml`.

   ```bash
   TAG=$(grep '^appVersion:' deploy/helm/fskick/Chart.yaml | cut -d'"' -f2)
   docker build -t fskick:$TAG .
   k3d image import fskick:$TAG -c fskick
   helm upgrade --install fskick deploy/helm/fskick -n fskick \
     -f deploy/helm/fskick/values-local.yaml
   ```

   k3d nodes cannot see your local Docker images, which is why every image is
   imported. `values-local.yaml` sets `pullPolicy: Never`, so a missing import
   shows up as `ErrImageNeverPull`.

   ```bash
   kubectl -n fskick get pods -w        # postgres + 2 app pods become Ready
   ```

   On the first start, Postgres initialises the database and the `migrate`
   initContainer creates the event store and all tables.

6. **Create the first account and season.** Mix tasks don't exist in a
   release, so call the context functions through `bin/fskick rpc`, which
   runs code in a live app pod:

   ```bash
   kubectl -n fskick exec deploy/fskick -c app -- bin/fskick rpc \
     'IO.inspect(Fskick.Users.register_user_with_new_player("Alice", "alice@example.com", "a-long-password"))'

   kubectl -n fskick exec deploy/fskick -c app -- bin/fskick rpc \
     'IO.inspect(Fskick.Seasons.create_season("2026"))'
   kubectl -n fskick exec deploy/fskick -c app -- bin/fskick rpc \
     'IO.inspect(Fskick.Seasons.activate_season("2026"))'
   ```

   The password ends up in your shell history; clear it or change the password
   afterwards.

   Open http://localhost:8080 and log in.

## Versions

- `appVersion` in `Chart.yaml` is the app release, the git tag without the
  `v` (`v3.1.0` → `"3.1.0"`). It is the default image tag and shows in
  `helm list` / `helm history`.
- `version` is the chart's own version. Bump it when templates or values
  change, independent of app releases.

## Deploying a change

Each deploy needs a new image tag, because the rollout only starts when the
pod spec changes.

- **Release:** set `appVersion: "3.2.0"` in a release commit, tag it
  (`git tag v3.2.0`), then repeat step 5.
- **In-between build:** keep `appVersion` and override the tag:

  ```bash
  TAG=$(git rev-parse --short HEAD)   # add -$(date +%s) for uncommitted changes
  docker build -t fskick:$TAG .
  k3d image import fskick:$TAG -c fskick
  helm upgrade --install fskick deploy/helm/fskick -n fskick \
    -f deploy/helm/fskick/values-local.yaml --set image.tag=$TAG
  ```

- **Chart change only** (templates or values): run the same `helm upgrade`
  with the tag that is currently deployed. Changes to the pod template trigger
  a rolling update, others are applied in place.

Following and undoing a deploy:

```bash
kubectl -n fskick rollout status deploy/fskick   # follow the rollout
helm -n fskick history fskick                    # releases
helm -n fskick rollback fskick                   # back to the previous one
```

A rollback does not undo migrations.

## Changing secrets

Update the Secret from the edited `.env`, then restart the app pods, which
only read the Secret at start-up. The restart is a rolling update, so there is
no downtime.

```bash
kubectl -n fskick create secret generic fskick-secrets --from-env-file=.env \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n fskick rollout restart deploy/fskick
```

Changing `POSTGRES_PASSWORD` this way breaks the app's database connection:
the database still has the old password. Change it in Postgres first
(`ALTER USER ... PASSWORD ...` via
`kubectl -n fskick exec -it fskick-postgres-0 -- psql -U <user> -d <POSTGRES_DB>`),
then update the Secret. A new `SECRET_KEY_BASE` logs everyone out.

## Checks

- Pods: `kubectl -n fskick get pods`. Migration output:
  `kubectl -n fskick logs <pod> -c migrate`.
- Clustering: `kubectl -n fskick exec deploy/fskick -c app -- bin/fskick rpc "IO.inspect(Node.list())"`
  should list the other app pod.
- No downtime: in one terminal run
  `while true; do curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/; sleep 0.2; done`
  and deploy a new tag in another. Every response should be `200`.
- Persistence: `kubectl -n fskick delete pod fskick-postgres-0`. The data is
  still there when the pod comes back.
- Without the ingress: `kubectl -n fskick port-forward svc/fskick 8080:80`
  sends requests straight to the app, bypassing Traefik.

## Stopping, removing, starting over

- **Pause:** `k3d cluster stop fskick` / `k3d cluster start fskick`.
- **Remove the release:** `helm -n fskick uninstall fskick`. The PVC and PV
  stay (`helm.sh/resource-policy: keep`), so a later install finds the data.
- **Remove the cluster:** `k3d cluster delete fskick`. The data stays in the
  `fskick-k8s-pgdata` volume; recreating the cluster with steps 2, 4 and 5
  brings everything back. Imported images are gone with the cluster.
- **Start from scratch:** delete the cluster, then
  `docker volume rm fskick-k8s-pgdata`. This permanently deletes all data,
  including the event store.
