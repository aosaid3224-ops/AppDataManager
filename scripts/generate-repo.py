#!/usr/bin/env python3
import os, sys, hashlib, subprocess, argparse

parser = argparse.ArgumentParser(description="Generate APT repository Packages/Release files")
parser.add_argument("repo_dir", nargs="?", default=".", help="Repository root directory")
parser.add_argument("--dev", action="store_true", help="Generate for dev repo (repo-dev)")
parser.add_argument("--prod", action="store_true", help="Generate for production repo (repo)")
args = parser.parse_args()

REPO_DIR = args.repo_dir
POOL_ROOT = os.path.join(REPO_DIR, "pool", "main")
POOL_ARCH_DIRS = [
    os.path.join(POOL_ROOT, "iphoneos-arm64"),
    os.path.join(POOL_ROOT, "iphoneos-arm64e"),
]

def hash_file(path, algo):
    h = hashlib.new(algo)
    with open(path, "rb") as f:
        while chunk := f.read(8192):
            h.update(chunk)
    return h.hexdigest()

def get_deb_info(deb_path):
    try:
        out = subprocess.check_output(["dpkg-deb", "-f", deb_path], text=True)
        return out
    except:
        return ""

def main():
    packages = []
    existing_dirs = [d for d in POOL_ARCH_DIRS if os.path.isdir(d)]
    if not existing_dirs:
        print(f"Pool dirs not found: {', '.join(POOL_ARCH_DIRS)}")
        return

    for pool_dir in existing_dirs:
        architecture_dir = os.path.basename(pool_dir)
        for fname in sorted(os.listdir(pool_dir)):
            if not fname.endswith(".deb"):
                continue
            fpath = os.path.join(pool_dir, fname)
            size = os.path.getsize(fpath)
            md5 = hash_file(fpath, "md5")
            sha1 = hash_file(fpath, "sha1")
            sha256 = hash_file(fpath, "sha256")
            info = get_deb_info(fpath)

            entry = info.strip()
            entry += f"\nFilename: pool/main/{architecture_dir}/{fname}\n"
            entry += f"Size: {size}\n"
            entry += f"MD5sum: {md5}\n"
            entry += f"SHA1: {sha1}\n"
            entry += f"SHA256: {sha256}\n"
            packages.append(entry)

    packages_text = "\n".join(packages) + "\n"

    with open(os.path.join(REPO_DIR, "Packages"), "w") as f:
        f.write(packages_text)
    with open(os.path.join(REPO_DIR, "Packages.gz"), "wb") as f:
        import gzip
        f.write(gzip.compress(packages_text.encode()))
    with open(os.path.join(REPO_DIR, "Packages.bz2"), "wb") as f:
        import bz2
        f.write(bz2.compress(packages_text.encode()))
    with open(os.path.join(REPO_DIR, "Packages.xz"), "wb") as f:
        import lzma
        f.write(lzma.compress(packages_text.encode()))

    # Generate Release file with proper hashes
    pkg_size = len(packages_text.encode("utf-8"))
    pkg_md5 = hashlib.md5(packages_text.encode()).hexdigest()
    pkg_sha1 = hashlib.sha1(packages_text.encode()).hexdigest()
    pkg_sha256 = hashlib.sha256(packages_text.encode()).hexdigest()

    gz_data = gzip.compress(packages_text.encode())
    gz_size = len(gz_data)
    gz_md5 = hashlib.md5(gz_data).hexdigest()
    gz_sha1 = hashlib.sha1(gz_data).hexdigest()
    gz_sha256 = hashlib.sha256(gz_data).hexdigest()

    bz2_data = bz2.compress(packages_text.encode())
    bz2_size = len(bz2_data)
    bz2_md5 = hashlib.md5(bz2_data).hexdigest()
    bz2_sha1 = hashlib.sha1(bz2_data).hexdigest()
    bz2_sha256 = hashlib.sha256(bz2_data).hexdigest()

    xz_data = lzma.compress(packages_text.encode())
    xz_size = len(xz_data)
    xz_md5 = hashlib.md5(xz_data).hexdigest()
    xz_sha1 = hashlib.sha1(xz_data).hexdigest()
    xz_sha256 = hashlib.sha256(xz_data).hexdigest()

    if args.dev:
        origin = "A-ZAIN Dev Repo"
        label = "A-ZAIN Development"
        codename = "ios-dev"
        description = "A-ZAIN Development Repo - Private testing channel"
    else:
        origin = "A-ZAIN Repo"
        label = "A-ZAIN"
        codename = "ios"
        description = "A-ZAIN Repo - Jailbreak tools and utilities"

    release_lines = [
        f"Origin: {origin}",
        f"Label: {label}",
        "Suite: stable",
        "Version: 1.0",
        f"Codename: {codename}",
        "Architectures: iphoneos-arm64 iphoneos-arm64e",
        "Components: main",
        f"Description: {description}",
        "",
        "MD5Sum:",
        f" {pkg_md5} {pkg_size} Packages",
        f" {gz_md5} {gz_size} Packages.gz",
        f" {bz2_md5} {bz2_size} Packages.bz2",
        f" {xz_md5} {xz_size} Packages.xz",
        "",
        "SHA1:",
        f" {pkg_sha1} {pkg_size} Packages",
        f" {gz_sha1} {gz_size} Packages.gz",
        f" {bz2_sha1} {bz2_size} Packages.bz2",
        f" {xz_sha1} {xz_size} Packages.xz",
        "",
        "SHA256:",
        f" {pkg_sha256} {pkg_size} Packages",
        f" {gz_sha256} {gz_size} Packages.gz",
        f" {bz2_sha256} {bz2_size} Packages.bz2",
        f" {xz_sha256} {xz_size} Packages.xz",
    ]

    with open(os.path.join(REPO_DIR, "Release"), "w") as f:
        f.write("\n".join(release_lines) + "\n")

    print(f"Generated Packages for {len(packages)} packages ({'dev' if args.dev else 'production'})")

if __name__ == "__main__":
    main()
