# SDC 0.4.14

Godot 4.6.3 / GDScript 开发的 Android ARM64 单机 PvE 2.5D 搜打撤原型。

## 下载手机版

**[下载 SDC 0.4.14 APK](https://github.com/sonrunqing/SDC/releases/download/v0.4.14/SDC-v0.4.14.apk)**（约93.3 MiB）

[最新发布页](https://github.com/sonrunqing/SDC/releases/latest) · [0.4.14 更新说明与源码压缩包](https://github.com/sonrunqing/SDC/releases/tag/v0.4.14)

当前版本为 **0.4.14 / versionCode 21**。仓库已公开，下载和读取源码无需登录。
包名保持 `org.prototype.shooter25d`，签名沿用0.4.3起的固定身份；后续同一固定签名版本之间覆盖升级。
历史云端0.3.0是另一签名，仅作为旧版本保留，不能直接覆盖升级。

## 最新游戏代码与 AI 入口

**完整游戏工程在 [fix-game-bugs 分支](https://github.com/sonrunqing/SDC/tree/fix-game-bugs)**，
[代码审查 PR #1](https://github.com/sonrunqing/SDC/pull/1)保持打开。
此 main 页面提供下载与项目入口；读取、开发或审查当前游戏请使用上述工作分支。

```sh
git clone --branch fix-game-bugs https://github.com/sonrunqing/SDC.git
```

用Godot 4.6.3打开 `SDC/project.godot`。审查先读工作分支两级 `AGENTS.md`；无需本机Android私钥或Blender。
具备联网及GitHub读取能力的AI可直接读取该公开分支。

## 本版更新

- 右下瞄准摇杆驱动四臂十字准星与中心点，显示人物和枪口当前朝向；遮挡截断，暂停和搜索时隐藏。
- 物品品质底色去除灰雾，灰、绿、蓝、黄、红背景与原色图标分层绘制；未搜索物品不显示品质。
- 局内菜单改为小圆形齿轮；圆形搜索键只在靠近可直接接触物资时显示，离开或换箱时取消按压。
- 包含48种原创变卖物、室内容器逐件搜索动画、双击/点选放置/拖动物品转移，以及之前的手机触控与装备改动。

[完整项目说明](https://github.com/sonrunqing/SDC/blob/fix-game-bugs/README.md) ·
[构建身份](https://github.com/sonrunqing/SDC/blob/fix-game-bugs/development/android-v0.4.14.json) ·
[本版实际引擎预览](https://github.com/sonrunqing/SDC/blob/fix-game-bugs/development/previews/README.md)

![0.4.14 靠近物资时的圆形搜索键与准星](https://raw.githubusercontent.com/sonrunqing/SDC/fix-game-bugs/development/previews/SDC-v0.4.14-near-loot.png)

## 项目现状

这是离线单人开发原型。Android导出、包名、版本、证书和资源清单已核对；本轮没有新增或运行自动测试，没有物理手机游玩、性能或覆盖安装结果。尚未实现多人服务器、账号和联网经济系统。

原有预览与资料仍保留在main历史目录中；本版素材来源和许可见[当前来源说明](https://github.com/sonrunqing/SDC/blob/fix-game-bugs/SDC/THIRD_PARTY_ASSETS.md)。
