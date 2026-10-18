# Ashfront AI 游玩接口检查

2026-10-18 只读检查旧项目完整源码；没有启动旧游戏或服务。

旧项目 `scripts/Main.cs:522` 调用 `AgentBridge.TryAttach(this)`，
`scripts/Agent/AgentGate.cs:22` 同时要求 `agent` 导出特性和 `--agent`。
源码开发模式可通过 `ASHFRONT_AGENT=1` 满足特性门禁；`AgentQA` 导出预设带该特性。

实际实现是本机子进程 stdin/stdout 的 UTF-8 NDJSON，每行一个 JSON。
协议v1、状态schema3；约30Hz快照、1秒心跳，3秒失联释放动作和瞄准。
游戏日志也走stdout，宿主须过滤。实现支持 hello/welcome、cmd/ack/error、state、
events、sync_req、events_req、ping/pong。未发现实际TCP传输或确定性单步step动作。

17类动作包括移动、瞄准、开火、换弹、翻滚、疾跑、近战、交互、换枪、切投掷物、投掷、
商店导航、购买、装备、暂停、继续、重开。命令按阶段与参数校验，带ID去重和30ms限频；
move/fire/sprint各有TTL，默认200ms。瞄准可给angleDeg或当前快照的稳定敌人targetId。
旧interact只真正支持开始下一波，equip调用旧护甲装备，不能原封不动用于SDC搜刮/仓库。

状态包括玩家位置、速度、生命、护甲、枪械弹药、换弹近似进度、波次、经济、商店商品、
敌人及帧率/序列化耗时。敌人按距离取最近36个，含运行内稳定ID和截断摘要。
12类事件通过序号/游标增量读取，256条环缓冲，覆盖报告dropped。
敌人快照包含不可见敌人的位置；公平游玩须遵守visibleToPlayer，不能把快照全量当成视觉。

源码启动参数如下，AI宿主必须保持进程管道：

```powershell
$env:ASHFRONT_AGENT = '1'
& 'E:\Godot\Documents\Godot\engine\Godot_v4.6.3-stable_mono_win64_console.exe' --path 'E:\Godot\Documents\Ashfront' -- --play --agent
```

实际宿主示例为 `E:/Godot/Documents/Godot/tools/_oneoff/bridge_drive.py:30`。
旧ashfront.ps1仍写死D盘路径，不适合作为当前现成启动入口。
截图通过独立 `scripts/Core/DevCapture.cs:28` 的 --shot/--shot-path/--shot-frame
参数实现，等待绘制后保存并退出；协议没有截图动作。

主要实现位置：

- `scripts/Agent/Bridge/Protocol.cs:15`
- `scripts/Agent/Bridge/StdioTransport.cs:60`
- `scripts/Agent/AgentBridge.cs:133`
- `scripts/Agent/Commands/CommandRouter.cs:36`（路由）、`:112`（校验）、`:215`（输入TTL）
- `scripts/Agent/State/StateCollector.cs:129`（快照）、`:339`（敌人列表）
- `scripts/Agent/Events/EventTypes.cs:12`、`EventRing.cs:94`

后续SDC接入可复用协议结构，直接调用 set_move/set_aim/set_fire/reload_weapon/interact
等玩法方法。旧AgentInputApplier的Input.ActionPress/Release不应回引为键鼠适配。
桥应仅在开发构建启用，为搜刮、撤离、仓库和装备事务补充SDC自己的动作与事件。
直接玩法动作能检查游戏规则；手机按钮/滑动/多指所有权仍需要原始触摸路径检查。
