# 0.4.16 手机体验改良与视觉验收

2026-10-19。用户原图的问题是常驻详情与操作栏挤压装备/仓库，只剩一行。
本次按 `PLAYER_FEEDBACK.md` 改为整体上层的邻近窗口，主格子不为次要内容预留空间。
完整主流程先在0.4.15候选代码实玩；最终0.4.16额外修正上一轮准星审查的两条P2，重新运行全部对应回归，并再次实际瞄准、开火击倒目标。0.4.15候选未单独发布。

## 改动

- 仓库详情、旋转/拆分/转移/出售/改枪随点选出现在小窗，关闭后不占空间；拖动时收起。
- 商店/图鉴使用全宽列表，单点才打开资料；购买后更新小窗，保留列表位置。
- 搜索详情与数量进入小窗，暂停移到标题，反馈短暂显示；没有“拿取所选”确认按钮。
- 改枪安装位置去重复说明，全部接口可见；空武器栏、单武器时多余的切枪键隐藏。
- 地图整备返回修复为回到地图，直接进入仓库时仍返回大厅。
- 开发 Agent 使用原始触摸、实际渲染、独立存档；支持多指、中间帧、MCP 图片与动作日志。
- 准星沿与开火相同的辅助瞄准方向检测遮挡；霰弹枪最小0.09弧度散布与指示器共用计算。

## 实际游玩证据

以下为生产 `main.tscn` 在 Windows/Godot4.6.3/OpenGL 的真实帧，来自原始 ScreenTouch/ScreenDrag。
不是重绘图，也不是手机截图。开发工具在决策间冻结世界，动作期间才推进模拟。
人工查看了动作结束图以及拖动、扫描、多指等过程帧。

| 路径 | 实际结果与证据 |
| --- | --- |
| 仓库布局 | [修改前一行](../development/visual-acceptance-0.4.16/inventory-before.png) → [修改后多行](../development/visual-acceptance-0.4.16/inventory-after.png) |
| 邻近详情 | [单选浮窗](../development/visual-acceptance-0.4.16/inventory-popup.png)，格子位置不变；点放、双击、长按拖动完成 |
| 拖动过程 | [手指拖动中的目标格](../development/visual-acceptance-0.4.16/inventory-drag.png)，松开后物品落入目标格 |
| 商店与装备 | [购买后浮窗保留](../development/visual-acceptance-0.4.16/shop-purchase.png)；[普通弹挂、背包和护甲并存](../development/visual-acceptance-0.4.16/rig-backpack-armor.png) |
| 改枪与设置 | [完整接口列](../development/visual-acceptance-0.4.16/workbench.png)、[自定义按键拖动并保存](../development/visual-acceptance-0.4.16/custom-controls.png) |
| 地图/出击 | 单指平移、双指缩放旋转，原始点击进入实际战局；选西侧入口步行进入室内 |
| 多指 | [双指移动/瞄准，弹药30](../development/visual-acceptance-0.4.16/two-fingers.png)；[加独立开火后弹药23](../development/visual-acceptance-0.4.16/three-fingers.png) |
| 搜索动画 | [未知格中性底与32%扫描](../development/visual-acceptance-0.4.16/search-unknown.png)，暂停/继续后逐件发现，未自动领取 |
| 搜刮交互 | [点选详情](../development/visual-acceptance-0.4.16/search-popup.png)、[堆叠数量窗](../development/visual-acceptance-0.4.16/search-quantity.png)；点放硬盘、双击硬盘、拖动14发弹药后[容器已空](../development/visual-acceptance-0.4.16/search-picked.png) |
| 战斗与撤离 | 正常治疗、换弹、[击倒守卫](../development/visual-acceptance-0.4.16/combat.png)，[撤离倒计时](../development/visual-acceptance-0.4.16/extraction-countdown.png)后[成功结算价值2352](../development/visual-acceptance-0.4.16/extraction-success.png)，点击回整备 |
| 短横屏/MCP | 1280×576 的[仓库](../development/visual-acceptance-0.4.16/short-inventory.png)、[浮窗](../development/visual-acceptance-0.4.16/short-popup.png)、[系统返回只关浮窗](../development/visual-acceptance-0.4.16/short-back.png) |

另一次正面战斗进入了行动失败结算，真实验收也覆盖失败返回；没有把它计为成功撤离。
较长路线实际遇到碰撞后绕行，没有传送、改玩家位置、直接开箱或发放战利品。
最终准星复查：[瞄准但未开火，弹药30](../development/visual-acceptance-0.4.16/final-assisted-aim.png) → [独立开火击倒目标，弹药18](../development/visual-acceptance-0.4.16/final-assisted-shot.png)。
本次留存22张原始PNG与SHA256索引 `development/visual-acceptance-0.4.16/frames.json`。

## 回归与交付核对

- 最终代码重新运行：原始触点12项、容器及物品守恒93项、前端/浮窗不缩格/返回路径324项、准星9项，共438项通过。
- Python协议2组边界测试通过；整组非法触摸先拒绝，防止半组操作后才报错。
- 真实 stdio MCP 初始化、9工具列表、启动/点击/浮窗/返回/过程图片/选项窗口文字/停止通过。
- Windows全新下载官方引擎并校验固定SHA256通过；JSON关闭有确认响应。
- 真实游玩日志中未发现SCRIPT ERROR；APK导出、签名与包名、versionCode、编译模块差异和开发工具排除已核对。
- APK：0.4.16/code23，签名沿用0.4.3起固定身份；[构建记录](../development/android-v0.4.16.json)。

## 验证范围

本次未连接实体Android手机；没有真机触摸手感、帧率、温度、系统安装或覆盖升级结果。
Linux/Xvfb/Docker/macOS路线提供了启动文件，尚未在对应环境运行。
主体画面沿用既有移植，旧项目左手IK等历史差距不在本次完成范围；也不据此次流程宣称所有游戏问题已消除。
