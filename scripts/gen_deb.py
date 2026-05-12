#!/usr/bin/env python3
from re import A
from typing import List, Optional
from plumbum import CommandNotFound, ProcessExecutionError, local , FG
from plumbum.cmd import sudo, chmod, echo, cat, git, sed
from pathlib import Path
import fire
from loguru import logger
from dataclasses import asdict, dataclass, field
from dataclasses_json import dataclass_json
import json
import os

VERSION = "0.1.0"

# ROS_VERSION = local["/usr/bin/rosversion"]["-d"]().strip()
ROS_VERSION = os.environ.get("ROS_DISTRO", None)
if ROS_VERSION is None:
    logger.error("未检测到 ROS 版本,请确保已正确加载 ROS 环境变量")
    exit(1)


rospack           = local["/opt/ros/noetic/bin/rospack"]
rosdep            = local["/usr/bin/rosdep"]
bloom_generate    = local["bloom-generate"]
fakeroot          = local["fakeroot"]


def is_git_repo(path: str) -> bool:
    try:
        with local.cwd(path):
            return git("rev-parse", "--is-inside-work-tree").strip() == "true"
    except (ProcessExecutionError, CommandNotFound, FileNotFoundError):
        return False


def get_branch_info():
    branch_name = git("rev-parse", "--abbrev-ref", "HEAD").strip()
    branch_name = branch_name.replace("/", "")
    branch_name = branch_name.replace("_", "")
    commit_count = git("rev-list", "--count", "HEAD").strip()
    commit_hash = git("log", "-1", "--format=%h").strip()
    return f"{branch_name}+{commit_count}-{commit_hash}"


def create_rosdep_source(pkgs_name, script_dir):
    target_file=f"/etc/ros/rosdep/sources.list.d/100-local-{pkgs_name}.list"

    if Path(target_file).parent.exists() is False:
        sudo["rosdep", "init"]()

    if Path(target_file).exists():
        print(f"{target_file} already exists.")
        return

    from plumbum.cmd import echo, tee
    content = f"yaml file://{script_dir}/rosdep.yaml"
    (echo[content] | sudo[tee[target_file]])()
    print(f"Content written to {target_file}")
    ret = rosdep["update", "--rosdistro=noetic"]()
    print(ret)



@dataclass_json
@dataclass
class PackageInfo:
    """包信息"""
    name: str                                   # 功能包名
    path: str                                   # 功能包路径
    version: str                                # 功能包版本
    abs_path: str                               # 功能包路径
    deb_name: Optional[str] = None              # 生成的deb包名称

@dataclass_json
@dataclass
class PackgesInfo:
    branch_name:str     = ""        # 分支命名
    commit_count:str    = ""        # 分支提交数量
    commit_hash:str     = ""        # 分支提交短hash
    packages: List[PackageInfo] = field(default_factory=list)

    def __str__(self) -> str:
        return f"{self.branch_name}+{self.commit_count}-{self.commit_hash}"


    def dump(self, file:str="/tmp/deb.json"):
        """将分支信息保存到JSON文件"""
        with open(file, "w", encoding="utf-8") as f:
            json.dump(asdict(self), f, indent=4, ensure_ascii=False)


from catkin_pkg.topological_order import topological_order


def get_workspace_packages(workspace_path):

    src_path = Path(workspace_path)
    
    # 按拓扑顺序排序
    ordered = topological_order(str(src_path))
    
    package_infos = []
    for pkg_path, pkg in ordered:

        package_infos.append(PackageInfo(
            name=pkg.name,
            path=pkg_path,
            abs_path=str(Path(pkg.filename).parent),
            version=pkg.version,
        ))
    
    return package_infos


