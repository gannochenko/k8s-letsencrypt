#!/usr/bin/env bash

TAG="awesome1888/k8s-letsencrypt:latest"

docker build --no-cache -t ${TAG} ..;
docker push ${TAG}
