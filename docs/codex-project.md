# 这个项目：BaoCode Codex

这个仓库**只做 codex 那个产品**（`baocode-codex.exe`，显示名 BaoCode Codex）。
它是从 `F:\Projects\baocode`（BaoCode Claude，即原来的 BaoCode 项目）分出来的**独立项目**：
自己的 `.git`、自己的分支、自己的构建目录，两边的开发互不打扰。

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
| 分支 | 他们自己的（`main` / `dev` / `feature/codex-kernel`） | `codex-product` |
| 默认构建的产品 | `baocode-claude` | `baocode-codex`（这个仓库里就一直是这样） |

两边**共享历史**：这里是从原仓库的 `feature/codex-kernel` 克隆出来的，
所以上游（`baocode-dev/baocode`）的同步、以及原项目里跟两个产品都有关的修复，
都可以按下面的办法拿过来。

## 构建、运行、测试

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
