

# Docker For ROS1

自用的docker ROS1镜像，配置了一些常用的工具和命令，支持Remote-SSH

## How to build

```
docker build -t cros:latest
```

## 修改主机终端字体

`unzip FiraCode.zip -d ~/.fonts && fc-cache -fv`
使用该命令在主机安装该字体，然后在终端选择该字体，zsh对应的主题就会正确显示

## 图形化
主机执行 `echo "xhost +local:docker" >> ~/.bashrc`

从机中确认`echo $DISPLAY` 其中应该为`127.0.0.1`

`xeyes` 使用该命令进行测试

## 创建自定义网络固定IP
`sudo docker network create --subnet=192.168.50.0/24 ros_network`

添加 --net 和 --ip参数
`docker run -itd -e DISPLAY=${HOSTNAME}:0 -v /tmp/.X11-unix:/tmp/.X11-unix -v /home/jay/01-RosSpace:/home/ros/01-RosSpace -v /dev:/dev --net ros_network --ip 192.168.50.50 --name ros-noetic cros`

## 解决文件映射后的权限问题
使用ros用户开发即可.

Dockerfile中已经添加了 UID和GID的参数，在build的时候，添加指定参数即可。

## 使用vscode进行remote 开发
```
Host MyRos
  HostName 192.168.50.50
  User ros
  Port 10022
```

## 设置容器开机自启动

`docker update --restart=always ros-noetic`
