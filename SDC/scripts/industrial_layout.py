"""Assemble the harbour's four playable industrial buildings on a four metre grid."""
import json, math
from pathlib import Path

def assemble(layout):
    root = Path(__file__).resolve().parents[1]
    catalog = json.loads((root/"data/industrial_modules.json").read_text(encoding="utf-8"))
    modules = {x["key"]: x for x in catalog["assets"]}
    objects, surfaces, lights = layout["objects"], layout["surfaces"], layout["lights"]
    replaced = {"industrial/building-"+letter for letter in "abcd"}
    objects[:] = [o for o in objects if o["model"] not in replaced]
    layout["buildings"] = []
    layout["industrial_revision"] = 1
    def add(key,x,z,y=0,angle=0,size=None,cutaway="",building=""):
        a=modules[key]
        o=dict(model=a["id"],position=[x,y,z],size=size or a["collision_size"],rotation=angle,collision=True)
        if cutaway:o["cutaway"]=cutaway
        if building:o["building"]=building
        objects.append(o)
    def prop(model,x,z,size,angle=0):
        objects.append(dict(model=model,position=[x,0,z],size=size,rotation=angle,collision=True))
    def surface(x,z,w,d,color,y=.045,h=.012):
        surfaces.append(dict(position=[x,y,z],size=[w,h,d],color=color))
    specs = [
        ("customs_hall","海关收货仓", -55,-35,16,12),
        ("repair_shop","机修车间", -30,-37,12,8),
        ("dispatch_office","调度与备件库", -58,-8,12,8),
        ("assembly_shop","装配车间", -34,-4,12,8)]
    for number,(bid,name,cx,cz,w,d) in enumerate(specs):
        left,right,north,south=cx-w/2,cx+w/2,cz-d/2,cz+d/2
        layout["buildings"].append(dict(id=bid,name=name,center=[cx,cz],size=[w,d],entry=[cx,0,south+1],roof_height=3))
        # Correctly rotated L corners: arms meet along the outside edges.
        for x,z,angle in [(right-1,north+1,0),(left+1,north+1,90),(left+1,south-1,180),(right-1,south-1,270)]:
            near=z>cz or x>cx
            add("corner",x,z,angle=angle,cutaway=bid if near else "",building=bid)
        # Two metre corner wings plus four metre straight infills.
        for j in range(int((w-4)/4)):
            x=left+4+j*4
            add("wall_window" if j%2==0 else "wall_straight",x,north,building=bid)
            # A clear four metre freight bay is also the AI's main entrance.
            if abs(x-cx)>1:
                add("wall_window" if number==2 else "wall_straight",x,south,cutaway=bid,building=bid)
        # For a 12 m building the grid has no central infill; remove its inner
        # south halves and replace by shorter side panels to leave a 4 m bay.
        if w==12:
            objects[:]=[o for o in objects if not(o.get("building")==bid and o["position"][2]==south)]
            add("wall_straight",cx-3,south,size=[2,3,.2],cutaway=bid,building=bid)
            add("wall_straight",cx+3,south,size=[2,3,.2],cutaway=bid,building=bid)
        for j in range(int((d-4)/4)):
            z=north+4+j*4
            add("wall_straight",left,z,angle=90,building=bid)
            add("wall_window",right,z,angle=90,cutaway=bid,building=bid)
        for ix in range(int(w/4)):
            for iz in range(int(d/4)):
                x,z=left+2+ix*4,north+2+iz*4
                add("floor",x,z,y=-.065,building=bid)
                add("ceiling",x,z,y=3.01,cutaway=bid,building=bid)
        for x in [left+.22,right-.22]:
            for z in [north+.22,south-.22]:
                add("pillar",x,z,building=bid,cutaway=bid if x>cx or z>cz else "")
        # Structural roof beams and continuous coping, independent of wall meshes.
        for ix in range(int(w/4)):
            x=left+2+ix*4
            add("beam",x,cz,y=2.67,cutaway=bid,building=bid)
            for z in [north,south]:add("roof_edge",x,z,y=3.13,cutaway=bid,building=bid)
        add("beam",cx,south,y=2.67,cutaway=bid,building=bid)
        for iz in range(int(d/4)):
            z=north+2+iz*4
            for x in [left,right]:add("roof_edge",x,z,y=3.13,angle=90,cutaway=bid,building=bid)
        # Loading apron and paired yellow edge stripes; keep the centre lane clear.
        surface(cx,south+2,w+1,3.6,"525b56")
        for x in [cx-2.4,cx+2.4]:surface(x,south+2,.12,3.3,"d2ae55",.056)
        surface(cx,south-.6,3.6,.1,"d2ae55",.056)
        for x in [cx-2.6,cx+2.6]:
            prop("factory/cone",x,south+1.8,[.35,.55,.35])
        lights.append(dict(position=[cx,2.8,cz],color="e3d4ae",energy=1.0,radius=9,fixture="ceiling",cutaway=bid))
        # Low cover placed against side walls, with an unobstructed central aisle.
        prop("factory/box-wide",left+1.5,north+2,[1.8,1.1,1.2])
        prop("factory/box-large",right-1.5,north+2,[1.3,1.5,1.3])
        if number in (1,3):
            prop("factory/machine",left+2,cz+.3,[1.8,1.6,1.4])
            prop("factory/robot-arm-a",right-2,cz,[1.3,1.8,1.2],180)
        # Loot makes the new interiors part of the extraction route.
        loot_index=[17,18,15,16][number]
        layout["loot"][loot_index]["position"]=[cx,0,north+2.7]
        layout["loot"][loot_index]["name"]=["海关封存货箱","机修工具箱","调度电子物资","装配备件箱"][number]
    # A small office within the freight hall. Its door is intentionally closed;
    # the larger freight bay provides the public route through the building.
    add("partition",-59,-37,building="customs_hall")
    add("wall_doorway",-57,-39,angle=90,building="customs_hall")
    add("door",-57,-39,angle=90,size=[.96,2.15,.16],building="customs_hall")
    # A paired external inspection platform; stair upper end faces north (-Z).
    # Located in the side service yard, clear of both roads and freight aprons.
    add("platform",-43,-34)
    add("stairs",-43,-30.7)
    surface(-43,-26.6,2.2,1.2,"b19b57")
    # Remove random clutter directly under the new stair/approach.
    objects[:]=[o for o in objects if o["model"].startswith("industrial_modular/") or
                not(-44.3<o["position"][0]<-41.7 and -34.9<o["position"][2]<-25.8)]
    layout["industrial_notes"]={
        "assemblies":4,"grid_metres":4,
        "stairs":"Player ramp collision; ground-only AI navigation excludes the flight.",
        "cutaway":"Roofs, east/south walls and near corner pieces hide when player enters."}
    from industrial_expansion_layout import extend
    return extend(layout)
