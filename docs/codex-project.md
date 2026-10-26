# 这个项目：BaoCode Codex

这个仓库**只做 codex 那个产品**（`baocode-codex.exe`，显示名 BaoCode Codex）。
它在 GitHub 上单独一个仓库：**https://github.com/poying2018/baocode-codex**（公开），
默认分支 `main`；origin 指它，upstream 仍指官方 `baocode-dev/baocode`（只 fetch）。
本地是 `F:\Projects\baocode-codex`，从 `F:\Projects\baocode`（BaoCode Claude）分出来的
**独立项目**：自己的 `.git`、自己的分支、自己的构建目录，两边的开发互不打扰。

## 为什么分开

一份源码出两个产品的时候，两边在**同一棵工作树**里开发会互相踩：

- 产品名是 `windows/CMakeLists.txt` 里的一行 `set(BINARY_NAME ...)`，两个人各建各的就会互相改；
- `build/` 是共享的，一边构建时另一边在跑应用会锁住 DLL；
- 同一个分支上，两边的提交交织在一起，发版时难以分清哪些是哪个产品的。

所以：**BaoCode Claude 留在 `F:\Projects\baocode`，BaoCode Codex 在这里。**

## 两个项目的关系

| | `F:\Projects\baocode` | 这里 |
| --- | --- | --- |
| 产品 | BaoCode Claude（`baocode-claude.exe`） | BaoCode Codex（`baocode-codex.exe`） |
| GitHub | `poying2018/baocode`（他们的） | **`poying2018/baocode-codex`**（自己的） |
| 分支 | 他们自己的（`main` / `dev` / `feature/codex-kernel`） | `main` |
| 默认构建的产品 | `baocode-claude` | `baocode-codex`（这个仓库里就一直是这样） |
| 更新通道 | 本仓库 release 的 `latest.json` | **本仓库 release 的 `latest-codex.json`** |

两边**共享历史**：这里是从原仓库的 `feature/codex-kernel` 克隆出来的，
所以上游（`baocode-dev/baocode`）的同步、以及原项目里跟两个产品都有关的修复，
都可以按下面的办法拿过来。

## 内置的 Codex CLI

这个产品**自带 Codex CLI**：安装包里带着它，用户不用装、不用下，第一次对话就能用
（和 BaoCode Claude 自带 Claude Code 是一个道理）。

