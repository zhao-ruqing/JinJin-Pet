# 进进宠物（Jinjin Pet）

一个轻量级 Windows 桌面宠物，基于提供的角色素材构建，以透明置顶窗口悬浮在桌面上。

## 环境要求

- Windows 10 / Windows 11
- PowerShell 5.1 或更高版本
- 如需重新构建精灵图，需要 Python 3.9+ 及依赖库

## 快速开始

### 1. 安装 Python 依赖（仅构建精灵图时需要）

```powershell
pip install -r requirements.txt
```

### 2. 启动宠物

双击 `Start Jinjin Pet.cmd`，或在终端中运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Start-JinjinPet.ps1
```

### 3. 停止宠物

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Stop-JinjinPet.ps1
```

## 操作说明

| 操作 | 效果 |
|---|---|
| 鼠标左键拖拽 | 移动宠物位置 |
| 鼠标滚轮 | 缩放宠物大小 |
| 右键点击 | 打开菜单（切换状态、大小、开关自动动作、退出） |

## 自动动作

当自动动作开启时，宠物会根据当前前台窗口自动切换状态：

| 前台窗口 | 宠物状态 |
|---|---|
| 鼠标悬停在宠物上 | `happy-wave`（开心挥手） |
| 按下 Delete 键 | `surprised`（惊讶，持续约 0.85 秒） |
| 鼠标静止约 2 秒 | `sleepy`（犯困） |
| 编程工具 / 终端 | `coding`（写代码） |
| 审查 / 调试 / 聊天 / 浏览器 | `thinking`（思考中） |
| 其他窗口 | `idle`（待机） |

## 开机自启

```powershell
# 添加开机自启
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-Autostart.ps1

# 移除开机自启
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall-Autostart.ps1
```

## 创建桌面快捷方式

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Create-DesktopShortcut.ps1
```

## 文件说明

| 文件 | 说明 |
|---|---|
| `JinjinPet.ps1` | 主脚本，启动透明置顶宠物窗口 |
| `Start-JinjinPet.ps1` | 后台启动一个宠物实例 |
| `Stop-JinjinPet.ps1` | 停止所有宠物进程 |
| `Install-Autostart.ps1` | 添加开机自启快捷方式 |
| `Uninstall-Autostart.ps1` | 移除开机自启快捷方式 |
| `Create-DesktopShortcut.ps1` | 在桌面创建启动快捷方式 |
| `build_pet_from_sources.py` | 从源图片重新构建 `spritesheet.png` |
| `import_incoming_images.ps1` | 导入新素材图片并重新构建精灵图 |
| `pet.json` | 宠物元数据清单 |
| `pet-config.json` | 运行时配置（自动生成，包含窗口位置、大小等） |
| `incoming/` | 待导入的新素材图片目录 |
| `pet-build/` | 构建输出目录（cutouts 预览等） |

## 在其他电脑上使用

1. Clone 本项目到本地
2. 安装 Python 依赖：`pip install -r requirements.txt`
3. 直接运行 `Start-JinjinPet.ps1` 即可

所有路径均为脚本所在目录的相对路径，无需额外配置。
