#!/usr/bin/env bash

TAG="awesome1888/k8s-letsencrypt:latest"

#docker run -d -p ${PORT}:${PORT} ${TAG};
docker run -it ${TAG} /bin/sh;
