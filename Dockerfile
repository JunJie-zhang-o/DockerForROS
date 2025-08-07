


# 如果这里加了--platform=linux/x86 在docker run的时候就可以 docker run --platform linux/x86
# FROM  --platform="linux/amd64" osrf/ros:noetic-desktop-full
FROM osrf/ros:noetic-desktop-full


RUN apt update && apt upgrade -y

RUN apt install bash-completion openssh-server net-tools nano zsh git curl x11-apps iputils-ping sshpass -y

ARG USERNAME=ros
# 创建用户并配置 sudo | 用户名ros 密码1234
# RUN useradd -m -s /bin/zsh ros && echo "ros:1234" | chpasswd && adduser ros sudo
ARG UID=1002
ARG GID=1002

# 创建组和用户并指定 UID/GID
RUN groupadd -g $GID ros && \
    useradd -m -u $UID -g $GID -s /bin/zsh ros && \
    echo "ros:1234" | chpasswd && \
    usermod -aG sudo ros

# 切换到 ros 用户，后续命令以 ros 用户身份执行
USER ros
ENV HOME=/home/ros

# 安装zsh
# RUN chsh -s /bin/zsh
RUN sh -c "$(wget -O- https://install.ohmyz.sh/)"

RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
RUN git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
RUN git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
# \
RUN sed -i 's/^ZSH_THEME=".*"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc 
RUN sed -i 's/^plugins=(.*)/plugins=(git zsh-syntax-highlighting zsh-autosuggestions)/' ~/.zshrc
# 修复p10k配置无法rainbow的问题
# USER root
RUN echo "[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh" >> ~/.zshrc && \
    echo "export TERM=xterm-256color" >> ~/.zshrc && \
    echo "export TERM=xterm-256color" >> ~/.bashrc

COPY .p10k.zsh /home/ros/.p10k.zsh

# 进行配置的替换
# COPY .p10k.zsh /home/ros/



# 切换回 root 用户
USER root
# SSH 配置
RUN mkdir -p /etc/ssh /var/run/sshd
RUN ssh-keygen -A
RUN echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
RUN echo 'Port 10022' >> /etc/ssh/sshd_config


# 配置ros环境变量
RUN echo "source /opt/ros/noetic/setup.bash" >> ~/.bashrc
RUN echo "source /opt/ros/noetic/setup.zsh" >> ~/.zshrc


ENV DISPLAY=:0

USER ros
WORKDIR /home/ros

# 暴露 SSH 端口
EXPOSE 10022
# 启动 sshd 服务并保持容器不退出
CMD ["sshpass", "-p", "1234", "sudo", "/usr/sbin/sshd", "-D"]
