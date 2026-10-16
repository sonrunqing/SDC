# SDC 0.3.0

Godot 4.6.3 开发的安卓 ARM64 单机 PvE 2.5D 搜打撤原型。包含人物装备大厅、地图选择、出战整备、搜刮和撤离、仓库与商店，以及可实时显示独立枪体和配件的改枪界面。

## 手机上安装

下载 [Android APK（v0.3.0，约 52 MiB）](https://github.com/sonrunqing/SDC/releases/latest/download/SDC-v0.3.0.apk)。这是 Android 7.0+、ARM64 的调试签名安装包。下载完成后，在手机文件管理器中打开 APK 并允许安装此来源的应用。

该仓库是私人仓库，手机浏览器需要登录有权限的 GitHub 账号。若 GitHub App 内不能下载，请复制上面的地址到手机浏览器打开。

## 项目内容

- `src/`：完整 Godot 游戏项目，包括 GDScript、场景、数据、测试、模型、贴图、音效、字体和资源许可证。用 Godot 4.6.3 打开 `src/project.godot`。
- `previews/`：大厅、地图、商店、改枪、仓库和战局截图。
- `development/`：构建校验记录和工具版本清单。
- GitHub Release：SDC APK 安装包、可直接导入 Godot 的源码 ZIP 与界面演示视频。

游戏与玩法细节见 [`src/README.md`](src/README.md)，资产来源与授权见 [`src/THIRD_PARTY_ASSETS.md`](src/THIRD_PARTY_ASSETS.md)。

## 项目现状

这是离线单人开发原型。安卓真机帧率、触控手感和音频还没有实机验证；安装包使用调试签名。尚未实现多人服务器、账号和联网经济系统。
