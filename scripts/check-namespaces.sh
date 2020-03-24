#!/bin/bash

if ! yq --version 2>/dev/null >/dev/null; then
  echo "Please install yq and try again"
  echo "https://mikefarah.gitbook.io/yq/#install"
  exit 1
fi

while getopts "hcdx" arg; do
  case $arg in
    h)
      echo "usage check-namespaces.sh [options]"
      echo "-h help"
      echo "-c create missing namespaces"
      exit 0
      ;;
    c)
      CREATE_NS=true
      ;;
    d)
      DEBUG=true
      ;;
    x)
      DELETE_NS=true
      ;;
  esac
done

# [[ -n $DEBUG ]] && set -x

if [[ -n ${CREATE_NS} && -n ${DELETE_NS} ]]; then
  echo "-c and -x are exclusive"
  exit 1
fi

MERGE="m ${ENV_DIR}/charts.yaml.gotmpl charts.yaml"

[[ -n $DEBUG ]] && echo "==> Calculating list of releases"
RELEASES=$(yq ${MERGE} | yq r - --printMode p "charts.*" | sed 's/^charts\.//')

[[ -n $DEBUG ]] && echo "----> releases: `echo $RELEASES | xargs`"
for release in $RELEASES; do
  [[ -n $DEBUG ]] && echo "==> Checking release $release"
  ENABLED=$(yq ${MERGE} | yq r - "charts.${release}.enabled")
  if [[ "${ENABLED}" =~ ^(true|yes|1|TRUE|YES)$ ]]; then
    [[ -n $DEBUG ]] && echo "----> release $release is enabled"
    NS=$(yq ${MERGE} | yq r - "charts.${release}.namespace")
    if ! kubectl get namespace ${NS} 2>/dev/null >/dev/null; then
      [[ -n $DEBUG ]] && echo "----> namespace $NS is missing"
      if [[ ${CREATE_NS} == "true" ]]; then
        [[ -n $DEBUG ]] && echo "----> creating namespace $NS"
        kubectl create namespace ${NS}
        sleep 5
        continue
      fi
    elif [[ ${DELETE_NS} == "true" ]]; then
      [[ -n $DEBUG ]] && echo "----> deleting namespace $NS"
      kubectl delete namespace ${NS}
      sleep 5
      continue
    fi
  else
    [[ -n $DEBUG ]] && echo "----> release $release is disabled"
    continue
  fi
          [[ -n $DEBUG ]] && echo "----> namespace $NS exists"

done