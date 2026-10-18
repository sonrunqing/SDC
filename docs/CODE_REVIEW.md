# SDC 代码审查

本次将此前只在本机存在的完整 Godot 工程纳入 Git，并在 `fix-game-bugs` 分支发起 PR。
`main` 原来只有说明、预览和历史构建信息，因此 PR 的总体差异包含首次导入的项目文件。

## 提交组织

1. **Import complete SDC v0.4.3 Godot source and assets**：导入修复前的代码及运行资源，建立审查基线。
2. **Fix mobile deployment, map navigation and equipment taps**：提交已交付的 0.4.4 修复、版本信息及审查说明。
3. **Add customizable mobile controls and saved layout profiles**：补上 0.4.5 的布局编辑、三方案保存、命中几何共用及大厅/战局入口。
4. **Fix touch buttons stuck by emulated mouse ownership**：0.4.6 修正模拟鼠标先到而触摸释放无法解锁按钮的问题，统一列表、库存和布局编辑画布的来源过滤。
5. **Make controls touch-only and separate storage rigs from armor**：0.4.7 删除键鼠适配与输入模拟，替换全部交互控件，补全 260 件物品详情，并分离普通弹挂与防弹弹挂。

可在 PR 的 Commits 中打开第二次提交，单独看本次约十个核心文件的变化；也可在 Files changed
检查整个游戏。模型、图标及导入描述被标为生成素材，默认折叠，仍可手动展开。游戏规则数据未整体隐藏。

## 重点代码

| 范围 | 入口 | 要关注的行为 |
| --- | --- | --- |
| 页面与出击 | `SDC/scripts/main.gd` | 大厅到预览到战局的动作区别，校验失败反馈，重复点击和页面重建 |
| 地图手势 | `SDC/scripts/map_preview.gd` | 单指平移、双指缩放旋转、手指增减与取消、相机范围 |
| 触屏按钮及滚动 | `touch_button.gd`、`touch_scroll.gd` | 滑动不能误点，抬指和取消必须释放状态 |
| 装备交互 | `ui_inventory.gd`、`ui_inventory_grid.gd` | 点击放置与双击快捷操作的边界，容器可见区域 |
| 物品事务 | `inventory_state.gd`、`inventory_grid.gd`、`game_state.gd` | 库存守恒、失败回滚、背包与弹挂共存、容器替换和存档兼容 |
| 战局控制 | `virtual_controls.gd`、`raid_world.gd` | 移动、瞄准、开火指针独立，暂停与结束时释放输入 |
| 签名和版本 | `SDC/export_presets.cfg`、`SDC/docs/ANDROID_UPDATES.md` | 包名、已确定的证书、递增版本、保留存档的更新流程 |
| 自定义布局 | `control_layout.gd`、`ui_control_layout.gd`、`ui_control_layout_canvas.gd`、`app_settings.gd` | 预览不触发战局操作、保存/取消、暂停恢复、方案持久化、屏幕比例与实际命中一致 |

除第一项的完整路径之外，上表文件都在 `SDC/scripts/`。

## 在 Codex 中审查

创建 PR 后在 Codex 代码审查页打开对应的 PR。已启用 GitHub Codex 审查的仓库，
还可以在 PR 评论中提交 `@codex review` 请求审查；若未启用，先在 Codex 的代码审查设置中连接该仓库。
用中文说明需要重点检查手机输入、出击流程、库存事务和存档；报告应给出文件位置和实际影响。
见 [OpenAI 官方 GitHub 审查说明](https://learn.chatgpt.com/docs/third-party/github)。

## 验证边界

各版本 APK 的公开导出和签名/包名/版本记录在 `development/android-v*.json`。
0.4.6 的输入故障原因和修改见 `SDC/docs/TOUCH_INPUT_FIX_0_4_6.md`。未完成开发侧真机操作验证。
原有 `SDC/tests/` 已保留，本次未新增或运行测试。审查不等同于自动合并；合并需后续明确决定。
Android SDK、Blender、签名密钥、凭据、缓存和 APK 均不作为源码上传。
