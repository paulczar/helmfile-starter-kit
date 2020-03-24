#!/bin/bash

set -eox pipefail

install_prereqs() {

  docker_exec sh -c '
    apt-get update && apt-get install -yq curl git

    if ! which helm; then
      curl -sSL https://get.helm.sh/helm-v3.1.1-linux-amd64.tar.gz | tar xzf -
      cp linux-amd64/helm /bin/helm
      chmod +x /bin/helm
    fi

    if ! helm plugin  list | grep "^diff\s"; then
      helm plugin install https://github.com/databus23/helm-diff
    fi

    if ! which helmfile; then
      curl -sSL https://github.com/roboll/helmfile/releases/download/v0.102.0/helmfile_linux_amd64 > /bin/helmfile
      chmod +x /bin/helmfile
    fi

    if [[ "${INPUT_COMMAND}" == "apply" ]]; then
      if ! which yq; then
        curl -sSL https://github.com/mikefarah/yq/releases/download/3.2.1/yq_linux_amd64 > /bin/yq
        chmod +x /bin/yq
      fi
      if ! which kubectl; then
        curl -sSL https://storage.googleapis.com/kubernetes-release/release/v1.17.0/bin/linux/amd64/kubectl > /bin/kubectl
        chmod +x /bin/kubectl
      fi
    fi
  '
}

build_container() {
  echo 'Building action container...'
  if ! docker inspect --type image action > /dev/null; then
    docker build -t action .
  fi
}

run_container() {
    echo 'Running action container...'
    # source ./envs/default/envs.sh
    # env > ./envs/default/docker-envs.list
    if docker inspect --type container runner > /dev/null; then
      docker rm -f runner
      sleep 5
    fi

    local args=(run --rm --interactive --detach --network host --name runner "--volume=$(pwd):/workdir" "--workdir=/workdir")
    args+=("-e" "KUBECONFIG=${KUBECONFIG}")
    # args+=("--env-file" "./envs/default/docker-envs.list")
    args+=("action" "cat")
    docker "${args[@]}"

    echo
}

docker_exec() {
    docker exec --workdir=/workdir --interactive runner "$@"
}

if [[ -n ${GITHUB_WORKSPACE} ]]; then
  cd "${GITHUB_WORKSPACE}"
fi

build_container
run_container

if [[ "${INPUT_COMMAND}" == "apply" ]]; then
  docker_exec sh -c '
    . ./envs/default/envs.sh
    ./scripts/check-namespaces.sh -c -d
    helmfile apply
  '
elif [[ "${INPUT_COMMAND}" == "diff" ]]; then
  docker_exec sh -c '
    . ./envs/default/envs.sh
    ./scripts/check-namespaces.sh -c -d
    helmfile diff
  '
else
  docker_exec sh -c '
    . ./envs/default/envs.sh
    helmfile lint
  '
fi
