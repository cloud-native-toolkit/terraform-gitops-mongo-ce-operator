#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname "$0"); pwd -P)
MODULE_DIR=$(cd "${SCRIPT_DIR}/.."; pwd -P)
CHART_DIR=$(cd "${MODULE_DIR}/chart/mongo-ce-operator"; pwd -P)
NAME="$1"
DEST_DIR="$2"
mkdir -p "${DEST_DIR}"
VALUES_FILE="values.yaml"
## Add logic here to put the yaml resource content in DEST_DIR 
cp -R "${CHART_DIR}"/* "${DEST_DIR}"
if [[ -n "${VALUES_FILE}" ]] && [[ -n "${VALUES_CONTENT}" ]]; then
#if  [[ -n "${VALUES_CONTENT}" ]]; then
  echo "${VALUES_CONTENT}" > "${DEST_DIR}/${VALUES_FILE}"
fi
find "${DEST_DIR}" -name "*"
