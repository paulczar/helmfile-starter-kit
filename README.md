# Helmfile Starter Kit

## About

This project is designed to be a starter kit for developing your own [Helmfile](https://github.com/roboll/helmfile) based project for installing complex software onto Kubernetes.

[Helmfile](https://github.com/roboll/helmfile) is a declarative spec for deploying helm charts. It lets you perform gitops style deployment of your helm charts.

This project applies some [in the authors opinion] sensible defaults and workflows around Helmfile itself.

## Prerequisites

The following are required for [Helmfile](https://github.com/roboll/helmfile) and this repo to function correctly.

* [Helmfile](https://github.com/roboll/helmfile/releases)
* [Helm 3](https://helm.sh/docs/intro/install/)
* [Helm Diff](https://github.com/databus23/helm-diff#install)
* [YQ](https://mikefarah.gitbook.io/yq/#install)

## Value precedence in Helmfile

Helmfile is effectively a layering of templates and values files. We take further advantage of this in the way that this starter kit is layed out.

### 1. Base state files

These are values files that are loaded before the helmfile itself is processed. This allows you to put logic in the helmfile itself around the contents of these values.

### 2. Environment values

These values are loaded after the base values that can be used to customize each environment. Usually in Helmfile you specify the environments and their values in the `helmfile.yaml` however we externalize this to a values file in your environment directory/repo, as far as Helmfile is concerned, the environment currently loaded (via `envs.sh` see below for details) is considered the `default` environment. This effectively fully decouples the environments from the code.

### 3. Helm Release Values

Finally Helm release values are literally the values that you would usually pass into Helm itself via `--set` or `--values`. However they can also be templates themselves (if the files have a `.gotmpl`) extension they're considered a template and treated as such.

This allows us to render in values from `base` and `environment` values, as well as `ENVIRONMENT VARIABLES` and other sources.

## Structure

### Code Repo

```console
├── charts.yaml
├── helmfile.yaml
├── values.yaml
├── charts
│   └── rocketchat
│       ├── helmfile
│       │   └── base.yaml.gotmpl
```

**helmfile.yaml**:

This is the main control center of helmfile, it defines your environments, repositories, and charts to be installed.

However almost all of this has been externalized to ensure composability. For the most part you should never need to modify `helmfile.yaml` itself.

**charts.yaml**:

This contains a list of default helm charts to be installed and the values and secrets to be used with those charts.

Since this is considered a **base** state file, we put everything under either a `charts` or `repositories` key.

To install Rocketchat you would put the following in the `charts.yaml`:

```yaml
  rocketchat:
    name: rocketchat
    enabled: true
    repository:
      name: stable
      url: https://kubernetes-charts.storage.googleapis.com
    namespace: rocketchat
    chart: stable/rocketchat
    version: 2.0.2
    values:
      - charts/rocketchat/helmfile/base.yaml.gotmpl
```

**values.yaml**:

This is where we put default values that can be used in our chart value templates. We don't actually use this for values that the charts expect but instead values that we can use in control logic in the templates.

Values in here are namespaced under the `_` key to ensure they don't interfere with actual chart values.

For example if you wanted to produce different chart values based on whether or not to use an an ingress controller you could set:

```yaml
_:
  ingress:
    enabled: false
```

**./charts/rocketchat/helmfile/base.yaml.gotmpl**:

Each chart gets its own set of chart value templates. Whether or not you vendor in your own charts we like to use the above naming scheme (replace `rocketchat` with your chart name.) Putting the value templates in a `helmfile` subdirectory ensures they do not interfere with the expected Helm Chart structure.

These files are listed under `values:` in your `charts.yaml` files if they are to be used. Multiple values files will merge `dicts` and override `lists` with the latter files taking precedence.

To enable ingress for Rocketchat based on `values.yaml` you would have the following logic in `base.yaml.gotmpl`:

```yaml
{{- if .Values._.ingress.enabled }}
ingress:
  enabled: true
  annotations:
...
...
{{- end }}
```

### Environment Repo

```console
├── envs
│   ├── default
│   │   ├── envs.sh
│   │   ├── charts.yaml.gotmpl
│   │   └── values.yaml.gotmpl
│   └── ingress
│       ├── envs.sh
│       ├── charts.yaml.gotmpl
│       └── values.yaml.gotmpl
```

As per gitops workflows its expected to have your environment specific values separate to your code. To enable this use environment variables to determine the environment name and path.

For simplicity sake we have some example enviroment repos
inside the code repo under `envs/`. These can be used as a basis for your own environment repo.

Inside each Environment we provide `charts.yaml.gotmpl` and `values.yaml.gotmpl` to allow you to override defaults from the code repo as well as an `envs.sh` which contains a list of `ENVIRONMENT VARIABLES` that can be used.

> Note: the charts and values files are templates and thus you can control them with logic based on the base values or environment variables.

**envs.sh**:

This is a bash script that sets a bunch of environment variables that is sourced (`. ./envs/default/envs.sh`) before running helmfile.

It sets the environment name and relative path to the Environment Repo so that helmfile can resolve things down.

It also sets environment variables for things that you want to render into your helm charts such as usernames and passwords. We went with environment variables to do this to make it easier to use alternative sources such as Vault.

For instance if your environment repo is in `../production` and your mongodb password is `bananas` you'd have the following in `envs.sh`:

```bash
export ENV_NAME=production
export ENV_DIR=../envs/${production}
export ROCKETCHAT_MONGODB_PASSWORD=bananas
...
```

**charts.yaml.gotmpl**:

This provides overrides for `charts.yaml` If you wanted to disable the rocketchat chart you could put the following in your `charts.yaml.gotmpl`:

```yaml
charts:
  rocketchat:
    enabled: false
```

You could even use an environment variable set in `envs.sh`:

```yaml
charts:
  rocketchat:
    enabled: {{ env "ROCKETCHAT_ENABLED" | default true }}
```

**values.yaml.gotmpl**

Provides overrides for values from `values.yaml` in your code repo. For instance if you wanted to enable ingress just for this environment you'd have `_.ingress.enabled: false` in your `values.yaml` and then you'd set it to enabled in `values.yaml.gotmpl`:

```yaml
_:
  ingress:
    enabled: true
```

or:

```yaml
_:
  ingress:
    enabled: {{ requiredEnv "ROCKETCHAT_INGRESS_ENABLED" }}
```

**$ENV_DIR/rocketchat.yaml.gotmpl**:

You can even override sections or all of a helm's chart templates. For example if you had one unique environment that was completely different to the others you could copy the `base.yaml.gotmpl` from the chart into your env and completely rewrite it.

You'd then add the following to your `charts.yaml.gotmpl`:

```yaml
charts:
  rocketchat:
    values:
      - '{{ env "ENV_DIR" }}/rocketchat.yaml.gotmpl'
```

> since lists get fully overridden, this would set your new file to be the only values to be rendered into the helm chart.

## Creating one off custom resources for Charts

Often Helm charts omit a necessary secret or configmap, especially for things like TLS certificates. To get around this each Chart can have a list of `raw` resources that will be rendered using the `paulczar/raw` Helm Chart.

For instance if you need to add a `ClusterIssuer` resource in order for the `cert-manager` controller to create a key/cert secret you could add the following:

**$ENV_DIR/charts.yaml.gotmpl**:
```yaml
charts:
  certManager:
    raw:
      - '{{ env "ENV_DIR" }}/clusterissuer.yaml.gotmpl
```

**$ENV_DIR/clusterissuer.yaml.gotmpl**:
```yaml
manifests:
  - metadata:
      name: google-credentials
    apiVersion: v1
    kind: Secret
    data:
      credentials.json: "{{ requiredEnv "GOOGLE_CREDENTIALS_JSON" | b64enc }}"
  - metadata:
      name: letsencrypt-prod
    apiVersion: cert-manager.io/v1alpha2
    kind: ClusterIssuer
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: {{ requiredEnv "CERT_MANAGER_EMAIL" }}
        privateKeySecretRef:
          name: letsencrypt-prod
        solvers:
        - dns01:
            clouddns:
              project: {{ requiredEnv "GOOGLE_PROJECT_ID" }}
              serviceAccountSecretRef:
                name: google-credentials
                key: "credentials.json"
```

## Example

To provide a fairly clear example we've included the stable rocketchat chart to show how it all ties together. Assuming
you have the pre-reqs installed and a Kubernetes cluster you should be able to run the following:

```bash
. ./envs/default
. ./scripts/check-namespaces.sh -c -d
helmfile apply
```

> Note: Helm 3 does not create namespaces by default. The above script will use `yq` to combine `charts.yaml` and `charts.yaml.gotmpl` and create namespaces for any charts that are enabled.

To clean up after:

```bash
helmfile destroy
```
