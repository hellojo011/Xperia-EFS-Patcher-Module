"""Builds the flashable KernelSU/Magisk module zip.

    python build.py [--profiles <efs dir>] [--ndk <ndk dir>]

Steps: compile native/efsdiag.c with the NDK, copy the efs/<carrier>/sim<n>
profile folders into profiles/<carrier>/sim<n>, normalize script line endings
and write dist/efsprofile_kr-<version>.zip.
"""

import argparse
import json
import re
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MODULE = ROOT / "module"
DIST = ROOT / "dist"
BUILD = ROOT / "build"

DEFAULT_PROFILES = ROOT / "efs"
DEFAULT_NDK = Path(r"C:\Android\Sdk\ndk\28.2.13676358")

# efs/<carrier>/sim<n>, the same layout as profiles/ inside the module.
PROFILE_DIRS = {(c, s): f"{c}/sim{s}" for c in ("SKT", "KT", "LGU") for s in (1, 2)}

# efs/GLOBAL: files shared by every carrier (the global band set option).
GLOBAL_DIR = "GLOBAL"

# efs/info.json -> profiles/info.prop (key=value, read by efsctl.sh info).
INFO_KEYS = ("version", "source")

TEXT_SUFFIXES = {".sh", ".prop", ".html", ".js"}
TEXT_NAMES = {"update-binary", "updater-script"}


def compile_native(ndk: Path) -> Path:
    clang = ndk / "toolchains/llvm/prebuilt/windows-x86_64/bin/aarch64-linux-android31-clang.cmd"
    if not clang.exists():
        sys.exit(f"NDK clang not found: {clang}")
    BUILD.mkdir(exist_ok=True)
    out = BUILD / "efsdiag"
    cmd = [str(clang), "-O2", "-Wall", "-Wextra", "-Wno-unused-parameter", "-fPIE", "-pie", "-s",
           str(ROOT / "native/efsdiag.c"), "-ldl", "-o", str(out)]
    print("+", " ".join(cmd))
    subprocess.run(cmd, check=True)
    return out


def efs_info(profiles: Path) -> dict:
    """Reads efs/info.json. Also accepts the loose form with unquoted keys
    and no commas, e.g. { version: "261024-1843" source: "https://..." }."""
    src = profiles / "info.json"
    if not src.is_file():
        return {}
    text = src.read_text(encoding="utf-8-sig")
    try:
        data = json.loads(text)
    except ValueError:
        data = dict(re.findall(r'"?(\w+)"?\s*:\s*"([^"\r\n]*)"', text))
    return {k: str(data[k]).strip() for k in INFO_KEYS if str(data.get(k, "")).strip()}


def git(profiles: Path, *args: str) -> str:
    try:
        r = subprocess.run(["git", "-C", str(profiles), *args], capture_output=True, text=True, encoding="utf-8")
    except OSError:
        return ""
    return r.stdout.strip() if r.returncode == 0 else ""


def efs_tag(profiles: Path) -> str:
    """Release tag of the efs checkout when HEAD is exactly at a tag."""
    return git(profiles, "describe", "--tags", "--exact-match", "HEAD")


def eol_mismatches(profiles: Path) -> list:
    """Files whose working copy differs from the committed blob only by line
    endings (core.autocrlf). The module bundles the working copy, a GitHub
    release serves the blob, so the two would not be byte-identical."""
    out = []
    for line in git(profiles, "ls-files", "--eol").splitlines():
        parts = line.split(None, 3)
        if len(parts) == 4 and parts[3].strip().split("/")[0] not in ("SKT", "KT", "LGU", GLOBAL_DIR):
            continue
        if len(parts) == 4 and parts[0].startswith("i/") and parts[1].startswith("w/"):
            i, w = parts[0][2:], parts[1][2:]
            if i != w and "crlf" in (i, w):
                out.append(f"{parts[3].strip()} (repo {i}, local {w})")
    return out


def module_version() -> str:
    for line in (MODULE / "module.prop").read_text(encoding="utf-8").splitlines():
        if line.startswith("version="):
            return line.split("=", 1)[1].strip()
    return "dev"


def add_text(zf: zipfile.ZipFile, src: Path, arcname: str) -> None:
    data = src.read_bytes().replace(b"\r\n", b"\n")
    info = zipfile.ZipInfo(arcname)
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = (0o755 if src.suffix == ".sh" or src.name == "update-binary" else 0o644) << 16
    zf.writestr(info, data)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--profiles", type=Path, default=DEFAULT_PROFILES)
    ap.add_argument("--ndk", type=Path, default=DEFAULT_NDK)
    args = ap.parse_args()

    for rel in PROFILE_DIRS.values():
        if not (args.profiles / rel).is_dir():
            sys.exit(f"profile folder missing: {args.profiles / rel}")

    binary = compile_native(args.ndk)
    DIST.mkdir(exist_ok=True)
    zip_path = DIST / f"efsprofile_kr-{module_version()}.zip"

    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for src in sorted(MODULE.rglob("*")):
            if not src.is_file():
                continue
            arc = src.relative_to(MODULE).as_posix()
            if src.suffix in TEXT_SUFFIXES or src.name in TEXT_NAMES:
                add_text(zf, src, arc)
            else:
                zf.write(src, arc)

        info = zipfile.ZipInfo("bin/efsdiag")
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o755 << 16
        zf.writestr(info, binary.read_bytes())

        count = 0
        for (carrier, slot), rel in PROFILE_DIRS.items():
            base = args.profiles / rel
            for f in sorted(base.rglob("*")):
                if f.is_file():
                    arc = f"profiles/{carrier}/sim{slot}/{f.relative_to(base).as_posix()}"
                    zf.write(f, arc)
                    count += 1

        gbase = args.profiles / GLOBAL_DIR
        for f in sorted(gbase.rglob("*")) if gbase.is_dir() else []:
            if f.is_file():
                zf.write(f, f"profiles/{GLOBAL_DIR}/{f.relative_to(gbase).as_posix()}")
                count += 1
        if not (gbase / "band_set_01.xml").is_file():
            print(f"WARNING {gbase / 'band_set_01.xml'} missing: the global band set option will not work")

        info = efs_info(args.profiles)
        tag = efs_tag(args.profiles)
        if tag:
            info["tag"] = tag
        if info:
            prop = "".join(f"{k}={v}\n" for k, v in info.items())
            zi = zipfile.ZipInfo("profiles/info.prop")
            zi.compress_type = zipfile.ZIP_DEFLATED
            zi.external_attr = 0o644 << 16
            zf.writestr(zi, prop.encode("utf-8"))

    for m in eol_mismatches(args.profiles):
        print(f"WARNING line endings differ from the git repo: {m}")
    print(f"profiles: {count} files")
    print(f"efs info: {info or 'none (efs/info.json missing)'}")
    print(f"wrote {zip_path} ({zip_path.stat().st_size // 1024} KiB)")


if __name__ == "__main__":
    main()
