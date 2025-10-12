import os
import sys
import sh

def check_sudo():
    if os.geteuid() != 0:
        print("❌ 本脚本需要 root 权限运行")
        print(f"👉 请使用: sudo python3 {sys.argv[0]} {' '.join(sys.argv[1:])}")
        sys.exit(1)


def drop_to_user():
    user = os.environ.get('SUDO_USER') or sh.logname().strip()
    if not user:
        print("无法确定普通用户", file=sys.stderr)
        return 1
    print(f"切换到普通用户: {user}")
    sh.sudo('-u', user, '-E', 'bash')


def get_git_info():
    branch_name = sh.git('rev-parse', '--abbrev-ref', 'HEAD').strip()
    branch_name = branch_name.replace('/', '')
    commit_count = sh.git('rev-list', '--count', 'HEAD').strip()
    commit_hash = sh.git('log', '-1', '--format=%h').strip()
    return f"{branch_name}+{commit_count}-{commit_hash}"


def build_ros_deb(pkg_path, prefix=None, is_postrm=False, arch_str=None):
    if not os.path.isdir(pkg_path):
        print(f"❌ ERROR: Package path not found: {pkg_path}")
        return 1
    pkg = os.path.basename(pkg_path)
    print(f"📦 Processing package: {pkg} ({pkg_path})")
    os.chdir(pkg_path)
    sh.rm('-rf', 'debian', '.obj-x86_64-linux-gnu')
    print("🛠  Generating debian package for", pkg)
    if os.environ.get('CI') == 'true':
        sh.sudo('-u', os.environ.get('SUDO_USER'), 'bloom-generate', 'rosdebian', '--ros-distro', sh.rosversion('-d').strip())
    else:
        git_info = get_git_info()
        sh.sudo('-u', os.environ.get('SUDO_USER'), 'bloom-generate', 'rosdebian', '--ros-distro', sh.rosversion('-d').strip(), '--debian-inc', git_info)
    with open('debian/rules', 'a') as f:
        f.write("\noverride_dh_strip:\n\ttrue\n\noverride_dh_shlibdeps:\n\ttrue\n")
    if is_postrm:
        with open('debian/postinst', 'a') as f:
            f.write("mkdir -p /opt/ros/noetic/include/zj_humanoid\n")
            f.write("mkdir -p /opt/ros/noetic/lib/python3/dist-packages/zj_humanoid\n")
            f.write(f"echo Installing directory: /opt/ros/noetic/include/zj_humanoid/{pkg}\n")
            f.write(f"cp -r /opt/ros/noetic/include/{pkg} /opt/ros/noetic/include/zj_humanoid/{pkg}\n")
            f.write(f"echo Installing directory: /opt/ros/noetic/lib/python3/dist-packages/zj_humanoid/{pkg}\n")
            f.write(f"cp -r /opt/ros/noetic/lib/python3/dist-packages/{pkg} /opt/ros/noetic/lib/python3/dist-packages/zj_humanoid/{pkg}\n")
            f.write("touch /opt/ros/noetic/lib/python3/dist-packages/zj_humanoid/__init__.py\n")
        sh.chmod('+x', 'debian/postinst')
    if prefix:
        sh.sed('-i', f"s/^Source: /Source: {prefix}-/", 'debian/control')
        sh.sed('-i', f"s/^Package: /Package: {prefix}-/", 'debian/control')
        sh.sed('-i', f"1s/^\(\S\+\) (/$(echo '{prefix}-\1') (/", 'debian/changelog')
    if arch_str:
        sh.sed('-i', f"s/^Architecture: .*/Architecture: {arch_str}/", 'debian/control')
    if pkg.endswith('msgs') or pkg.endswith('srvs'):
        print("🗑  Removing include directory for message/service package...")
        if prefix:
            sh.rm('-rf', f"debian/{prefix}-ros-{sh.rosversion('-d').strip()}-{pkg}/opt/ros/{sh.rosversion('-d').strip()}/include/{pkg}")
        else:
            sh.rm('-rf', f"debian/ros-{sh.rosversion('-d').strip()}-{pkg}/opt/ros/{sh.rosversion('-d').strip()}/include/{pkg}")
    print(f"📦 Building binary package for {pkg}...")
    sh.sudo('-u', os.environ.get('SUDO_USER'), 'fakeroot', 'debian/rules', 'binary')
    print("📥 Installing generated deb package...")
    sh.sudo('apt-get', 'install', '../*.deb')
    print("📦 Moving deb package to dist directory...")
    sh.sudo('-u', os.environ.get('SUDO_USER'), 'mkdir', '-p', f"{pkg_path}/../dist")
    sh.sudo('-u', os.environ.get('SUDO_USER'), 'mv', '../*.deb', f"{pkg_path}/../dist/")
    os.chdir(f"{pkg_path}/../dist/")
    sh.ls()
    print(f"✅ Done building {pkg}")


def uninstall_ros_debs(dist_dir):
    if not os.path.isdir(dist_dir):
        print(f"❌ ERROR: dist directory not found: {dist_dir}")
        return 1
    pkgs_to_remove = []
    for deb in os.listdir(dist_dir):
        if deb.endswith('.deb'):
            pkg_name = sh.dpkg_deb('-f', os.path.join(dist_dir, deb), 'Package').strip()
            if pkg_name and sh.grep('^ii\s\+' + pkg_name, _ok_code=[0,1], _in=sh.dpkg('-l')).exit_code == 0:
                pkgs_to_remove.append(pkg_name)
    if not pkgs_to_remove:
        print("ℹ No matching installed packages found.")
        return 0
    print(f"🗑 Removing packages: {' '.join(pkgs_to_remove)}")
    sh.sudo('apt-get', 'purge', '-y', *pkgs_to_remove)
    print("✅ Uninstall complete.")


def create_rosdep_source(pkgs_name, script_dir):
    target_file = f"/etc/ros/rosdep/sources.list.d/100-local-{pkgs_name}.list"
    print(f"Creating {target_file} for rosdep...")
    if not os.path.isfile(target_file):
        with open(target_file, 'w') as f:
            f.write(f"yaml file://{script_dir}/rosdep.yaml\n")
        print(f"File created: {target_file}")
        sh.rosdep('update', '--rosdistro=noetic')
    else:
        print(f"File already exists: {target_file}")

# 其他辅助函数可按需补充