from abc import ABC, abstractmethod
class Builder(ABC):


    def __init__(self, pkg:PackageInfo) -> None:
        self.__pkg = pkg
        self.deb_path, self.deb_name = None, None

    @abstractmethod
    def build(self):
        pass


    def clear(self):
        with local.cwd(self.__pkg.abs_path):
            logger.info("🧹 Removing old debian and build directories...")
            sudo["rm", "-rf", "debian", ".obj-x86_64-linux-gnu", "obj-x86_64-linux-gnu"]()


    def install(self):
        sudo["apt-get", "install", "-y", "--allow-downgrades", "--reinstall",self.deb_path] & FG


    def uninstall(self):
        sudo["apt-get", "purge", "-y", self.__pkg.deb_name] & FG

    def modify_deb_name(self, prefix: str="zj-humanoid", suffix: str=None):
        sed["-i", f"s/^Source: /Source: {prefix}-/", "debian/control"]()
        sed["-i", f"s/^Package: /Package: {prefix}-/", "debian/control"]()
        # sed["-i", f"1s/^\(\S\+\) (/$(echo \"{prefix}-\1\") (/", "debian/changelog"]()
        sed["-i", f"1s/^\\(\\S\\+\\) (/{prefix}-\\1 (/", "debian/changelog"]()


    def modify_deb_arch(self, arch: str="all"):
        sed["-i", f"s/^Architecture: .*/Architecture: {arch}/", "debian/control"]()


    def modify_debian_rules(self):
        raw_context = [
            "",
            "override_dh_strip:",
            "	true",
            "",
            "override_dh_shlibdeps:",
            "	true",
        ]
        context = "\n".join(raw_context)
        (echo[f"{context}"] >> "debian/rules")()
        # 开启多核编译
        context = Path("debian/rules").read_text()

        # 普通包不需要 catkin 二进制包参数，仅移除该行，保留其余 configure 配置
        context = context.replace('\t\t-DCATKIN_BUILD_BINARY_PACKAGE="1" \\', "")

        context = context.replace("dh $@ -v", "dh $@ -v --parallel")
        # 调整 catkin 二进制包安装前缀
        context = context.replace('-DCMAKE_INSTALL_PREFIX="/usr"', '-DCMAKE_INSTALL_PREFIX="/opt/zj_humanoid"')
        context = context.replace('-DCMAKE_PREFIX_PATH="/usr"', '-DCMAKE_PREFIX_PATH="/opt/zj_humanoid"')
        Path("debian/rules").write_text(context)


    def get_deb_info(self):
        text = Path(self.__pkg.abs_path).joinpath("debian", "files").read_text()
        self.deb_name = text.split(" ")[0]
        self.deb_path = str(Path(self.__pkg.abs_path).joinpath("..", self.deb_name))
        text = Path(self.__pkg.abs_path).joinpath("debian", "control").read_text()
        for line in text.split("\n"):
            if line.startswith("Package:"):
                self.__pkg.deb_name = line.split(" ")[1]


    def mv(self, dest_path:Path):
        dest_path.mkdir(parents=True, exist_ok=True)
        Path(self.deb_path).rename(dest_path.joinpath(self.deb_name))
        return dest_path.joinpath(self.deb_name)




class DebPackageBuilder(Builder):

    def build(self, prefix: str="zj-humanoid", arch: str="all", local_build: bool=False):
        logger.info(f"📦 Building package: {self.__pkg.name} at {self.__pkg.abs_path}")

        self.clear()
        with local.cwd(self.__pkg.abs_path):
            logger.info("🛠  Generating debian package...")
            if os.environ.get("IS_TAG_TRIGGER") == "true" or local_build:        # 打tag的时候云端也上传 tag名称就是v1.0.0等
            # TODO 根据构建的规则进行生成，是否要生成一个时间戳
                bloom_generate["debian", "--native", "--unsafe"]()
            else:
                bloom_generate["debian", "--native", "--debian-inc", f"{get_branch_info()}", "--unsafe"]()
            logger.info("🛠  Modifying debian/rules...")
            self.modify_debian_rules()
            self.modify_deb_name()
            logger.info("📦 Building debian package...")
            # TODO 判断当前系统的CPU核心数量，如果超过10核的情况下 在根据实际情况是否要进行多核编译
            with local.env(DEB_BUILD_OPTIONS="parallel=4 nocheck"):
                fakeroot["debian/rules", "binary"] & FG
        self.get_deb_info()
        self.clear()


