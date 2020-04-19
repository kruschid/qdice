#!/bin/bash
export $(cat .env | xargs)
export $(cat .local_env | xargs)

docker run -it --rm --network qdice --env-file .env bgrosse/qdice:backend \
  node toast.js $1
