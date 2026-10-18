# Ashfront 画面移植 · SDC 0.4.8

用户提供的旧项目位于 `E:/Godot/Documents/Ashfront`，其入口位于
`E:/Godot/Documents` 下。此次迁移以旧项目当前源码和 `_verify_shots/after_fix.png`
为依据，把主体画面系统接入 SDC 的工业港、角色、装备与手机战局。

## 已接入的画面系统

| 旧项目来源 | SDC 实现 | 实际行为 |
| --- | --- | --- |
| `Core/Look.cs`、`World/Materials.cs` | `scripts/visual_profile.gd` | 冷灰蓝天空与环境光、暖色灯池、ACES、稀薄距离雾、饱和度/对比度、分档辉光和环境遮蔽。战局、地图、角色预览、改枪预览共享标定。GL 的环境光数值按实际渲染重新标定。 |
| `Player/FollowCamera.cs` | `scripts/raid_world.gd` | 55°透视俯视，水平/垂直独立平滑，向瞄准方向提前构图，trauma 平方衰减镜头震动。高度、角度、视野、震动强度可在手机设置页调整。 |
| `Player/HeroVisual.cs`、`assets/hero/hero_animated.glb` | `scripts/operator_model.gd`、`assets/ashfront/operator_animated.glb` | 旧项目 20 骨骼和 17 段动画重蒙皮到 SDC 自有角色，实际速度驱动四方向走/跑；待机、举枪、受击、死亡有对应动作。保留 SDC 的装备、普通弹挂/防弹弹挂和真实枪械组件。 |
| `Enemies/EnemyBase.cs`、`assets/enemy/` | 同一动画适配器及 `rusher.glb`、`sniper.glb` | 两种旧项目敌人剪影接替方块守卫，保留 SDC 守卫数值、巡逻、战斗与掉落。步枪使用旧项目 AK-74 模型，随手骨倒地。 |
| `Player/VisionOcclusion.cs`、`VisionMaskPainter.cs` | `scripts/raid_presentation.gd`、`vision_mask_painter.gd`、`shaders/vision_composite.gdshader` | 80°硬边视野、近身可见区、物理遮挡；多边形并集遮罩，视野外环境压暗 35%。敌人和小地图敌点遵循视野和遮挡。射线分档限频，遮罩投影每帧跟随镜头。 |
| `Combat/Fx.cs`、`HitFeedbackDirector.cs` | `scripts/raid_fx.gd`、`raid_presentation.gd` | 有界特效池、枪口短闪与点光、最长26米曳光、火花/血色命中、尘点和弹壳；命中标记、伤害飘字、目标倒地提示、敌人血条、方向受击提示和镜头反馈。效果只消费已结算的伤害。 |
| `World/ArenaDetail.cs`、`ReferenceArena.cs` | `scripts/harbor_detail.gd`、`shaders/harbor_surface.gdshader` | 基于工业港实际道路和建筑布置横道、止行线、排水槽、井盖、路面修补、接缝、装卸标线、区域字样和接地阴影；固定种子、分块 MultiMesh，装饰不额外阻挡通行。 |
| `World/InteriorReveal.cs` | 现有 `scripts/harbor_map.gd` 的工业建筑揭顶 | 保留并接入新光影；角色进入既有5座可进入建筑时揭去顶盖/遮挡墙体。地图预览使用相同模型与布局。 |
| `Ui/MenuTheme.cs`、`Ui/Hud.cs` | `scripts/main.gd`、`ui_minimap.gd` | 炭灰信息板、细灰边、稳定的琥珀信息色，新增生命条。手机三指按钮、独立触摸和自定义布局沿用 SDC 实现。 |

角色资产转换工具只读取旧项目和 SDC 的源模型，输出独立 GLB，不覆盖源模型。
新角色模型约0.8MB，保留 SDC 的低面数几何；旧项目13.8MB的高面数主角与贴图没有
直接塞进手机包。来源哈希在 `assets/ashfront/provenance.json`。

## 渲染边界

旧项目使用 C# / Forward+；SDC 使用 GDScript / Godot 4.6.3 Compatibility。
Godot 4.6 文档列出了 Compatibility 支持的 SSAO、辉光、调整、距离雾和 MSAA，
也列出了只在 Forward+ 可用的 SSIL、体积雾等。此次保留手机渲染器，体积雾与 SSIL
没有开启，以距离雾、灯池、接地阴影补足层次。画面不是逐像素复刻。

参考：<https://docs.godotengine.org/en/4.6/tutorials/rendering/renderers.html>

省电关闭方向阴影/辉光/SSAO与MSAA；均衡开启阴影、辉光和2x MSAA；精细再开启SSAO。
角色视野最大38m，和 SDC 工业港战斗距离匹配。旧作85m视野及37m相机高度未机械照搬；
SDC 默认31m相机高度，设置可调25–42m。分辨率/帧率/亮度设置继续生效。

旧波次玩法、桌面键鼠输入、旧护甲/经济系统和开发桥不属于本次画面接入。
触摸与存档标识保持原约定；手持枪用校准后的完整手骨姿态，枪焰读取真实枪口节点，
命中射线继续从胸部发出，避免枪口伸入薄墙造成穿墙命中。

## 本机检查与结果

- Godot 4.6.3 导入新模型并实际以 OpenGL 渲染战局、角色近景和工业仓库画面。
- `tests/test_visual_port.gd`：139项通过，包含骨架/动画导入、持枪旋转、瞄准轴校准、
  死亡跟枪、遮挡墙前后可见性、持续射击特效节点上限、长射线显示长度与物品守恒。
- `tests/test_models.gd`：1088项通过，覆盖24把枪体、145件配件、真实挂点和组件替换。
- `tests/test_preview.gd`：28项通过，覆盖改枪预览组件替换、触摸旋转/缩放与草稿只读。
- 渲染工具 `tools/visual_preview.tscn` 输出桌面引擎画面，用于美术核对；不会模拟手机触摸。
  `tools/` 与 `tests/` 均从 Android 包排除。
- Android 构建继续使用固定包名和既有签名，由项目外的 `build-android.ps1` 递增版本。

尚未在用户手机运行本次版本，不能以导出和本机渲染结果代表真机帧率或触摸验收。

## 旧项目 AI 接口检查

已只读确认 `scripts/Agent/` 下存在可用实现，记录见
`docs/ASHFRONT_AI_INTERFACE.md`。本次没有把开发桥接入 Android 发布包。
