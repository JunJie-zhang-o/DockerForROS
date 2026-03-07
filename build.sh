#!/bin/bash
# 检查参数是否正确
if [ $# -ne 1 ]; then
  echo "Usage: $0 {focal|jammy|ubuntu2004|ubuntu2204|humble|foxy}"
  exit 1
fi
# 根据传入的参数设置 Dockerfile 和目标镜像名称
case $1 in
  focal|ubuntu2004)
    DOCKERFILE="Dockerfile.NoeticOnFocal"
    IMAGE_NAME="cros20"
    ;;
  jammy|ubuntu2204)
    DOCKERFILE="Dockerfile.NoeticOnJammy"
    IMAGE_NAME="cros22"
    ;;
  humble)
    DOCKERFILE="Dockerfile.HumbleOnJammy"
    IMAGE_NAME="cros22-humble"
    ;;
  foxy)
    DOCKERFILE="Dockerfile.FoxyOnFocal"
    IMAGE_NAME="cros20-foxy"
    ;;
  *)
    echo "Invalid argument: $1"
    echo "Usage: $0 {focal|jammy|ubuntu2004|ubuntu2204|humble|foxy}"
    exit 1
    ;;
esac
# 执行 docker build 命令
docker build --platform=linux/amd64 \
             --build-arg UID="$(id -u)" \
             --build-arg GID="$(id -g)" \
             -t $IMAGE_NAME \
             -f $DOCKERFILE .


# How to test containers:
# docker run -it --rm cros20
# docker run -it --rm cros22