#!/usr/bin/env python3
import argparse
import os
import subprocess
import zipfile
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional


EXCLUDE_DIRS = {
    ".git",
    ".cache",
    "build",
    "build_isolated",
    "devel",
    "devel_isolated",
    "dist",
    "dists",
    "install",
    "log",
    "logs",
}


def git_output(repo_dir: Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(repo_dir), *args],
        text=True,
        stderr=subprocess.DEVNULL,
    ).strip()


def git_output_optional(repo_dir: Path, *args: str) -> Optional[str]:
    try:
        return git_output(repo_dir, *args)
    except subprocess.CalledProcessError:
        return None


def env_tag_name() -> Optional[str]:
    for name in ("TAG", "TAG_NAME", "GIT_TAG"):
        value = os.environ.get(name)
        if value:
            return value
    return None


@dataclass(frozen=True)
class BuildMetaInfo:
    commit_id: str
    commit_count: str
    branch: str
    build_time: str
    tag: Optional[str] = None

    @classmethod
    def from_git(cls, repo_dir: Path) -> "BuildMetaInfo":
        tag = env_tag_name() or git_output_optional(
            repo_dir, "describe", "--tags", "--exact-match", "HEAD"
        )
        return cls(
            commit_id=git_output(repo_dir, "rev-parse", "HEAD"),
            commit_count=git_output(repo_dir, "rev-list", "--count", "HEAD"),
            branch=git_output(repo_dir, "rev-parse", "--abbrev-ref", "HEAD"),
            build_time=datetime.now().astimezone().isoformat(timespec="seconds"),
            tag=tag,
        )

    @property
    def short_commit_id(self) -> str:
        return self.commit_id[:7]

    @property
    def zip_suffix(self) -> str:
        branch_name = self.branch.replace("/", "").replace("_", "")
        return f"{branch_name}+{self.commit_count}.{self.short_commit_id}"

    @property
    def is_tag_trigger(self) -> bool:
        return os.environ.get("IS_TAG_TRIGGER") == "true"

    @property
    def tag_zip_suffix(self) -> str:
        if not self.tag:
            raise RuntimeError("IS_TAG_TRIGGER=true but no tag name was found")
        return self.tag.replace("/", "").replace("_", "")

    def default_zip_name(self, package_name: str) -> str:
        if self.is_tag_trigger:
            return f"{package_name}-{self.tag_zip_suffix}.zip"
        return f"{package_name}-{self.zip_suffix}.zip"

    def as_package_fields(self) -> Dict[str, str]:
        fields = {
            "commit_id": self.commit_id,
            "commit_count": self.commit_count,
            "build_time": self.build_time,
        }
        if self.is_tag_trigger:
            if not self.tag:
                raise RuntimeError("IS_TAG_TRIGGER=true but no tag name was found")
            fields["tag"] = self.tag
        else:
            fields["branch"] = self.branch
        return fields


def package_xml_with_metainfo(package_xml: Path, metainfo: BuildMetaInfo) -> bytes:
    original_lines = package_xml.read_text().splitlines()
    leading_models = [
        line for line in original_lines[1:] if line.strip().startswith("<?xml-model ")
    ]
    parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True, insert_pis=True))
    tree = ET.parse(package_xml, parser=parser)
    root = tree.getroot()
    export = root.find("export")
    if export is None:
        export = ET.SubElement(root, "export")

    for existing in list(export.findall("metainfo")):
        export.remove(existing)

    meta_element = ET.Element("metainfo")
    meta_element.text = "\n      "
    metainfo_fields = metainfo.as_package_fields()
    if metainfo.is_tag_trigger:
        metainfo_keys = ("commit_id", "commit_count", "tag", "build_time")
    else:
        metainfo_keys = ("commit_id", "commit_count", "branch", "build_time")
    for index, key in enumerate(metainfo_keys):
        child = ET.SubElement(meta_element, key)
        child.text = metainfo_fields[key]
        child.tail = "\n    " if index == 3 else "\n      "

    export.insert(0, meta_element)
    export.text = "\n    "
    meta_element.tail = "\n    "

    content = ET.tostring(root, encoding="utf-8", xml_declaration=True)
    if leading_models:
        first_newline = content.find(b"\n")
        model_content = ("\n".join(leading_models) + "\n").encode()
        return content[: first_newline + 1] + model_content + content[first_newline + 1 :]
    return content


def should_exclude(path: Path, root_dir: Path) -> bool:
    rel_path = path.relative_to(root_dir)
    if any(part in EXCLUDE_DIRS for part in rel_path.parts):
        return True
    return path.suffix == ".zip"


def add_directory(zip_file: zipfile.ZipFile, root_dir: Path, directory: Path) -> None:
    if should_exclude(directory, root_dir):
        return
    archive_name = directory.relative_to(root_dir).as_posix().rstrip("/") + "/"
    zip_info = zipfile.ZipInfo(archive_name)
    zip_file.writestr(zip_info, "")


def create_zip(source: Path, dist_dir: Path, zip_name: Optional[str] = None) -> Path:
    root_dir = source.parent
    metainfo = BuildMetaInfo.from_git(root_dir)
    if zip_name is None:
        zip_name = metainfo.default_zip_name(source.name)

    dist_dir.mkdir(parents=True, exist_ok=True)
    zip_path = dist_dir / zip_name
    zip_path.unlink(missing_ok=True)

    legacy_zip_path = root_dir / zip_name
    if legacy_zip_path != zip_path:
        legacy_zip_path.unlink(missing_ok=True)

    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zip_file:
        add_directory(zip_file, root_dir, source)
        for path in sorted(source.rglob("*")):
            if should_exclude(path, root_dir):
                continue
            if path.is_dir():
                add_directory(zip_file, root_dir, path)
            else:
                archive_name = path.relative_to(root_dir).as_posix()
                if path == source / "package.xml":
                    zip_file.writestr(archive_name, package_xml_with_metainfo(path, metainfo))
                else:
                    zip_file.write(path, archive_name)

    return zip_path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build the WA-T description zip package.")
    parser.add_argument("--source", default="wa_t_description", help="Directory to archive.")
    parser.add_argument("--dist-dir", default="dists", help="Directory for the generated zip.")
    parser.add_argument("--zip-name", default=None, help="Output zip file name.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    script_dir = Path(__file__).resolve().parent
    repo_dir = script_dir.parent
    source = (repo_dir / args.source).resolve()
    dist_dir = (repo_dir / args.dist_dir).resolve()

    if not source.is_dir():
        raise SystemExit(f"source directory does not exist: {source}")

    zip_path = create_zip(source, dist_dir, args.zip_name)
    print(zip_path)


if __name__ == "__main__":
    main()
