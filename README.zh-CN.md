[繁體中文](README.md) | [简体中文](README.zh-CN.md) | [English](README.en.md)

# ShiftInput

ShiftInput 是一个原生、轻量且事件驱动的 macOS 输入法切换增强工具。它在后台运行，默认显示于菜单栏且不显示于 Dock。

## 功能

### Shift 输入法切换

- 单独点按 `Shift`，从当前输入法切换到最近使用的英文输入法。
- 已在英文输入法时，再次点按 `Shift` 会返回上次使用的输入法。
- 返回 Apple 拼音时会等待并确认拼音键盘布局已启用；如果 macOS 尚未完成切换，会自动重试，避免显示为拼音却只能输入英文。
- 切换后显示 macOS 风格的输入来源提示。
- Shift 用于输入大写字母、组合快捷键、Shift 点击或 Shift 滚动时不会误触发。

### Shift + Space 拼音全／半形切换

- 在 Apple 拼音输入法中按 `Shift + Space`，切换系统全形／半形标点模式。
- 不显示切换提示。
- 支持 Apple 拼音－繁体和拼音－简体。
- **不应用于 Apple 注音输入法**；在注音或其他输入法中，`Shift + Space` 会原样传给当前应用。

以上两项功能可以在设置中分别启用或停用。

## 其他设置

- 显示菜单栏图标，默认开启。
- 显示 Dock 图标，默认关闭。
- 如果同时隐藏两个图标，再次从 Finder 打开 ShiftInput 即可返回设置。

## 系统要求与权限

- macOS 13 或以上。
- “系统设置 → 隐私与安全性 → 辅助功能”。
- “系统设置 → 隐私与安全性 → 输入监控”。

首次启动会显示设置窗口与权限状态。如果重新构建了 ad-hoc 签名的应用，macOS 可能要求重新授权。

## 本地构建

需要 Apple Swift 工具链；也可以直接使用 Xcode 打开 `Package.swift`。

```bash
# 纯 Swift 状态机与输入来源识别检查
make test

# 创建 dist/ShiftInput.app
make app

# 创建 dist/ShiftInput-0.2.1.dmg
make dmg
```

创建同时支持 Apple Silicon 和 Intel 的 Universal Binary：

```bash
BUILD_ARCHS="arm64 x86_64" VERSION=0.2.1 make dmg
```

其他可用参数：

```bash
VERSION=0.2.1 BUILD_NUMBER=2 CONFIGURATION=release make app
```

运行完整验证：

```bash
make verify
```

## 安装 DMG

1. 打开 `dist/ShiftInput-<版本>.dmg`。
2. 将 `ShiftInput.app` 拖入映像中的 `Applications` 快捷方式。
3. 从“应用程序”启动 ShiftInput。
4. 按照设置窗口指示授予两项键盘权限。

## GitHub Actions

`.github/workflows/build-dmg.yml` 会在以下情况运行：

- 推送到 `main`。
- 创建 Pull Request。
- 手动运行 workflow。

流程会执行检查、创建 `arm64 + x86_64` Universal Binary、封装 DMG、验证磁盘映像，最后作为 GitHub Actions artifact 上传。

要发布新版本，请修改根目录 `VERSION` 中的语义化版本号（例如 `0.3.0`），提交并推送到 `main`。构建成功后，workflow 会自动创建对应的 `v0.3.0` 标签和 GitHub Release、附上 DMG，并在 Release 说明中列出自上一个版本以来的所有 commits。已存在的版本标签不会被覆盖。

## 技术设计

- Swift、AppKit、Core Graphics、Text Input Source Services。
- `CGEventTap` 只处理必要的键盘和指针事件。
- 事件监听范围会根据已启用的快捷键调整；未启用 Shift 切换时不监听鼠标和滚动事件。
- 使用系统输入来源通知，不持续轮询输入法状态。
- 每次输入来源通知只读取一次系统快照，并一致地更新保存来源、拼音能力和界面。
- 使用 `TISSelectInputSource` 切换输入法并保存上次来源；切换后会确认实际来源，Apple 拼音也会确认其键盘布局并在需要时重试。
- `Shift + Space` 仅在识别为 Apple 拼音时转发为原生 `Option + Shift + H` 命令。
- Event tap 超时停用时会自动恢复；权限被撤销时会停止监听。
- 快捷键设置改变或 event tap 被系统停用时，监听器会使用最新设置安全重建。

## 项目结构

```text
.github/workflows/build-dmg.yml  GitHub Actions DMG 构建
VERSION                          应用程序与 Release 版本号
Sources/ShiftInputCore/          可测试的纯 Swift 逻辑
Sources/ShiftInput/              AppKit 应用与系统集成
Resources/AppIcon.png            应用图标 1024px 主图
Scripts/build-app.sh             .app 构建脚本
Scripts/generate-app-icon.sh     ICNS 图标尺寸集生成脚本
Scripts/create-dmg.sh            DMG 打包脚本
Scripts/smoke-test-app.sh        应用生命周期与菜单栏检查
Scripts/StateMachineChecks.swift 状态机与拼音识别检查
Makefile
Package.swift
```
