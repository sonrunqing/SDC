# 第三方素材

本项目使用以下 Kenney 资源中的部分文件，作者：Kenney（https://kenney.nl）。包内的原始 `License.txt` 已保留。

| 资源 | 使用内容 | 原始页面 | 许可证 |
| --- | --- | --- | --- |
| Blaster Kit 2.1 | blaster-a 至 blaster-r、crate-small、target-large 和对应贴图 | https://kenney.nl/assets/blaster-kit | CC0-1.0 |
| Prototype Kit | figurine-cube、wall、stairs 和对应贴图 | https://kenney.nl/assets/prototype-kit | CC0-1.0 |
| Interface Sounds | confirmation_004、click_001 | https://kenney.nl/assets/interface-sounds | CC0-1.0 |
| Mobile Controls 1.0 | joystick_circle_pad_highlight、joystick_circle_nub_highlight、button_circle_highlight | https://kenney.nl/assets/mobile-controls | CC0-1.0 |

CC0 允许在个人和商业项目中使用、修改这些素材，不强制署名。仍保留来源便于追踪。资源包内的推广材料和作者标志不作为游戏素材使用。完整下载地址及压缩包 SHA-256 在 `assets/kenney/manifest.json`。

界面中文字体来自 Noto Sans CJK SC，采用 SIL Open Font License 1.1。本项目从系统字体集合中提取简体中文字体面供安卓使用；原始许可证与版权说明保存在 `assets/fonts/LICENSE-NOTO.txt`，上游为 https://github.com/notofonts/noto-cjk 。

当前工业货场几何、灯光、人物占位造型和程序合成枪声由本项目代码生成。24 个枪体、145 个附件及 62 个原厂部件为本项目通过 Blender 生成的独立原创低多边形模型，采用 CC0；详见 `assets/modular/LICENSE.txt` 和 `data/weapon_geometry.json`。Kenney 枪械文件保留作为备用原型素材，当前改枪台和玩家携带武器使用原创模块化模型。

## 0.3.0 新增场景与人物

新增 Kenney City Kit Industrial（37 GLB）、Factory Kit（143 GLB）、Car Kit（50 GLB），均为 CC0，来源分别为 https://kenney.nl/assets/city-kit-industrial 、https://kenney.nl/assets/factory-kit 、https://kenney.nl/assets/car-kit 。原始 LICENSE 与模型同目录保留，下载地址、版本和 SHA-256 在 `assets/environment/manifest.json`。当前地图实际使用 97 种模型，其余作为可用资源保留。

人物及 36 件独立穿戴护具由本项目 Blender 脚本生成，共 37 个原创 GLB，采用 CC0，见 `assets/operator/LICENSE.txt`。所有物品图标由实际模型或本项目几何渲染，游戏未使用商业游戏的界面截图或人物模型。界面调研链接见 `docs/FRONTEND_AND_MAP.md`。
