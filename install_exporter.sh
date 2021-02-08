#!/usr/bin/env bash

HAS_DOCKER="$(type "docker" &> /dev/null && echo true || echo false)"
HAS_NVGPU="$(type "nvidia-smi" &> /dev/null && echo true || echo false)"
PROXY_URL="https://aics-api.asus.com/pushproxy/"
VERTIAL_NAME=""
VM_NAME=""

# initArch discovers the architecture for this system.
initArch() {
  ARCH=$(uname -m)
  case $ARCH in
    armv5*) ARCH="armv5";;
    armv6*) ARCH="armv6";;
    armv7*) ARCH="arm";;
    aarch64) ARCH="arm64";;
    x86) ARCH="386";;
    x86_64) ARCH="amd64";;
    i686) ARCH="386";;
    i386) ARCH="386";;
  esac
}

# initOS discovers the operating system for this system.
initOS() {
  OS=$(echo `lsb_release -is`|tr '[:upper:]' '[:lower:]')
  VERSION=$(echo `lsb_release -rs`|tr '[:upper:]' '[:lower:]')

  case "$OS" in
    # Minimalist GNU for Windows
    mingw*) OS='windows';;
  esac
}

# verifySupported checks that the os/arch combination is supported for
# binary builds, as well whether or not necessary tools are present.
verifySupported() {
  local supported="ubuntu-amd64"
  if ! echo "${supported}" | grep -q "${OS}-${ARCH}"; then
    echo "No prebuilt binary for ${OS}-${ARCH}."
    exit 1
  fi

  if [ "${HAS_DOCKER}" != "true" ]; then
    echo "docker is required"
    exit 1
  fi
}

inputFQDN() {
  while [ -z $VERTIAL_NAME ]
  do
    read -p "Input vertical name, ex: aics-safety: " VERTIAL_NAME
  done
  while [ -z $VM_NAME ]
  do
    read -p "Input vm name, ex: model-training-vm: " VM_NAME
  done
  echo "FQDN name = $VERTIAL_NAME.$VM_NAME"
}

installNodeExporter() {
  echo "Install node exporter..."
  sudo docker run -d --restart always --net="host" --pid="host" quay.io/prometheus/node-exporter:latest || exit 1
}

installGpuExporter() {
  echo "Install dcgm exporter..."
  sudo docker run -d --restart always --gpus all -p 9400:9400 nvidia/dcgm-exporter:2.0.13-2.1.2-"$OS$VERSION" || exit 1
}

installPushProxClient() {
  echo "Install pushprox client..."
  sudo docker run -d --net=host --entrypoint='/app/pushprox-client' prom/pushprox:v0.1.0 --fqdn="$VERTIAL_NAME.$VM_NAME" --proxy-url="$PROXY_URL" || exit 1
}

initArch
initOS
verifySupported
inputFQDN
installNodeExporter
if [ "$HAS_NVGPU" == "true"]; then
  installGpuExporter
fi
installPushProxClient
