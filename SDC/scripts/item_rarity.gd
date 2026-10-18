extends RefCounted
## Shared five-tier pastel palette. Call only after a record is discovered.
const TONES := {"common":Color("b2b8bc"),"uncommon":Color("a2bfa0"),"rare":Color("9bb5d1"),"epic":Color("d1bc87"),"legendary":Color("d2a19c")}
## Opaque underlays: hue is authored directly, never a gray veil over the icon.
const BACKGROUNDS := {"common":Color("3e454e"),"uncommon":Color("305d42"),"rare":Color("305e91"),"epic":Color("806828"),"legendary":Color("84414b")}
const NAMES := {"common":"普通","uncommon":"少见","rare":"稀有","epic":"珍稀","legendary":"珍贵"}
const GROUPS := {"industrial":"工业品","collectibles":"收藏品","everyday":"生活物品","precision":"高精度仪器","metals":"金属","electronics":"电子元件","medical":"医疗物资","tools":"机修工具"}
static func tone(item: Dictionary) -> Color:
	return TONES.get(str(item.get("rarity","common")),TONES.common)
static func background(item: Dictionary) -> Color:
	return BACKGROUNDS.get(str(item.get("rarity","common")),BACKGROUNDS.common)
static func label(item: Dictionary) -> String:
	return str(NAMES.get(str(item.get("rarity","common")),"普通"))
static func group_label(item: Dictionary) -> String:
	return str(GROUPS.get(str(item.get("loot_category","")),"变卖物"))
