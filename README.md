

# Docker For ROS1

自用的docker ROS1镜像，配置了一些常用的工具和命令，支持Remote-SSH

## How to build

```
docker build -t cros:latest
```

## 修改主机终端字体

`unzip FiraCode.zip -d ~/.fonts && fc-cache -fv`
使用该命令在主机安装该字体，然后在终端选择该字体，zsh对应的主题就会正确显示


## 创建自定义网络固定IP
`sudo docker network create --subnet=192.168.50.0/24 ros_network`

添加 --net 和 --ip参数

> 添加 --privileged参数,释放内核安全限制,可以访问硬件等

`docker run -itd --privileged -e DISPLAY=${HOSTNAME}:0 -v /tmp/.X11-unix:/tmp/.X11-unix -v /home/jay/01-RosSpace:/home/ros/01-RosSpace -v /dev:/dev --net ros_network --ip 192.168.50.50 --name ros-noetic cros`

## 创建一个自定义的启动命令

```
nano /Users/jay/.docker/setup/ros-noetic

# 写入下述内容
xhost +local:docker
echo "请输入指令控制ros-noetic容器: 启动(s) 重启(r) 进入(e)  关闭(c):"
read choose
case $choose in
s) docker start ros-noetic;;
r) docker restart ros-noetic;;
e) docker exec -it ros-noetic /bin/zsh;;
c) docker stop ros-noetic;;
esac
```


## 图形化方式1 xhost

### MAC + Orbstack

> Mac一般使用IP进行通信，所以需要设置IP

主机执行 `echo "xhost +local:docker" >> ~/.bashrc`,该命令用来设置主机允许本地的docker用户访问 X server

主机执行 `echo $DISPLAY` 查看索引号，如`/private/tmp/com.apple.launchd.oko2LIKMW3/org.xquartz:0`,另外确认 `hostnames`,打印主机名称,如`JaydeMacBook-Pro-2.local`

> 其实前缀为主机的任意一个IP都可以，只要满足从机可以ping通主机

从机中确认`echo $DISPLAY` 其中应该为`JaydeMacBook-Pro-2.local:0`

`xeyes` 使用该命令进行测试

### Ubuntu

> Ubuntu默认使用Unix Domain Socket进行通信,所以我们已经映射了对应的文件,不需要设置IP即可

主机执行 `echo "xhost +local:docker" >> ~/.bashrc`,该命令用来设置主机允许本地的docker用户访问 X server

主机执行 `echo $DISPLAY` 查看索引号，如`:1`,

从机中确认`echo $DISPLAY` 其中应该为`:1`

`xeyes` 使用该命令进行测试


## 图形化方式2 ssh开启转发

由于我们给容器添加了ssh以及自定义的ip，所以可以通过ssh进行访问

`ssh -X ros@192.168.50.50`，执行过命令之后进入容器,使用`xeyes`进行测试

如果你有sshpass的话，可以使用 `sshpass -p '1234' ssh -X ros@192.168.50.50 -p 10022` 进行自定义命令访问


## 解决文件映射后的权限问题
使用ros用户开发即可.

Dockerfile中已经添加了UID和GID的参数，在build的时候，添加指定参数即可。

## 使用vscode进行remote 开发

> 并配置进行x11转发,方便图形化界面的显示

```
Host MyRos
  HostName 192.168.50.50
  User ros
  Port 10022
  ForwardX11 yes
  ForwardX11Trusted yes
```

## 设置容器开机自启动

`docker update --restart=always ros-noetic`
