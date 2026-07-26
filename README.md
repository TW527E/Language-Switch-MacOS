[繁體中文](README.md) | [简体中文](README.zh-CN.md) | [English](README.en.md)

# ShiftInput

ShiftInput 是一個原生、輕量且事件驅動的 macOS 輸入法切換增強工具。它在背景執行，預設顯示於選單列且不顯示於 Dock。

## 功能

### Shift 輸入法切換

- 單獨點按 `Shift`，從目前輸入法切換到最近使用的英文輸入法。
- 已在英文輸入法時，再次點按 `Shift` 會返回上次使用的輸入法。
- 切換後顯示 macOS 風格的輸入來源提示。
- Shift 用於輸入大寫字母、組合快捷鍵、Shift 點擊或 Shift 捲動時不會誤觸發。

### Shift + Space 拼音全／半形切換

- 在 Apple 拼音輸入法中按 `Shift + Space`，切換系統全形／半形標點模式。
- 不顯示切換提示。
- 支援 Apple 拼音－繁體與拼音－簡體。
- **不套用於 Apple 注音輸入法**；在注音或其他輸入法中，`Shift + Space` 會原樣傳給目前應用。

以上兩項功能可在設定中分別啟用或停用。

## 其他設定

- 顯示選單列圖標，預設開啟。
- 顯示 Dock 圖標，預設關閉。
- 若同時隱藏兩個圖標，再次從 Finder 開啟 ShiftInput 即可回到設定。

## 系統要求與權限

- macOS 13 或以上。
- 「系統設定 → 隱私權與安全性 → 輔助使用」。
- 「系統設定 → 隱私權與安全性 → 輸入監控」。

首次啟動會顯示設定窗口與權限狀態。若重新建置了 ad-hoc 簽署的應用，macOS 可能要求重新授權。

## 本機建置

需要 Apple Swift 工具鏈；也可以直接使用 Xcode 開啟 `Package.swift`。

```bash
# 純 Swift 狀態機與輸入來源辨識檢查
make test

# 建立 dist/ShiftInput.app
make app

# 建立 dist/ShiftInput-0.2.0.dmg
make dmg
```

建立同時支援 Apple Silicon 與 Intel 的 Universal Binary：

```bash
BUILD_ARCHS="arm64 x86_64" VERSION=0.2.0 make dmg
```

其他可用參數：

```bash
VERSION=0.2.0 BUILD_NUMBER=2 CONFIGURATION=release make app
```

執行完整驗證：

```bash
make verify
```

## 安裝 DMG

1. 開啟 `dist/ShiftInput-<版本>.dmg`。
2. 將 `ShiftInput.app` 拖入映像檔內的 `Applications` 捷徑。
3. 從「應用程式」啟動 ShiftInput。
4. 依設定窗口指示授予兩項鍵盤權限。

## GitHub Actions

`.github/workflows/build-dmg.yml` 會在以下情況執行：

- 推送到 `main`。
- 建立 Pull Request。
- 手動執行 workflow。

流程會執行檢查、建立 `arm64 + x86_64` Universal Binary、封裝 DMG、驗證映像檔，最後以 GitHub Actions artifact 上傳。

要發布新版本，請修改根目錄 `VERSION` 內的語意化版本號（例如 `0.3.0`），提交並推送至 `main`。建置成功後，workflow 會自動建立對應的 `v0.3.0` 標籤與 GitHub Release、附上 DMG，並在 Release 說明列出自上一個版本以來的所有 commits。已存在的版本標籤不會被覆寫。

## 技術設計

- Swift、AppKit、Core Graphics、Text Input Source Services。
- `CGEventTap` 僅處理必要的鍵盤與指標事件。
- 使用系統輸入來源通知，不持續輪詢輸入法狀態。
- 使用 `TISSelectInputSource` 切換輸入法並保存上次來源。
- `Shift + Space` 僅在辨識為 Apple 拼音時轉送為原生 `Option + Shift + H` 命令。
- Event tap 逾時停用時會自動恢復；權限被撤銷時會停止監聽。

## 專案結構

```text
.github/workflows/build-dmg.yml  GitHub Actions DMG 建置
VERSION                          應用程式與 Release 版本號
Sources/ShiftInputCore/          可測試的純 Swift 邏輯
Sources/ShiftInput/              AppKit 應用與系統整合
Resources/AppIcon.png            應用圖標 1024px 主圖
Scripts/build-app.sh             .app 建置腳本
Scripts/generate-app-icon.sh     ICNS 圖標尺寸集產生腳本
Scripts/create-dmg.sh            DMG 封裝腳本
Scripts/smoke-test-app.sh        應用生命週期與選單列檢查
Scripts/StateMachineChecks.swift 狀態機與拼音辨識檢查
Makefile
Package.swift
```
