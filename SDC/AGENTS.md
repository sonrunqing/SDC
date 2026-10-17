# SDC Android 交付要求

用户明确要求每次修改以新版本覆盖安装，签名不能冲突。

- 保持 application ID：`org.prototype.shooter25d`。
- **2026-10-17 用户已明确选择：可以清空旧版数据，接受一次卸载旧版后重新安装，以后固定签名覆盖升级。** 不再要求以丢失的云端私钥作为后续构建的前置条件。
- 从 0.4.3 / versionCode 10 开始，固定使用现有本机密钥，证书 SHA-256：`caf122605c0d8479de1e5cef3e957b6149f9da7af8771ea27981fd5781f08fae`。不能再生成替代密钥。
- 固定密钥：`D:/aa/SDC-tools/keys/SDC-fixed-signing.keystore`；alias 为 `androiddebugkey`。构建环境与签名策略必须指向此文件。
- 两份备份：`D:/aa/SDC-tools/keys/backup/SDC-fixed-signing.keystore`、`C:/Users/s1378/SDC-signing-backup/SDC-fixed-signing.keystore`。密钥及凭据放在项目外，不提交仓库。
- 使用 `D:/aa/SDC-tools/build-android.ps1` 打包；自动递增版本和 versionCode，校验密钥、备份、参考 APK、输出包的包名和证书。密钥缺失应恢复备份，不能重建密钥绕过检查。
- 手机原始 0.3.0 的证书为 `0ad176172779f00595698b1929ac834b9b2c29efcd7a334d1d97f0d3b76cd3f0`，原私钥尚未找到。参考副本在 `D:/aa/SDC-tools/signing-reference/SDC-phone-v0.3.0.apk`。它仅用于历史诊断，不能作为新签名包的兼容更新基准。
- **0.4.3 不能直接覆盖这个云端旧版。此次必须先卸载手机上的旧 SDC（丢失本地进度），再安装 0.4.3。** 后续包可在固定签名版本上覆盖更新。未实际在手机安装时，不声称真机更新成功。
- 以后不能把卸载/清数据作为日常更新流程；不修改包名逃避冲突，不向用户重复交付已知不兼容的包并声称可覆盖旧版。
- 技术记录见 `docs/ANDROID_UPDATES.md`。
