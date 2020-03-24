#!/bin/bash


export ENV_NAME=ingress-demo
export ENV_DIR="./envs/ingress"

export DOMAIN=example.com

export ROCKETCHAT_HOSTNAME=chat.${DOMAIN}
export ROCKETCHAT_SMTP_ENABLED=false
export ROCKETCHAT_SMTP_USERNAME=
export ROCKETCHAT_SMTP_PASSWORD=
export ROCKETCHAT_SMTP_HOST=
export ROCKETCHAT_SMTP_PORT=
export ROCKETCHAT_MONGO_ROOT_PASSWORD=root-password
export ROCKETCHAT_MONGO_USERNAME=rocketchat
export ROCKETCHAT_MONGO_PASSWORD=rocket-password
export ROCKETCHAT_MONGO_KEY=key1234556