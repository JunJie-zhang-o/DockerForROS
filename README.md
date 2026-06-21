

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

如果是Mac，建议使用该命令

```
docker run -itd --privileged -e DISPLAY=${HOSTNAME}:0 -v /tmp/.X11-unix:/tmp/.X11-unix -v /home/jay/01-RosSpace:/home/ros/01-RosSpace -v /dev:/dev --net ros_network --ip 192.168.50.50 --name ros-noetic cros
```

如果是Ubuntu，建议使用该命令

```
docker run -itd --privileged -e DISPLAY=${DISPLAY} -v /tmp/.X11-unix:/tmp/.X11-unix -v /home/jay/01-RosSpace:/home/ros/01-RosSpace -v /dev:/dev --net ros_network --ip 192.168.50.50 --name ros-noetic cros
```

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


## 图形化方式1 本机直连 X11/Wayland

适合容器跑在本机 Linux 上时使用。RViz、rqt、Gazebo、OpenCV `imshow` 直接走宿主机图形 socket，不经过 `ssh -X`，带宽占用最低，性能最好。

### Ubuntu / Linux

宿主机执行：

```bash
xhost +local:docker
export DISPLAY=${DISPLAY:-:0}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-0}
```

然后启动或重启容器：

```bash
docker compose up -d ros-noetic-focal
# 或使用仓库脚本
noetic restart
```

容器内验证：

```bash
echo $DISPLAY
echo $XDG_RUNTIME_DIR
echo $WAYLAND_DISPLAY
xeyes
```

如果 `xeyes` 能弹窗，X11 已经走本机 Unix socket。Wayland 程序会通过挂载的 `$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY` 连接宿主机 Wayland socket；RViz/Gazebo 这类程序仍可继续走 X11。

如果想每次登录自动允许本机 Docker 访问 X server：

```bash
echo "xhost +local:docker >/dev/null 2>&1" >> ~/.zshrc
```

> 使用 Powerlevel10k instant prompt 时，`xhost +local:docker` 的正常输出也会触发 zsh 初始化 warning，所以需要重定向输出。

> Ubuntu 默认使用 Unix Domain Socket。`docker-compose.yml` 已经映射 `/tmp/.X11-unix`、`DISPLAY`、`XDG_RUNTIME_DIR` 和 `WAYLAND_DISPLAY`，本机场景不需要通过 SSH 转发图形。

### MAC + Orbstack

> Mac一般使用IP进行通信，所以需要设置IP

主机执行 `echo "xhost +local:docker" >> ~/.bashrc`,该命令用来设置主机允许本地的docker用户访问 X server

主机执行 `echo $DISPLAY` 查看索引号，如`/private/tmp/com.apple.launchd.oko2LIKMW3/org.xquartz:0`,另外确认 `hostnames`,打印主机名称,如`JaydeMacBook-Pro-2.local`

> 其实前缀为主机的任意一个IP都可以，只要满足从机可以ping通主机

从机中确认`echo $DISPLAY` 其中应该为`JaydeMacBook-Pro-2.local:0`

`xeyes` 使用该命令进行测试


## 图形化方式2 ssh开启转发

由于我们给容器添加了 SSH，所以可以通过 SSH 进入容器开发。

本机 Linux 推荐直接 SSH 进入，不使用 `-X`：

```bash
ssh ros@127.0.0.1 -p 10022
```

容器启动时会把 Docker Compose 注入的 `DISPLAY`、`XDG_RUNTIME_DIR`、`WAYLAND_DISPLAY` 写入 `/etc/environment`，所以 SSH 登录后可以直接使用本机挂载的 X11/Wayland socket：

```bash
echo $DISPLAY
xeyes
```

如果连接远程机器上的容器，才使用 `ssh -X` 走 SSH 图形转发：

```bash
ssh -X ros@192.168.50.50 -p 10022
```

如果你有 `sshpass`，可以使用 `sshpass -p '1234' ssh ros@127.0.0.1 -p 10022` 进行自定义命令访问。


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

## 一键管理 ROS 容器

仓库已提供脚本：

- `startup/foxy`：管理 `ros-foxy-focal`
- `startup/humble`：管理 `ros-humble-jammy`
- `startup/noetic`：管理 `ros-noetic-focal` / `ros-noetic-jammy`

先在本机配置命令（任选一种）：

```bash
# 方式1：加入 PATH（推荐）
echo 'export PATH="/home/zhangjunjie/00_zj_humanoid/000-Github/DockerForROS/startup:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

```bash
# 方式2：软链接到全局命令
sudo ln -sf /home/zhangjunjie/00_zj_humanoid/000-Github/DockerForROS/startup/foxy /usr/local/bin/foxy
sudo ln -sf /home/zhangjunjie/00_zj_humanoid/000-Github/DockerForROS/startup/humble /usr/local/bin/humble
sudo ln -sf /home/zhangjunjie/00_zj_humanoid/000-Github/DockerForROS/startup/noetic /usr/local/bin/noetic
```

使用方式：

```bash
foxy
humble
noetic
```

输入选项后可执行：启动(s)、重启(r)、进入(e)、关闭(c)、状态(t)。

也支持直接命令参数：

```bash
foxy start
foxy stop
foxy enter
foxy restart
foxy status

humble start
humble stop
humble enter
humble restart
humble status

noetic start            # 默认 focal
noetic jammy start      # 指定 jammy
noetic focal enter      # 指定 focal
noetic jammy            # 进入 jammy 的交互菜单
```
