# PV - 图片浏览器

一个简洁的macOS图片浏览器，支持网格浏览和单图查看。

## 功能

- � 网格浏览图片缩略图
- 🖼️ 单图模式查看大图
- ⌨️ 键盘方向键导航
- 🔄 自动播放幻灯片
- 📁 支持文件夹浏览
- 🗑️ 删除图片（移到废纸篓）
- ⚡ 快速流畅的切换

## 安装

```bash
# 一键构建
./build_pv_app.sh

# 快速构建（开发用）
./build_pv_app.sh -q

# 安装到应用文件夹
cp -R release/PV.app /Applications/
```

## 使用

1. 打开应用，点击"打开..."选择图片文件夹
2. 双击图片进入单图模式
3. 使用方向键或点击切换图片
4. 按ESC返回网格视图

### 快捷键
- `⌘O` - 打开文件夹
- `→←` - 切换图片
- `空格` - 自动播放
- `⌫` - 删除图片
- `ESC` - 退出单图

## 命令行

```bash
# 打开文件夹
PV ~/Pictures

# 打开单张图片
PV image.jpg
```

## 构建

需要macOS 12.0+，支持Intel和M1/M2芯片。

```bash
swift build -c release
```

## 文件说明

- `PVApp.swift` - 应用主入口
- `ImageBrowserViewModel.swift` - 图片浏览逻辑
- `ListView.swift` - 网格视图
- `SingleImageView.swift` - 单图视图
- `build_pv_app.sh` - 构建脚本