- 包里放哪：`codex-cli\`（挨着 `baocode-codex.exe`），里面是平台 npm 包的原样布局
  `vendor\x86_64-pc-windows-msvc\{bin\codex.exe, codex-resources\, codex-path\}`——
  程序按相对位置找它自己的资源，布局不能改。
- 谁放进去的：`tool/build_windows.dart` 的 `_putCodex()`。版本与校验值钉在脚本顶部
  （`_codexVersion` / `_codexIntegrity`）：

  ```dart
  const _codexVersion = '0.164.0';
  const _codexPlatform = 'win32-x64';
  const _codexIntegrity = 'sha512-urWPhwh9…hDg==';   // registry 的 dist.integrity
  const _codexUrl = 'https://registry.npmjs.org/@openai/codex/-/codex-$_codexVersion-$_codexPlatform.tgz';
  ```

  下载一次缓存在 `build\codex\`，以后离线构建也能用；换版本时改这三行——
  或者让工具改：`dart tool/bump_codex_version.dart`（说现状，落后时退出码 1）、
  `--write`（写进去）。它读的是 npm registry 的 `dist.integrity`，**不用下载 165 MB**
  就知道校验值；`.github/workflows/codex-version.yml` 每天跑一次并自动提交
  `ci(codex): bump the Codex CLI to <版本>`，发版时的 `check` 再跑一遍兜底
  （落后就发不下去）。
- 应用怎么找到它：`ProcessCodexTransport.locateCodex()` 的顺序是
  **`BAOCODE_CODEX_COMMAND`（环境里指定的）→ 用户自己装的（PATH / npm 全局 / Codex Desktop）
  → 包里带的**。包里那份是「地板」：用户有自己的就用用户的（可能更新、已登录）。
- 想确认当前会用哪一份：

  ```powershell
  dart tool/check_codex_bundle.dart                                  # 这个仓库自己的
  dart tool/check_codex_bundle.dart build\windows\x64\runner\Release\baocode-codex.exe
  ```

  它会说：包里带的在哪、能不能报版本、最终会跑哪一个。
- 装上之后 `codex-cli\` 在 Program Files 里（只读没问题，是可执行文件），
  状态（会话、登录）仍然写用户的数据目录 `%APPDATA%\baocode-codex\codex\`。


```powershell
# 会话环境（和原项目一样：Flutter 3.47.5、共享的 pub 缓存、工作区内的临时目录）
$env:PATH='F:\Projects\tools\flutter\bin;'+$env:PATH
$env:PUB_CACHE='F:\Projects\pub-cache'
$env:APPDATA='F:\Projects\tmp\appdata2'
$env:LOCALAPPDATA='F:\Projects\tmp\localappdata'
$env:TEMP='F:\Projects\tmp'; $env:TMP='F:\Projects\tmp'
$env:ANDROID_HOME='F:\Projects\tmp\android-sdk'   # 有这个目录，flutter 才不去 where aapt
$env:NO_PROXY='*'
cd F:\Projects\baocode-codex
```

- **构建**：`build_codex.cmd`（先 `tool/set_product.dart codex`，再 `flutter build windows --release`）。
  产物在 `build\windows\x64\runner\Release\baocode-codex.exe`。
- **整套发行包**：`dart run tool/build_windows.dart --product codex`（要 Inno Setup 和网络，
  见 §「本机限制」）。
- **跑起来**：直接运行上面的 exe；**开发时要给数据目录**（否则会写 `%APPDATA%\baocode-codex`）：

  ```powershell
  $env:BAOCODE_DATA_DIR = 'F:\Projects\tmp\codex-run'   # 这个文件夹要先存在
  ```

- **测试**（只跑跟改动相关的）：

  ```powershell
  flutter test test\kernel_test.dart test\kernel\codex_kernel_test.dart
  flutter test test\codex_stub_test.dart           # 对着真进程跑一整轮
  flutter test test\settings\product_table_test.dart
  flutter test test\stash
  ```

## 更新链

应用从本仓库的 release 取自己的下一版：

```
https://github.com/poying2018/baocode-codex/releases/latest/download/latest-codex.json
```

- 清单是**签名**的（Ed25519；公钥钉在 `lib/update/update_signature.dart`，私钥只在 CI 的
  `BAOCODE_UPDATE_SIGNING_KEY` Secret 里）。签名覆盖 version、platform、size、sha256。
- 每个产品一份清单（这个是 `latest-codex.json`，兄弟产品是 `latest.json`），
  清单里 `product` 不写算 BaoCode 的 ⇒ 这个产品只收自己的。
- **仓库必须是公开的**：应用是**匿名**取清单和安装包的，私有仓库的 release 资产匿名 404
  （2026-10-26 因为这个把仓库从私有改成公开）。
- 发版流程：`dart run tool/bump_version.dart <版本>` → 写 `release-notes/<版本>.{en,zh}.md`
  → 提交 → `git tag v<版本> && git push origin v<版本>` → CI 构建四平台远端服务器 +
  Windows 安装包 → 签名 `latest-codex.json` → 建 release → **最后跑一遍链条检查**。
- 查链条（随时可跑，也进 CI 的发布末尾）：

  ```powershell
  dart run tool/check_update_chain.dart                    # 这个产品、当前版本、windows-x64
  dart run tool/check_update_chain.dart --version 1.6.0+18  # 「装的是旧版会不会被提示」
  ```

  它按应用的方式做：匿名抓清单、用应用自己的解析器、URL 白名单和钉住的公钥验签；
  任何一环断了就以退出码 1 说明原因。

## 从原项目拿东西过来

```powershell
# 一次性：把原项目加成一个远程
git remote add claude F:\Projects\baocode

git fetch claude
git log --oneline claude/feature/codex-kernel ^codex-product   # 那边有什么这边没有
git cherry-pick <提交>            # 只拿跟两个产品都有关的修复
git merge claude/feature/codex-kernel   # 或者整条合并（要解冲突）
```

**只拿「两个产品都成立」的改动**：协议、内核、通用 UI、构建脚本的共性部分。
不要拿他们的产品身份改动（名字、安装包、发布链）——那是 BaoCode Claude 的。

同步上游（官方 `baocode-dev/baocode`）和原项目一样：

```powershell
git fetch upstream --no-tags
git fetch upstream 'refs/tags/v*:refs/tags/upstream/v*'
git merge upstream/main --no-edit
```

## 本机限制（2026-10-26 实测）

- **没有 Codex CLI**、**没有网络**：打不了真的 Codex（`codex app-server`）。
  协议对不对，靠 `tool/codex_stub.dart`（照着协议说话的假服务器）验证。
  想用真的：装 `npm install -g @openai/codex`，或用
  `$env:BAOCODE_CODEX_COMMAND = 'dart F:\Projects\baocode-codex\tool\codex_stub.dart'`
  先跑假的那份。
- **Inno Setup 装不上**（离线安装包在本机起不来）：安装包只能在 CI 上出
  （`release.yml` 里 `choco install innosetup`）。
- **远端服务器的 Linux 版编不了**：`dart compile exe --target-os linux` 要联网下载
  AOT 运行时。CI 上有。
- **沙箱**：从 DSH 里起的应用写不了工作区以外的地方（`%APPDATA%`、`~\.codex` 会 errno 5），
  所以开发跑应用时把 `BAOCODE_DATA_DIR` 指到工作区里。

## 文档

- `docs/codex-kernel.md`：**内核开发读本**（协议契约、能力矩阵、陷阱）。
- `docs/claude-code-kernel.md`：另一个产品的内核读本（两个产品共用框架，对照着看）。
- `docs/release.md` §4.1：一次发版、两个产品。
- `F:\Projects\_baocode开发上下文.md`：整个工作区的开发上下文（含这个项目的来龙去脉）。
