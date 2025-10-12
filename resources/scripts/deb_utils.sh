#!/bin/bash

check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        echo "❌ 本脚本需要 root 权限运行"
        echo "👉 请使用: sudo $0 $*"
        exit 1
    fi
}


drop_to_user() {
    local user="${SUDO_USER:-$(logname 2>/dev/null)}"
    if [[ -z "$user" ]]; then
        echo "无法确定普通用户" >&2
        return 1
    fi
    echo "切换到普通用户: $user"
    exec sudo -u "$user" -E bash
}


get_git_info() {
    # 获取当前分支名称
    branch_name=$(git rev-parse --abbrev-ref HEAD)

    # 替换 / 为 -
    # branch_name=$(echo "$branch_name" | sed 's/\//-/g')
    # 删除所有斜杠
    branch_name=$(echo "$branch_name" | sed 's/\///g')

    # 获取当前分支的提交数量
    commit_count=$(git rev-list --count HEAD)

    # 获取当前分支的最新提交哈希值
    commit_hash=$(git log -1 --format=%h)

    # 返回格式化的结果
    echo "$branch_name+$commit_count-$commit_hash"
    # how to use 调用函数并将结果赋值给变量
    # git_info=$(get_git_info)
}

build_ros_deb() {
    local PKG_PATH="$1"   # 函数参数：功能包路径
    local PREFIX="$2"     # 函数参数: 生成的包名前缀
    local IS_POSTRM="$3"
    local ARCH_STR="$4"   # Architecture 指定值

    if [ ! -d "$PKG_PATH" ]; then
        echo "❌ ERROR: Package path not found: $PKG_PATH"
        return 1
    fi

    # 获取包名
    local PKG
    PKG=$(basename "$PKG_PATH")

    echo "📦 Processing package: $PKG ($PKG_PATH)"

    cd "$PKG_PATH" || exit 1
    sleep 0.2

    echo "🧹 Removing old debian and build directories..."
    rm -rf debian .obj-x86_64-linux-gnu
    sleep 0.2

    echo "🛠  Generating debian package for $PKG..."
    if [[ "$CI" == "true" ]]; then
        sudo -u "$SUDO_USER" bloom-generate rosdebian --ros-distro "$(rosversion -d)"
    else
        git_info=$(get_git_info)
        sudo -u "$SUDO_USER" bloom-generate rosdebian --ros-distro "$(rosversion -d)" --debian-inc "$git_info"
    fi
    sleep 0.2

    echo "⚙ Modifying debian/rules..."
    {
        echo ""
        echo "override_dh_strip:"
        echo "	true"
        echo ""
        echo "override_dh_shlibdeps:"
        echo "	true"
    } >> debian/rules

    if [ "$IS_POSTRM" = "true" ]; then

        echo "Create debian/postinst..."
        {
            echo "mkdir -p /opt/ros/noetic/include/zj_humanoid"
            echo "mkdir -p /opt/ros/noetic/lib/python3/dist-packages/zj_humanoid"
            echo "echo Installing directory: /opt/ros/noetic/include/zj_humanoid/${PKG}"
            echo "cp -r /opt/ros/noetic/include/${PKG} /opt/ros/noetic/include/zj_humanoid/${PKG}"
            echo "echo Installing directory: /opt/ros/noetic/lib/python3/dist-packages/zj_humanoid/${PKG}"
            echo "cp -r /opt/ros/noetic/lib/python3/dist-packages/${PKG} /opt/ros/noetic/lib/python3/dist-packages/zj_humanoid/${PKG}"
            echo "touch /opt/ros/noetic/lib/python3/dist-packages/zj_humanoid/__init__.py"
        } >> debian/postinst
        chmod +x debian/postinst

        echo "⚙ Modifying debian/rules..."
        {
            echo ""
            echo "_PATH_INCLUDE_PKG=/opt/ros/noetic/include/zj_humanoid/${PKG}"
            echo "_PATH_PYTHON3_PKG=/opt/ros/noetic/lib/python3/dist-packages/zj_humanoid/${PKG}"
        } >> debian/postrm
        cat "$SCRIPT_DIR/postrm" >> debian/postrm
        chmod +x debian/postrm
    fi


    if [ -n "$PREFIX" ]; then
        sed -i "s/^Source: /Source: ${PREFIX}-/" debian/control
        sed -i "s/^Package: /Package: ${PREFIX}-/" debian/control
        sed -i "1s/^\(\S\+\) (/$(echo "${PREFIX}-\1") (/" debian/changelog
    fi

    if [ -n "$ARCH_STR" ]; then
        echo "⚙ Setting Architecture: $ARCH_STR in debian/control..."
        sed -i "s/^Architecture: .*/Architecture: ${ARCH_STR}/" debian/control
    fi

    # 如果是 msgs 或 srvs 包，删除自动生成的 include 目录
    if [[ "$PKG" == *msgs || "$PKG" == *srvs ]]; then
        echo "🗑  Removing include directory for message/service package..."
        if [ -n "$PREFIX" ]; then
            echo "Removing debian/$PREFIX-ros-$(rosversion -d)-$PKG/opt/ros/$(rosversion -d)/include/$PKG"
            rm -rf "debian/$PREFIX-ros-$(rosversion -d)-$PKG/opt/ros/$(rosversion -d)/include/$PKG"
        else
            echo "Removing debian/$PREFIX-ros-$(rosversion -d)-$PKG/opt/ros/$(rosversion -d)/include/$PKG"
            rm -rf "debian/ros-$(rosversion -d)-$PKG/opt/ros/$(rosversion -d)/include/$PKG"
        fi
    fi
    sleep 0.2

    echo "📦 Building binary package for $PKG..."
    sudo -u "$SUDO_USER" fakeroot debian/rules binary
    sleep 0.2

    echo "📥 Installing generated deb package..."
    sudo apt-get install ../*.deb
    sleep 0.2

    echo "📦 Moving deb package to dist directory..."
    sudo -u "$SUDO_USER" mkdir -p "$PKG_PATH/../dist"
    sudo -u "$SUDO_USER" mv ../*.deb "$PKG_PATH/../dist/"
    cd "$PKG_PATH/../dist/" && ls
    sleep 0.2

    echo "✅ Done building $PKG"
}



uninstall_ros_debs() {
    local DIST_DIR="$1"  # dist 目录路径
    if [ ! -d "$DIST_DIR" ]; then
        echo "❌ ERROR: dist directory not found: $DIST_DIR"
        return 1
    fi

    echo "🔍 Searching for installed packages from $DIST_DIR..."
    local pkgs_to_remove=()

    for deb in "$DIST_DIR"/*.deb; do
        [ -f "$deb" ] || continue
        pkg_name=$(dpkg-deb -f "$deb" Package)
        if dpkg -l | grep -q "^ii\s\+$pkg_name"; then
            pkgs_to_remove+=("$pkg_name")
        fi
    done

    if [ ${#pkgs_to_remove[@]} -eq 0 ]; then
        echo "ℹ No matching installed packages found."
        return 0
    fi

    echo "🗑 Removing packages: ${pkgs_to_remove[*]}"
    sudo apt-get purge -y "${pkgs_to_remove[@]}"
    echo "✅ Uninstall complete."
}


create_rosdep_source() {
    local pkgs_name="$1"
    local script_dir="$2"
    local target_file="/etc/ros/rosdep/sources.list.d/100-local-${pkgs_name}.list"

    echo "Creating $target_file for rosdep..."

    # 如果文件不存在则创建
    if [[ ! -f "$target_file" ]]; then
        echo "yaml file://${script_dir}/rosdep.yaml" > "$target_file"
        echo "File created: $target_file"
        rosdep update --rosdistro=noetic
    else
        echo "File already exists: $target_file"
    fi

}






# main分支进行保护,无法直接进行推送
# 本地构建添加git_info
# 云端构建如果是打tag的方式,如果是版本号+后缀的话,那么加上后缀
# 如果是main分支触发或者其他分支进行触发的话