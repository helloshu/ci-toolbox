# 许可与修改声明 / Licensing and modification notice

本仓库**不含**任何上游源码的副本，只包含补丁（diff）、构建流水线与构建脚本。
每次构建立即从上游按固定提交拉取源码，在临时目录打补丁后编译。

This repository contains no copy of the upstream sources: only patches, build
workflows and helper scripts. Every build clones the pinned upstream commit,
applies the patches in a temporary directory, and compiles that tree.

---

## Cryptomator (android / ios)

- 上游：https://github.com/cryptomator/android 、 https://github.com/cryptomator/ios
- 许可：GNU General Public License v3.0（见上游 `LICENSE.txt`）
- 修改：本项目仅做最小改动以致能既有 Pro 功能可用，改动点见 `targets/b/patches/`、
  `targets/c/patches/`
- GPLv3 §6 对应源码：每个 Release 附 `targets/b-source.tar.gz` /
  `targets/c-source.tar.gz`，即本次二进制对应的完整打补丁源码树
- 未使用 Cryptomator 的商标、图标或发布签名；产物并非上游官方发布，作者与上游项目无关

Modifications, not upstream releases: binaries here are built from the pinned
upstream commits with the patches in this repository, are signed with
self-signed certificates, and carry the corresponding source next to them.

## Keyguard

- 上游：https://github.com/AChep/a-app
- 许可：`All Rights Reserved`；上游 README：「The source code is available for
  **personal use** only.」
- 因此：本项目的 Keyguard 流水线仅用于**仓库所有者个人设备**，仓库需保持私有，
  产物不得公开分发、不得再发布
- 修改：`targets/a/patches/0001-pro-unlock.patch`（授权判定）、
  `0002-no-telemetry.patch`（移除 Firebase Analytics/Crashlytics 与相关插件）

This build is for the repository owner's personal use only. Do not redistribute
the Keyguard artifacts.

---

## Third-party components

两个应用都会在构建时拉取大量第三方依赖（AndroidX、Compose、Kotlin、Rust crates 等），
各自许可见构建产物内的 `META-INF` 与上游 `LICENSE` 文件。
