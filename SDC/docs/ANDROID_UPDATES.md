# Android 覆盖更新与固定签名

更新于 2026-10-17。用户要求所有后续改动以新版本覆盖安装，并保持签名一致。

## 当前决定：一次重新安装，之后固定签名

2026-10-17 用户明确选择：

> 可以清空：接受卸载旧版后重新安装，以后固定签名覆盖升级

因此不再等待丢失的云端私钥来阻止后续交付。**这次先卸载手机中的旧 SDC，
再安装 0.4.3（versionCode 10），旧版本地仓库、装备和进度会清空。**
0.4.3 及后续版本固定使用现有本机密钥，不生成新密钥、不改包名。
以后在这个固定签名版本上直接安装更高版本即可，不应重复要求卸载。

这项同意仅适用于本次旧版迁移。尚无手机连接，未执行卸载、清数据、安装或真机验证。
不能声称 0.4.3 可以直接覆盖云端 0.3.0，也不能将证书核对等同于实际安装成功。

## 永久保留的签名身份

| 属性 | 固定值 |
| --- | --- |
| 包名 | org.prototype.shooter25d |
| 证书 SHA-256 | caf122605c0d8479de1e5cef3e957b6149f9da7af8771ea27981fd5781f08fae |
| 密钥路径 | D:/aa/SDC-tools/keys/SDC-fixed-signing.keystore |
| alias | androiddebugkey |
| 密钥文件 SHA-256 | 010fac18aa5626ba623f94863816b4c1b517b4710b2f21b9a6e9928dc0b77d5a |
| 第一份备份 | D:/aa/SDC-tools/keys/backup/SDC-fixed-signing.keystore |
| 第二份备份 | C:/Users/s1378/SDC-signing-backup/SDC-fixed-signing.keystore |
| 首个重新安装版本 | 0.4.3 / code 10 |

固定密钥从既有本机 `keys/debug.keystore` 原样复制，没有生成新密钥。
主文件及两份备份均已核对文件 SHA-256 一致。证书有效期至 2054-03-04。
密钥丢失应从备份恢复；不能用同名新密钥代替。恢复说明随备份保存为 `RECOVERY.txt`。
构建凭据在项目外的本机环境提供，密钥和密码不能提交 Git。
当前继续使用 Android debug 导出方式；包是否能覆盖升级取决于固定包名、证书和递增版本。

## 统一打包流程

入口：`D:/aa/SDC-tools/build-android.ps1`。

```powershell
& D:\aa\SDC-tools\build-android.ps1
# 或明确指定一个比已分配版本更新的版本：
& D:\aa\SDC-tools\build-android.ps1 -Version 0.5.0
```

- 固定 application ID、密钥路径、alias 和证书指纹；策略状态为 `active_fixed_signing`。
- 构建前核对密钥证书、两份密钥备份，以及上次成功导出的参考 APK 的哈希、包名和证书。
- 自动递增可见版本的补丁号和 versionCode，同时更新导出预设与 `project.godot`。
- 使用构建文件锁，已分配的版本不会因导出失败而回退或复用。
- 构建后由 apksigner 校验实际 APK 签名，由 aapt 读取实际包名和版本。
- 输出包含 APK 哈希、证书、参考包、旧版迁移说明的 `.build.json`。
- 成功构建后将新 APK 设为下次参考基准。
- 密钥、备份或参考身份不一致时停止，不重新创建密钥或改包名逃避冲突。

配置在项目外：

- `D:/aa/SDC-tools/android-signing-policy.json`：固定签名、备份、参考包及用户迁移授权。
- `D:/aa/SDC-tools/android-build-state.json`：已分配/成功版本，防止版本回退。
- `D:/aa/SDC-tools/environment.json`：本机构建工具和固定密钥路径。

## 旧版冲突的历史证据

手机导出的 `C:/Users/s1378/Downloads/base.apk` 通过签名校验：

| 属性 | 原云端版本 |
| --- | --- |
| 包名 | org.prototype.shooter25d |
| 版本 | 0.3.0 / code 6 |
| APK SHA-256 | 199bdba465fcd2dadda25d6eb93886455b3ce84ca6060ff57df0273e339fe5d3 |
| 证书 SHA-256 | 0ad176172779f00595698b1929ac834b9b2c29efcd7a334d1d97f0d3b76cd3f0 |

它与原 GitHub 0.3.0 交付记录的文件哈希一致，参考副本为
`D:/aa/SDC-tools/signing-reference/SDC-phone-v0.3.0.apk`。

接手后本机 0.3.0、0.4.0、0.4.1、0.4.2 使用上方 caf122... 证书，
它们互相同签名，但不能覆盖云端旧版。提高版本号无法解决两把签名密钥不同的问题。
接手时未保留原云端签名身份，之后再次交付本机签名包导致用户重复遇到冲突。

已查过项目、源码 ZIP、仓库上传文件、下载/桌面/OneDrive/Documents、备份和常见
Godot/Android 密钥目录，没有找到与原证书匹配的私钥。这并不表示所有离线/云端备份均已查遍。
APK 只有公钥证书，不能从中恢复私钥。原私钥未找到的事实保留，不应称为已恢复旧签名。

0.4.2 诊断产物仍在 `builds/diagnostics-local-signature/`；之前另有同内容交付副本。
它们不是解决原云端版本覆盖升级的包。当前唯一交付基准是重新安装后的固定签名版本。

Android 官方更新条件：[How app updates work](https://developer.android.google.cn/google/play/app-updates?hl=en)。

## 只读存档备份工具

保留工具 `D:/aa/SDC-tools/backup-phone-save.py`，通过经用户授权的 USB 调试
读取 `org.prototype.shooter25d` 的 app files 并核对存档 JSON，保存 tar、独立存档和哈希清单。
它不安装、不卸载、不清数据。此前手机未连接，所以没有实际备份。
本次用户已选择清空，不再以完成存档备份作为本次重新安装的前置条件。