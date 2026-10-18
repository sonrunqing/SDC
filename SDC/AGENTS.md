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

## GitHub 代码审查

- 根目录 `AGENTS.md` 的 Code Review Rules 同样适用于本工程。
- 代码审查不需要 Android 私钥；云端审查时不要为缺失的本机路径重新创建签名文件。
- `main.gd` 管理页面与出击，`map_preview.gd` 管理预览手势，`ui_inventory.gd` 管理手势，
  `inventory_state.gd` / `inventory_grid.gd` / `game_state.gd` 管理装备事务与存档。
- 重点检查连续输入、独立多指控制、装备和容器物品守恒，以及保存/加载时的兼容性。
- 仅在静态检查或导出成功时，不得将其描述为真机验证。

## 手机专用输入与弹挂

- 2026-10-18 用户明确要求删除电脑操作适配。运行代码只使用原始触摸，关闭触摸转鼠标和鼠标转触摸模拟；不能重新加回 WASD、鼠标瞄准/开火、滚轮、键盘快捷键或桌面 UI 后备分支。
- 保留 Android 系统返回与手机输入法，搜索和数量输入属于手机功能。Godot 的 `mouse_filter` 是 GUI 触摸路由属性，不应因名称而删除。
- 普通弹挂 `category=rig` 只储物，无防弹属性，可与防弹衣及背包同穿；`category=armored_rig` 为独立分组的防弹弹挂，替代防弹衣但可配背包。统一后端槽沿用历史 `armored_rig`，通过 Catalog 映射，不破坏旧存档。
- 防弹衣栏的淡色防弹弹挂只映射同一真实 UID，不可复制物品、重复计重；该显示位置仍是防弹衣的放置目标。
- 仓库单次点选显示所有类型的实际物品详情，不能破坏继续点放置、双击与拖动，选中后不能挤走原位置的格子。
