# 使用 Ubuntu 22.04 作为基础镜像
FROM ubuntu:22.04

# 设置环境变量
ENV LANG=en_US.UTF-8 \
    LANGUAGE=zh_CN:zh \
    LC_ALL=zh_CN.UTF-8 \
    DEBIAN_FRONTEND=noninteractive

RUN apt update && apt upgrade -y && apt install locales && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8

# 安装基础工具
RUN apt update && apt upgrade -y && \
    apt install -y \
    bash-completion \
    openssh-server \
    net-tools \
    nano \
    zsh \
    git \
    curl \
    x11-apps \
    iputils-ping \
    sshpass \
    fakeroot \
    python3-bloom \
    debhelper \
    unzip \
    zip \
    tree \
    python3-pip \
    software-properties-common \
    sudo \
    libpoco-dev \
    liburdfdom-headers-dev \
    libyaml-cpp-dev \
    liburdfdom-dev \
    python3-netifaces 
    

# RUN apt-get install --no-install-recommends -y hddtemp


# 安装 pytest 相关工具
RUN pip3 install pytest pytest-dependency pytest-env &&  ln -s /lib/x86_64-linux-gnu/librt.so.1 /lib/x86_64-linux-gnu/librt.so

# # 安装 locales 包
RUN apt-get update && apt-get install -y locales && \
    sed -i '/zh_CN.UTF-8/s/^# //g' /etc/locale.gen && \
    sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen

# 安装 ROS Noetic
# RUN apt update && \
#     apt install -y curl gnupg lsb-release && \
#     # 添加 ROS 1 Noetic GPG 密钥
#     curl -sSL "http://packages.ros.org/ros/ubuntu/ros1.gpg" | tee /etc/apt/trusted.gpg.d/ros.asc > /dev/null && \
#     # 添加 ROS 1 Noetic 的 APT 仓库
#     echo "deb [arch=amd64] http://packages.ros.org/ros/ubuntu $(lsb_release -c | awk '{print $2}') main" | tee /etc/apt/sources.list.d/ros-noetic.list && \
#     apt update && \
#     # 安装 ROS Noetic 完整桌面版本
#     apt install -y ros-noetic-desktop-full



# pinocchio 3.4
RUN apt install -qqy lsb-release curl && curl http://robotpkg.openrobots.org/packages/debian/robotpkg.asc \
   | tee /etc/apt/keyrings/robotpkg.asc && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/robotpkg.asc] http://robotpkg.openrobots.org/packages/debian/pub $(lsb_release -cs) robotpkg" \
   | tee /etc/apt/sources.list.d/robotpkg.list && apt update && apt install -qqy robotpkg-py3*-pinocchio

# RUN add-apt-repository ppa:ros-for-jammy/noetic && \
#     apt update 
    # apt install ros-noetic-desktop-full -y 
    # echo "source /opt/ros/noetic/setup.bash" >> ~/.bashrc && 

RUN add-apt-repository ppa:malcscott/ppa && \
    apt update && \
    apt install hddtemp

RUN git clone https://github.com/ROS-on-Ubuntu/ROS-on-Jammy.git && cd ROS-on-Jammy && \
    pip3 install -U rosdep rosinstall_generator vcstool && \
    mkdir -p /etc/ros/rosdep/sources.list.d/ && \
    curl -o /etc/ros/rosdep/sources.list.d/20-default.list https://gitee.com/qinyinan/rosdistro/raw/master/rosdep/sources.list.d/20-default.list && \
    rosdep update --rosdistro=noetic && \
    mkdir -p src && \
    vcs import --input noetic-desktop.rosinstall ./src && \
    mkdir -p /opt/ros/noetic && \
    chmod 777 /opt/ros/noetic && \
    rosdep install --from-paths ./src --ignore-packages-from-source --rosdistro noetic -y && \
    ./src/catkin/bin/catkin_make_isolated --install-space /opt/ros/noetic  --install -DCMAKE_BUILD_TYPE=Release -DCATKIN_ENABLE_TESTING=OFF -DPYTHON_EXECUTABLE=/usr/bin/python3 




# 配置用户 ros
ARG USERNAME=ros
ARG UID=1002
ARG GID=1002

RUN groupadd -g $GID ros && \
    useradd -m -u $UID -g $GID -s /bin/zsh ros && \
    echo "ros:1234" | chpasswd && \
    usermod -aG sudo ros

USER ros
ENV HOME=/home/ros


# 安装 zsh 和 Oh-My-Zsh
RUN sh -c "$(wget -O- https://install.ohmyz.sh/)" && \
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k && \
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# 配置 zsh
RUN sed -i 's/^ZSH_THEME=".*"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc && \
    sed -i 's/^plugins=(.*)/plugins=(git zsh-syntax-highlighting zsh-autosuggestions)/' ~/.zshrc

# 修复 p10k 配置
RUN echo "[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh" >> ~/.zshrc && \
    echo "export TERM=xterm-256color" >> ~/.zshrc && \
    echo "export TERM=xterm-256color" >> ~/.bashrc

COPY .p10k.zsh /home/ros/.p10k.zsh

USER root
# 配置 SSH 服务
RUN mkdir -p /etc/ssh /var/run/sshd && mkdir -p /home/ros/.ssh  && \
    ssh-keygen -A && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'Port 10023' >> /etc/ssh/sshd_config

# 配置 ROS 环境
RUN echo "source /opt/ros/noetic/setup.bash" >> ~/.bashrc && \
    echo "source /opt/ros/noetic/setup.zsh" >> ~/.zshrc
# RUN apt install sshpass && which sshpass

# 设置环境变量
ENV DISPLAY=:0
USER ros
WORKDIR /home/ros

# 暴露 SSH 端口
EXPOSE 10023

# 启动 sshd 服务并保持容器不退出
CMD ["sshpass", "-p", "1234", "sudo", "/usr/sbin/sshd", "-D"]

