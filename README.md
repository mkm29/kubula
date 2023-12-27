# Kubula - Flux Bootstrapper for Kubernetes

![Kubula](media/logo-scaled.png)

## What is Kubula?

Kubula is a tool that helps you bootstrap your Kubernetes cluster using [Flux](https://fluxcd.io/). It is a wrapper around Flux that helps you get started with Flux and Kubernetes.

## Components

- Argo CD
- Prometheus

## Prerequisites

- A Kubernetes [cluster](https://mitchmurphy.io/cilium-rke2/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [flux CLI](https://fluxcd.io/flux/installation/)
- [flamingo CLI](https://flux-subsystem-argo.github.io/website/)

## Bootstrap

This repository will serve as the source of truth for your cluster. You can clone this repository, change the remote, make changes to it and commit. The changes will be applied to your cluster.

1. Install flux CLI. Follow these instructions: https://fluxcd.io/docs/installation/
2. Create PAT (Personal Access Token) with `repo` scope from [GitHub](https://github.com/settings/tokens)
3. Bootstrap

```console
export GITHUB_TOKEN=<your-token>
export GITHUB_USER=<your-username>
export GITHUB_REPO=<your-repo>
export CLUSTER_NAME=<your-cluster-name>
flux bootstrap github \
    --owner=$GITHUB_USER \
    --repository=$GITHUB_REPO \
    —-path="clusters/$CLUSTER_NAME" \
    --token-auth \
    --personal \
    --branch=main
```

4. Wait for the bootstrap to complete. You can check the status using `flux get sources git`. It should look like this:

```bash
$ flux get sources git
NAME            REVISION                SUSPENDED       READY   MESSAGE
flux-system     main@sha1:2e619003      False           True    stored artifact for revision 'main@sha1:2e619003'
```

5. Check the pods in `flux-system` namespace. It should look like this:

```bash
$ kubectl get pods -n flux-system
NAME                                       READY   STATUS    RESTARTS   AGE
helm-controller-5f9f9f6f8f-4q9qz           1/1     Running   0          2m
kustomize-controller-7f9f9f6f8f-2q9qz      1/1     Running   0          2m
notification-controller-7f9f9f6f8f-2q9qz   1/1     Running   0          2m
source-controller-7f9f9f6f8f-2q9qz         1/1     Running   0          2m
```

6. Install Flamingo

```bash
flamingo install
```

### Install Cilium

We can use Flamingo to install Cilium. The Cilium Helm chart is defined in `clusters/$CLUSTER_NAME/cilium/01-cilium-helmrelease.yaml`. You can change the values in `clusters/$CLUSTER_NAME/cilium/01-cilium-helmrelease.yaml` to customize the installation. Once you are done, commit the changes and push them to the repository. Flux will apply the changes to your cluster.

```bash
$ git add .
$ git commit -m "Install Cilium"
$ git push origin main
```

_Note_ - We have set `serviceMonitor.enabled` to `false` as the Prometheus CRDs need to be installed before we can enable this, and since we are replaing `kube-proxy` with `cilium`, we need to install Cilium first. After installing Prometheus, you can set this to `true` and commit the changes.

### Install Argo CD

We can now use Flux to install Argo CD. We will use a HelmRelease to install Argo CD. The HelmRelease is defined in `clusters/$CLUSTER_NAME/argo-cd/argocd-helmrelease.yaml`. You can change the values in `clusters/$CLUSTER_NAME/argo-cd/02-argo-cd-helmrelease.yaml` to customize the installation. Once you are done, commit the changes and push them to the repository. Flux will apply the changes to your cluster.

```bash
$ git add .
$ git commit -m "Install Argo CD"
$ git push origin main
```

You can check the status of the HelmRelease using `flux get helmrelease --all-namespaces`. It should look like this:

```bash
$ flux get helmrelease --all-namespaces
NAMESPACE       NAME    REVISION        SUSPENDED       READY   MESSAGE
argocd          argocd  5.51.0          False           True    Helm install succeeded for release argocd/argocd-argocd.v1 with chart argo-cd@5.51.0
```

### Install Prometheus

Similar to Argo CD, we can use a `HelmRelease` to install the Prometheus Kube Stack. The `HelmRelease` is defined in `clusters/$CLUSTER_NAME/prometheus/03-prom-helmrelease.yaml`. You can change the values in `clusters/$CLUSTER_NAME/prometheus/03-prome-helmrelease.yaml` to customize the installation. Once you are done, commit the changes and push them to the repository. Flux will apply the changes to your cluster.

```bash
$ git add .
$ git commit -m "Install Prometheus"
$ git push origin main
```

## References

- https://fluxcd.io/docs/get-started/
- https://argoproj.github.io/cd/
- https://docs.rke2.io/helm

## Contributing

1. Fork it!
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Submit a pull request :D

## Credits

Lead Developer - [Mitchell Murphy](mitch.murphy@gmail.com)

## License

The MIT License (MIT)

Copyright (c) 2023 Mitchell Murphy

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
