# SDC 接续状态

## active · 手机体验改良与 GitHub 视觉 Agent 入口（2026-10-19）

背景：用户要求次要详情/说明/操作点击后以整体上层窗口显示，不挤压主格子；改良全游戏，并看真实帧/原始触摸、多指走完整流程。GitHub供agent在自身本地/云环境运行，旧公网托管和headless状态验收已superseded。反馈与推断在docs/PLAYER_FEEDBACK.md，DECISIONS/AGENTS同步；用户“记住每次反馈”已写全局ad_hoc note、读回并告知路径。固定包名/签名，递增版本，不清存档。

实现与验证完成未发布：邻近touch_popup、仓库/商店/图鉴/搜索去常驻详情；购买保留列表、小窗及数量按需；改枪接口压缩；冗余空武器键隐藏；地图整备返回修正。ai/play.py+tools/ai_player运行真实main，独立存档/设置、原始触摸、多指、截图/过程帧/动作日志；MCP9工具真实连线和图片/选择器文字通过；Windows fresh Godot4.6.3下载校验通过。短屏二次坐标缩放已修复并重新看图。JSON关闭有确认，非法整组触摸首触前拒绝。Linux/Docker/macOS及实体手机未实测。

完整实玩：Temp/sdc-ai-uo0hx8dq，1280×576，西侧入口步行进室内；84搜索未知扫描、121详情、123点放硬盘、127双击硬盘、137拖动14发弹药后容器空；349击倒守卫，377/390撤离倒计时，400撤离成功价值2352，404回整备。未传送、直接开箱或发物品。首轮1600×720在Temp/sdc-ai-n3ix_wz5看仓库/商店/装备/改枪/设置/地图/双指/三指等。服务均已停。

读上轮PR回执发现两条准星P2（discussion4307325154/56），已共用辅助方向和霰弹0.09散布修复，9项新回归通过。最终代码全量对应回归438项（touch12/container93/frontend324/aim9）+Python2组通过。0.4.16生产真图在Temp/sdc-ai-7esqlq2j/10与16，瞄准弹药30后独立开火击倒目标18发余弹，已看。22张原始PNG与索引已复制development/visual-acceptance-0.4.16；docs/VISUAL_ACCEPTANCE_0_4_16.md明确候选完整实玩与最终准星复查边界。

已构建最终0.4.16/code23：SDC-tools/builds/SDC-v0.4.16.apk，97886913bytes，SHA256 2095b78dc05706c546e42becf241a786cd0605d295687e18e3e450fcdcfc103b。包名org.prototype.shooter25d，证书caf122605c0d8479de1e5cef3e957b6149f9da7af8771ea27981fd5781f08fae，固定身份匹配；8相关编译模块差异和开发工具排除已核对。0.4.15/code22为未发布候选，因补准星P2升16。构建身份在development/android-v0.4.16.json。

下一步仅发布收尾：最终diff/secret排除核对→commit/push fix-game-bugs→更新PR1正文并对当前提交请求审查（不合并），发v0.4.16 Latest APK；main只同步README/AI入口，不自动合并源码；匿名验证manifest、当前源码和APK头/摘要；更新repository-access和本HANDOFF；本对话交付本地APK、AI_PLAY链接和实玩范围。AI_PLAY.md/manifest/MCP配置/Dockerfile已写。尚未发布16，Git仍HEAD7c32635且本轮所有文件未提交。当前Latest14、main入口14待更新，旧PR静态问题不能声称全部解决（左手IK/容器统计仍历史差距）。

工具：D:/aa/SDC-tools；Git根D:/aa/SDC，Godot子目录SDC/，branch fix-game-bugs，public sonrunqing/SDC，PR https://github.com/sonrunqing/SDC/pull/1。私钥/凭据留项目外；发布helper沿用外部publish-sdc-v0.4.14.py模式，现有git credential仅进子进程环境，禁止打印/保存token。main README应使用远端最新sha更新。
