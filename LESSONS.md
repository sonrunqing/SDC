# SDC 已确认经验

## active · 品质底色与图标（2026-10-18）

0.4.12 的绘制顺序已经是背景先、图标后，不能把“同一个 CanvasItem”误判为灰色罩层盖在图标上。灰蒙观感主要来自低饱和品质色与深底混合。0.4.13 用直接配出的实色品质底，再把图标移到独立子 CanvasItem；实际生产格子渲染确认颜色更清楚，图标原色保留，未知格子仍一致中性。证据：`SDC/scripts/item_rarity.gd`、`ui_inventory_grid.gd`，交付预览 `SDC-v0.4.13-rarity.png`。

## active · 准星移植（2026-10-18）

旧 Crosshair.cs 的屏幕位置取自鼠标；移植到手机时只复用外形，并消费原始触摸摇杆已有的世界朝向。准星不持有输入，显示位置需要沿世界射线缩短距离以保持可见，不能独立钳制屏幕 x/y 后假装那仍是武器方向。实际局内渲染已显示右摇杆、人物、枪口和准星一致转向；尚非手机触摸验证。证据：`SDC/scripts/ui_aim_reticle.gd`、`raid_world.gd`、`raid_presentation.gd` 与 `SDC-v0.4.13-aim.png`。
