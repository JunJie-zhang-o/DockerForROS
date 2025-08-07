#!/bin/bash
###
 # @Author       : Jay jay.zhangjunjie@outlook.com
 # @Date         : 2025-07-08 23:32:06
 # @LastEditTime : 2025-07-10 00:17:24
 # @LastEditors  : Jay jay.zhangjunjie@outlook.com
 # @Description  : 
### 

# cros 为镜像名称
docker build --platform=linux/amd64 --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t cros:latest . 

# 后续如何创建实例
# my_cros为实例名称 cros为镜像名称
# docker run -it -e DISPLAY=${HOSTNAME}:0 -v /tmp/.X11-unix:/tmp/.X11-unix  --name my_cros cros zsh

# 如何运行
# docker exec -it my_cros
