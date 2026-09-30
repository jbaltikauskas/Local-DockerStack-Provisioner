# Install-Kubectl.ps1

Bootstraps [Argo CD](https://argo-cd.readthedocs.io/en/stable/getting_started/)
onto a local Kubernetes cluster and deploys example applications from a Git
repository. Unlike the other installers, this one does **not** create a
`docker-compose.yml`; it drives `kubectl` against the cluster in the current
kube-context. It follows the kubectl-only getting-started flow and never
installs the `argocd` CLI — admin login happens in the browser UI.

**What it does:**

1. Ensures `kubectl` is on PATH (installed with `winget` on Windows, or the
   official single-binary release on Linux/macOS).
2. Ensures a cluster is available: probes `kubectl get nodes`, and on Windows
   enables Kubernetes in Docker Desktop when it is off (setting the
   Kubernetes-enabled flag in Docker Desktop's settings file and restarting it).
   If the cluster still cannot be reached, it opens the
   [Docker Desktop Kubernetes guide](https://docs.docker.com/desktop/use-desktop/kubernetes/)
   in the browser before failing.
3. Creates the `argocd` namespace and server-side applies the Argo CD install
   manifest (`ARGO_MANIFEST_URL`), then waits for `argocd-server` to be ready.
4. Starts a background `kubectl port-forward` to the Argo CD server
   (`https://localhost:8080` -> `service/argocd-server:443`).
5. Retrieves the initial `admin` password and writes it to a protected file.
6. Creates the `WORKLOAD_NAMESPACES` (`dev`, `qa`). Kubernetes namespaces must be
   lowercase RFC 1123 labels, so the requested `Dev`/`QA` are created as
   `dev`/`qa`.
7. Clones `GIT_REPO_URL` to disk and applies one Argo CD Application per entry in
   `APPLICATIONS` (`kustom-webapp`, `helm-webapp`) with an automated sync policy,
   then waits until each is Synced and Healthy.
8. Writes a cross-platform browser shortcut to the Argo CD UI.

**Requirements:** PowerShell 7.2+, `git` on PATH, and a Kubernetes cluster.
Docker Desktop's Kubernetes is enabled automatically on Windows; otherwise start
a cluster yourself (kind / minikube / k3d). Stopping/restarting the Docker
Desktop service may require an elevated (Administrator) PowerShell. The
background port-forward stays alive only while the PowerShell window is open.

**Generated files:**

Each installation folder (for example, `<ServerNamePrefix>-ArgoCD-yyyyMMdd`)
generates:

- `argocd-admin-password.env`: the initial `admin` credentials, locked to the
  current user on Windows (treat that file as secret).
- `argocd-application-<name>.yaml`: one Argo CD Application manifest per
  configured application.
- `ArgoCD.url` (Windows), `ArgoCD.webloc` (macOS), or `ArgoCD.desktop` (Linux):
  a browser shortcut to the Argo CD UI (`https://localhost:8080`).
- `repos\<repository>`: the cloned `GIT_REPO_URL` working copy.

**Configuration (`config-kubectl.json`):**

- `INSTALL_ROOT_FOLDER` — where the dated install folder is created.
- `ARGO_NAMESPACE`, `PORT_FORWARD_PORT`, `WEB_HOST`.
- `ARGO_MANIFEST_URL` — the Argo CD install manifest to apply.
- `GIT_REPO_URL` — the source repository for the applications.
- `APPLICATIONS` — a list of `{ NAME, PATH, PROJECT, DEST_NAMESPACE }`; add an
  entry to deploy another app.
- `WORKLOAD_NAMESPACES` — namespaces created before the applications deploy.

```json
"APPLICATIONS": [
    { "NAME": "kustom-webapp", "PATH": "kustom-webapp", "PROJECT": "default", "DEST_NAMESPACE": "dev" },
    { "NAME": "helm-webapp",   "PATH": "helm-webapp",   "PROJECT": "default", "DEST_NAMESPACE": "dev" }
]
```

**Access:**

- Web UI: `https://localhost:8080` (self-signed certificate — accept the browser
  warning). The port-forward runs while the installer window stays open; restart
  it later with
  `kubectl port-forward service/argocd-server -n argocd 8080:443`.
- Login: user `admin`, password from `argocd-admin-password.env`.