class ROSPackageBuilder(Builder):


    def build(self, prefix: str="zj-humanoid", arch: str="all", local_build: bool=False):
        logger.info(f"📦 Building package: {self.__pkg.name} at {self.__pkg.abs_path}")

        self.clear()
        with local.cwd(self.__pkg.abs_path):

            logger.info("🛠  Generating debian package...")
            if os.environ.get("IS_TAG_TRIGGER") == "true" or local_build:        # 打tag的时候云端也上传 tag名称就是v1.0.0等
            # TODO 根据构建的规则进行生成，是否要生成一个时间戳
                bloom_generate["rosdebian", "--ros-distro", f"{ROS_VERSION}", "--unsafe"]()
            else:
                bloom_generate["rosdebian", "--ros-distro", f"{ROS_VERSION}", "--debian-inc", f"{get_branch_info()}", "--unsafe"]()

            logger.info("🛠  Modifying debian/rules...")
            self.modify_debian_rules()
            self.modify_deb_name(prefix)

            if self.is_data_package():
                self.modify_deb_arch(arch="all")
                logger.info("📦 Detected data package, modifying debian/postrm and debian/postinst...")
                self.postinst()
                self.postrm()

            logger.info("📦 Building debian package...")
            # TODO 判断当前系统的CPU核心数量，如果超过10核的情况下 在根据实际情况是否要进行多核编译
            with local.env(DEB_BUILD_OPTIONS="parallel=4 nocheck"):
                fakeroot["debian/rules", "binary"] & FG
        self.get_deb_info()
        self.clear()
    

    def postrm(self):
        PKG = self.__pkg.name
        raw_context = [
            "",
            f"_PATH_INCLUDE_PKG=/opt/ros/noetic/include/zj_humanoid/{PKG}",
            f"_PATH_PYTHON3_PKG=/opt/ros/noetic/lib/python3/dist-packages/zj_humanoid/{PKG}",
            "",
            "echo \"Removing directory: $_PATH_INCLUDE_PKG\"",
            "rm -rf \"$_PATH_INCLUDE_PKG\"",
            "echo \"Removing directory: $_PATH_PYTHON3_PKG\"",
            "rm -rf \"$_PATH_PYTHON3_PKG\"",
            "",
            "_PATH_INCLUDE=\"/opt/ros/noetic/include/zj_humanoid\"",
            "_PATH_PYTHON3=\"/opt/ros/noetic/lib/python3/dist-packages/zj_humanoid\"",
            "",
            "# 判断第一个文件夹是否为空，如果是则删除",
            "if [ -d \"$_PATH_INCLUDE\" ]; then",
            "    # 检查目录是否为空（仅包含隐藏文件也视为空）",
            "    if [ -z \"$(ls -A \"$_PATH_INCLUDE\")\" ]; then",
            "        echo \"Removing empty include directory: $_PATH_INCLUDE\"",
            "        rm -rf \"$_PATH_INCLUDE\"",
            "    fi",
            "fi",
            "",
            "# 判断第二个文件夹是否只包含__init__.py且没有其他文件/文件夹",
            "if [ -d \"$_PATH_PYTHON3\" ]; then",
            "    # 获取目录下所有文件和文件夹（包括隐藏文件）",
            "    contents=$(ls -A \"$_PATH_PYTHON3\")",
            "    # 检查是否只有__init__.py一个文件",
            "    if [ \"$contents\" = \"__init__.py\" ] && [ -f \"$_PATH_PYTHON3/__init__.py\" ]; then",
            "        echo \"Removing python directory with only __init__.py: $_PATH_PYTHON3\"",
            "        rm -rf \"$_PATH_PYTHON3\"",
            "    fi",
            "fi",
        ]
        context = "\n".join(raw_context)
        (echo[f"{context}"] >> "debian/postrm")()
        chmod["+x", "debian/postrm"]()


    def postinst(self):
        PKG = self.__pkg.name
        raw_context = [
            "mkdir -p /opt/ros/noetic/include/zj_humanoid",
            "mkdir -p /opt/ros/noetic/lib/python3/dist-packages/zj_humanoid",
            f"echo Installing directory: /opt/ros/noetic/include/zj_humanoid/{PKG}",
            f"cp -r /opt/ros/noetic/include/{PKG} /opt/ros/noetic/include/zj_humanoid/{PKG}",
            f"echo Installing directory: /opt/ros/noetic/lib/python3/dist-packages/zj_humanoid/{PKG}",
            f"cp -r /opt/ros/noetic/lib/python3/dist-packages/{PKG} /opt/ros/noetic/lib/python3/dist-packages/zj_humanoid/{PKG}",
            "touch /opt/ros/noetic/lib/python3/dist-packages/zj_humanoid/__init__.py"
        ]
        context = "\n".join(raw_context)
        (echo[f"{context}"] >> "debian/postinst")()
        chmod["+x", "debian/postinst"]()


    def is_data_package(self):  
        # TODO 判断是否为数据包
        is_have_msg = len(list(Path(self.__pkg.abs_path).rglob("*.msg")))
        is_have_srv = len(list(Path(self.__pkg.abs_path).rglob("*.srv")))
        is_have_action = len(list(Path(self.__pkg.abs_path).rglob("*.action")))
        return bool(is_have_msg + is_have_srv + is_have_action)





