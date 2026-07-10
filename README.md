# 进进宠物

桌面宠物，透明置顶悬浮，右键菜单切换状态。

## 启动

双击 `Start Jinjin Pet.cmd`，或者：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Start-JinjinPet.ps1
```

## 停止

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Stop-JinjinPet.ps1
```

## 操作

- 左键拖拽移动，滚轮缩放，右键打开菜单
- 自动动作开启时，会根据前台窗口自动切换状态（编程工具 → coding，浏览器/聊天 → thinking，其他 → idle）
- 鼠标悬停 → happy-wave，按下 Backspace → surprised，鼠标静止 2 秒 → sleepy

## 开机自启

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-Autostart.ps1     # 添加
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall-Autostart.ps1   # 移除
```

## 工作日 17:58 自动打开 Codex++

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-CodexSchedule.ps1     # 添加
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall-CodexSchedule.ps1   # 移除
```

程序路径默认为 `D:\ALL-APP\codex++\codex-plus-plus.exe`，如需修改请编辑 `Install-CodexSchedule.ps1` 顶部的 `$CodexExe` 和 `Start-CodexPlusPlus.vbs`。

## 换电脑 clone 后

```powershell
pip install -r requirements.txt   # 仅构建精灵图时需要
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Start-JinjinPet.ps1
```

所有路径相对脚本所在目录，无需额外配置。
