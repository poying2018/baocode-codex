# BaoCode Codex 的版本与发布

这个仓库怎么发一个版本：版本号从哪来、打什么标签、CI 做什么、发布到哪里、
发完要核对什么。应用这一侧怎么检查、下载、校验、安装，见
[auto-update.md](auto-update.md)；上游 BaoCode 的完整流程（R2、macOS 公证、
Linux 包）见 [release.md](release.md)，本仓库不跑那些。

## 1. 全貌

```
git tag v1.7.3 && git push origin v1.7.3
        │
        ▼
GitHub Actions（.github/workflows/release.yml，约 15-25 分钟）
  check     pubspec.yaml == lib/update/version.dart；标签 == v<版本>；
            不比已发布的旧；dart tool/bump_codex_version.dart（落后即失败）
  test      flutter test（全部测试，构建之前先跑）
  analyze   flutter analyze
  remote    macOS 上编出四平台的远端服务器（Codex 服务器按源码定版本），
            Linux 容器里把 linux 两份真跑一遍
  windows   flutter build windows --release + 内置 Codex CLI（tool/build_windows.dart）
            + Inno Setup 打包（tool/baocode.iss）
  publish   签名 latest-codex.json → 建 release → 传安装包/服务器/清单
            → dart run tool/check_update_chain.dart（发布后从应用视角再查一遍）
        │
        ▼
https://github.com/poying2018/baocode-codex/releases/tag/v<x.y.z>
  BaoCodeCodex-<版本>-setup.exe      应用 + 内置的 Codex CLI
  baocode-codex-server-*.gz          四平台的远端服务器
  servers-codex.json / remote-latest.json
  latest-codex.json                  签名的更新清单（最后上传）
```

浏览器扩展是另一条流水线（`extension.yml`），发到自己的 release（tag `extension`），
见 [extensions.md](extensions.md) 与下文第 4 节。

## 2. 版本号

`x.y.z+build`，两处一致（`test/update/version_test.dart` 守着）：
`pubspec.yaml` 的 `version:` 与 `lib/update/version.dart` 的 `appVersionString`。
build 号只增不减：应用按它判断有没有新版本（docs/auto-update.md）。

```powershell
dart run tool/bump_version.dart 1.7.4     # 或 patch / minor / major
```

它同时起草 `release-notes/<版本>.{en,zh}.md`（从提交生成）——**重写成给用户看的**，
那也是更新通知和站点 changelog 的内容：

```powershell
dart run tool/build_changelog.dart        # 把 release-notes 生成 site/changelog.html（中英）
```

## 3. 发一个版本

```powershell
dart run tool/bump_version.dart <版本>     # 版本号 + 起草发布说明
# 重写 release-notes/<版本>.{en,zh}.md
dart run tool/build_changelog.dart         # 站点的更新日志
git add -A && git commit -m "release: <版本>, 一句话"
git push origin main
git tag v<版本> && git push origin v<版本>   # CI 接手
```

**推 tag 前先看它指向哪**：这个仓库是从上游克隆来的，会带着上游的旧 tag
（v1.6.1、extension-v0.1.0 都踩过）。`git tag -l` + `git rev-list -n1 <tag>`
核对是自己的提交再推。

## 4. CI 之外的两条流水线

| 工作流 | 触发 | 做什么 |
|---|---|---|
| `codex-version.yml` | 每天 04:23 UTC | Codex CLI 出新版就 bump `tool/build_windows.dart` 的 pin（版本 + registry 的 sha512），自动提交 |
| `update-chain.yml` | 每天 06:03 UTC | 匿名读 latest-codex.json、验签名、说各版本会被提示什么。release 被删/仓库转私有/地址被挪，第二天就是红色 run |
| `extension.yml` | tag `extension-*` | 打包浏览器扩展，发到 release `extension`（manifest、zip、store zip） |
| `remote.yml` | tag `server-*` | 手动发远端服务器的构建（一般由 Release 调用） |

其余（Extension 的 pull_request、Mobile、Sign release manifest）已禁用：
Mobile 不在本产品；签名在 release.yml 里做。

## 5. 发完核对什么

```powershell
# 清单与签名（应用的方式：匿名读、本仓库的公钥验）
dart run tool/check_update_chain.dart --version <上一版>+<上一build>
#   ⇒  "an app at <上一版> is offered <这一版>"  且 the chain is whole

# 每个资产的尺寸对得上清单
gh release view v<版本> --repo poying2018/baocode-codex --json assets

# 站点
#   changelog 有这个版本（site/changelog.html 已推 main）
#   下载按钮指向 releases/latest（本仓库）
```

## 6. 本机装与升级

安装包双击即可（`PrivilegesRequired=lowest`，不需要管理员；开始菜单/右键菜单/
浏览器宿主/卸载项都写 HKCU）。安装器对写不了的项会跳过而不是回滚——
`/LOG=<文件>` 能看到它跳过了什么。

装完核对：

```powershell
D:\BaoCodeCodex\self-check.cmd      # 应用/CLI/宿主/scheme/菜单/卸载项逐项 OK
dart tool/check_codex_bundle.dart "D:\BaoCodeCodex\baocode-codex.exe"
```

## 7. 出了问题

| 症状 | 原因 |
|---|---|
| CI 的 Test 挂了 | 先修测试再发版（test-before-build 是门禁） |
| `Unknown constant "3c9e…"`（ISCC） | AppId 的花括号没转义——构建时已把 `{` 加倍，见 tool/build_windows.dart |
| 发布的清单 404 | 仓库转私有会让匿名清单 404，自动更新随之失效 |
| `BROKEN: the signature does not verify` | 签名密钥不对：Secret `BAOCODE_UPDATE_SIGNING_KEY` |
| 远端服务器找不到文件 | 文件名按产品走（`baocode-codex-server-*`），测试脚本按 `*server-<平台>` 找 |
