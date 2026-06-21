

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


## 图形化方式3 远程高性能 3D

远程机器上跑 RViz、Gazebo 这类 OpenGL 3D 程序时，推荐使用 VirtualGL + TurboVNC。远程 GPU 负责渲染，TurboVNC 只传输压缩后的画面，比 `ssh -X` 更适合 3D GUI。

镜像内已安装 VirtualGL、TurboVNC、noVNC、Openbox 和 xterm，并提供 `start-vnc` 命令。启动容器后，先 SSH 进入远程容器：

```bash
ssh ros@REMOTE_HOST -p 10022
```

容器内启动 VNC 桌面：

```bash
start-vnc
```

默认配置：

```text
VNC display: :10
VNC port: 5910
noVNC port: 6080
Geometry: 1920x1080
Password: 1234
TurboVNC listen: 127.0.0.1 only
noVNC listen: 0.0.0.0
VirtualGL display: egl
```

如果使用 VNC Viewer，从本机建立 SSH 隧道：

```bash
ssh -L 5910:127.0.0.1:5910 ros@REMOTE_HOST -p 10022
```

然后用 VNC Viewer 连接：

```text
localhost:5910
```

如果使用浏览器 noVNC，可以直接打开：

```text
http://REMOTE_HOST:6080/vnc.html
```

如果远程防火墙没有开放 6080，也可以从本机建立 SSH 隧道：

```bash
ssh -L 6080:127.0.0.1:6080 ros@REMOTE_HOST -p 10022
```

然后浏览器打开：

```text
http://localhost:6080/vnc.html
```

在 VNC 桌面的终端里运行 3D 程序：

```bash
echo $DISPLAY
export DISPLAY=:10
vglrun -d egl rviz
vglrun -d egl gazebo
```

`echo $DISPLAY` 应该显示当前 VNC display，例如 `:10`。如果显示宿主机的 `:0`、`:1` 或 `jay-ZBOX:1`，RViz 窗口会弹到主机显示器上，需要先 `export DISPLAY=:10`。

普通 2D 程序不需要 `vglrun`，例如：

```bash
rqt
xterm
xeyes
```

可选参数：

```bash
VNC_DISPLAY=2 VNC_GEOMETRY=2560x1440 VNC_PASSWORD=1234 start-vnc
```

如果使用 `VNC_DISPLAY=2`，VNC Viewer 隧道和端口对应改为 `5902`。noVNC 端口默认仍是 `6080`，也可以用 `NOVNC_PORT=6082 start-vnc` 修改。

如果出现 `jay-ZBOX:1 is taken because of /tmp/.X11-unix/X1`，说明 `:1` 已被宿主机 X11 socket 或已有 VNC 会话占用。默认 `start-vnc` 会从 `:10` 开始自动找空闲 display；如果你手动设置了 `VNC_DISPLAY=1`，改成 `VNC_DISPLAY=10 start-vnc` 或先关闭旧会话：

```bash
/opt/TurboVNC/bin/vncserver -kill :1
```

如果不想让 noVNC 监听所有 IP，可以改回本地监听：

```bash
NOVNC_HOST=127.0.0.1 start-vnc
```

如果 `vglrun` 报错不能打开 `display :0`，说明容器访问不到宿主机的物理 Xorg。远程容器默认使用 EGL 后端，重新启动 VNC：

```bash
VGL_DISPLAY=egl start-vnc
```

只有确认容器能访问宿主机物理 X server 时，才使用：

```bash
VGL_DISPLAY=:0 start-vnc
```


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
