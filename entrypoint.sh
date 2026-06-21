#!/bin/sh
# 这个脚本会在容器启动时运行，用于动态修改 /etc/hosts 文件。

# 定义要配置的域名列表
DOMAINS="github.com raw.githubusercontent.com github.global.ssl.fastly.net assets-cdn.github.com"

# 定义hosts文件路径
HOSTS_FILE="/etc/hosts"
ENV_FILE="/etc/environment"

echo "--- Docker Entry: Starting host configuration ---"

# 备份原始的 /etc/hosts 文件
# cp $HOSTS_FILE "${HOSTS_FILE}.bak"
# echo "Original hosts file backed up to ${HOSTS_FILE}.bak"

# 清理 hosts 文件中旧的 GitHub 相关条目
# 使用 sed 删除任何包含这些域名的行
for domain in $DOMAINS; do
    sshpass -p 1234 sudo bash -c "sed -i \"/$domain/d\" $HOSTS_FILE"
done
echo "Cleaned up old host entries."
sshpass -p 1234 sudo bash -c "printf \"\n\n\" >> $HOSTS_FILE"
# 循环处理每个域名，解析并追加到 hosts 文件
for domain in $DOMAINS; do
    echo "Resolving $domain..."
    # 使用 dig 获取所有 A 记录，然后格式化后追加到 hosts 文件
    dig +short "$domain" | while read -r ip; do
        sshpass -p 1234 sudo bash -c "echo \"$ip $domain\" >> $HOSTS_FILE"
    done
done

if [ -f "$ENV_FILE" ]; then
    # SSH login does not inherit Docker Compose environment variables.
    # Persist the local graphics socket variables so plain SSH sessions can use them.
    for name in DISPLAY XDG_RUNTIME_DIR WAYLAND_DISPLAY; do
        value=$(eval "printf '%s' \"\${$name}\"")
        sshpass -p 1234 sudo bash -c "sed -i '/^${name}=/d' $ENV_FILE"
        if [ -n "$value" ]; then
            sshpass -p 1234 sudo bash -c "printf '%s\n' '${name}=${value}' >> $ENV_FILE"
        fi
    done
fi

echo "Host configuration complete."
echo "--- Docker Entry: Handing over to final command ---"

# 执行 Dockerfile CMD 或 docker run 时传入的命令
# 使用 exec 是最佳实践，让最终命令成为 PID 1，能正确接收信号
exec "$@"