class RosDebCli:


    def __init__(self):
        self._local_build = False
        self._packages = PackgesInfo()


    def __call__(self, workspace: str, prefix: str="zj-humanoid", arch: str="all", local_build: bool=False) -> None:
        self._local_build = local_build

        if not self._local_build:
            if not is_git_repo(workspace):
                logger.error(f"工作空间路径 {workspace} 不是一个有效的 Git 仓库，请确保在 Git 仓库中运行，或者使用 --local-build 参数进行本地构建")
                exit(1)
            with local.cwd(workspace):
                self._packages = PackgesInfo(
                    branch_name  = git("rev-parse", "--abbrev-ref", "HEAD").strip().replace("/", "").replace("_", ""),
                    commit_count = git("rev-list", "--count", "HEAD").strip(),
                    commit_hash  = git("log", "-1", "--format=%h").strip()
                )
        self.build(workspace=workspace, prefix=prefix, arch=arch)


    def build(self, workspace: str, prefix: str="zj-humanoid", arch: str="all") -> None:
        sudo["su"]()
        workspace_path = Path(workspace).expanduser().resolve()
        if not workspace_path.exists():
            raise FileNotFoundError(f"工作空间路径不存在: {workspace_path}")

        packages = get_workspace_packages(workspace_path)
        if not packages:
            logger.warning(f"未在 {workspace_path} 下找到可构建的包")
            return

        builders: List[ROSPackageBuilder] = []
        for pkg in packages:
            pkg:PackageInfo
            builder = ROSPackageBuilder(pkg)
            builders.append(builder)
            builder.build(prefix=prefix, arch=arch)
            builder.install()
            deb_name = builder.mv(workspace_path.joinpath("dist").resolve())
            pkg.deb_name = str(deb_name)
            self._packages.packages.append(pkg)
            

        for builder in reversed(builders):
            builder.uninstall()


        # 在这里生成临时json文件
        self._packages.dump()

# /tmp/deb.json json文件

if __name__ == "__main__":
    fire.Fire(RosDebCli)
