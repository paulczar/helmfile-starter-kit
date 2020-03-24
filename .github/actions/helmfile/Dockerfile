FROM "ubuntu:latest"

WORKDIR /tmp

RUN apt-get update && apt-get install -yq curl git tree

RUN \
  curl -sSL https://get.helm.sh/helm-v3.1.1-linux-amd64.tar.gz | tar xzf - \
  && cp linux-amd64/helm /bin/helm && chmod +x /bin/helm \
  && helm plugin install https://github.com/databus23/helm-diff --version v3.1.1

RUN \
  curl -sSL https://github.com/roboll/helmfile/releases/download/v0.102.0/helmfile_linux_amd64 > /bin/helmfile \
  && chmod +x /bin/helmfile

RUN \
  curl -sSL https://github.com/mikefarah/yq/releases/download/3.2.1/yq_linux_amd64 > /bin/yq \
  && chmod +x /bin/yq

RUN \
  curl -sSL https://storage.googleapis.com/kubernetes-release/release/v1.17.0/bin/linux/amd64/kubectl > /bin/kubectl \
  && chmod +x /bin/kubectl

# COPY entrypoint.sh /entrypoint.sh

# WORKDIR /src

# ENTRYPOINT [ "/entrypoint.sh" ]