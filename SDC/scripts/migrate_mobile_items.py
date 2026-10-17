"""One-time, idempotent catalog migration to positive attachment bonuses."""
import json
from pathlib import Path
path=Path(__file__).resolve().parents[1]/"data/items.json"
data=json.loads(path.read_text(encoding="utf-8"))
for item in data["items"]:
    if item["kind"]=="weapon":
        stats=item["stats"]
        stats.setdefault("recoil_control",round(100-stats["recoil"],1))
        stats.setdefault("horizontal_control",round(100-stats["recoil"]*.7,1))
        stats.setdefault("suppression",round(120-stats["noise"],1))
    if item["kind"]=="attachment" and not item.get("positive_bonus_schema"):
        modifiers={}
        for key,value in item.get("modifiers",{}).items():
            if key=="recoil" and value<0:
                modifiers["recoil_control"]=abs(value)
                modifiers["horizontal_control"]=round(abs(value)*.6,1)
            elif key=="noise" and value<0:
                modifiers["suppression"]=abs(value)
            elif key not in ("recoil","noise") and value>0:
                modifiers[key]=value
        item["modifiers"]=modifiers
        item["positive_bonus_schema"]=1
    if item.get("category") in ("backpack","armored_rig"):
        item["storage_cells"]=int(item.get("capacity",0))
        item["description"]=item["description"].replace("容量单位为 kg。","储物空间按格子显示，负重上限单独计算。")
data["schema_version"]=2
path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print("MOBILE_CATALOG",len(data["items"]),"items migrated")
