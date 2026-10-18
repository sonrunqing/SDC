#!/usr/bin/env python3
"""Build the original fictional equipment catalog. No third-party game data."""
import json
import csv
import argparse
from pathlib import Path
from balance_rules import apply_balance

ROOT = Path(__file__).resolve().parents[1]
ITEMS = []


def add(item_id, name, kind, category, price, weight, description, **extra):
    ITEMS.append(dict(id=item_id, name=name, kind=kind, category=category,
                      price=price, sell_price=round(price * .56), weight=weight,
                      description=description, **extra))


# Threads, mount standards, and platform sockets are functional data. A shared
# physical interface does not override a weapon_ids restriction on an attachment.
WEAPONS = [
    # model, name, family, caliber, price, kg, damage,rpm,mag,recoil,accuracy,ergo,range,noise, sockets
    ('reed9','芦苇 R9','smg','9x19',5200,2.35,24,820,30,26,76,76,23,64,
     dict(muzzle=['thread_9_13'],grip=['picatinny'],stock=['pdw_slide'],magazine=['mag_reed9'],optic=['picatinny'],laser=['picatinny'],handguard=['hg_reed9'])),
    ('lynx45','猞猁 L45','smg','45acp',6800,2.8,31,620,25,33,73,67,21,69,
     dict(muzzle=['thread_45_16'],grip=['mlok'],stock=['fold_hinge'],magazine=['mag_lynx45'],optic=['picatinny'],laser=['mlok'],handguard=['hg_lynx45'])),
    ('kestrel57','红隼 K57','smg','57x28',8500,2.6,22,900,40,20,84,73,28,61,
     dict(muzzle=['thread_57_10'],stock=['pdw_slide'],magazine=['mag_kestrel57'],optic=['microplate'],laser=['picatinny'])),
    ('swift9','雨燕 S9','smg','9x19',3900,2.1,25,700,32,29,72,82,20,65,
     dict(muzzle=['thread_9_13'],stock=['swift_hinge'],magazine=['mag_swift9'],optic=['dovetail'],laser=['trigger_rail'],handguard=['hg_swift9'])),
    ('badger556','獾 B556','rifle','556x45',9800,3.35,34,720,30,34,85,65,36,83,
     dict(muzzle=['thread_556_12'],grip=['mlok'],stock=['ar_buffer'],magazine=['mag_ar556'],optic=['picatinny'],laser=['mlok'],handguard=['hg_ar556'])),
    ('cedar545','雪松 C545','rifle','545x39',8200,3.45,32,650,30,36,82,59,34,81,
     dict(muzzle=['thread_545_14'],grip=['keymod'],stock=['cedar_trunnion'],magazine=['mag_cedar545'],optic=['side_rail'],laser=['keymod'],handguard=['hg_cedar545'])),
    ('jackal762','胡狼 J762','rifle','762x39',8800,3.7,41,600,30,43,79,55,33,88,
     dict(muzzle=['thread_762_14'],grip=['picatinny'],stock=['fold_hinge'],magazine=['mag_jackal762'],optic=['side_rail'],laser=['picatinny'],handguard=['hg_jackal762'])),
    ('manta300','蝠鲼 M300','rifle','300blk',13500,3.1,39,700,30,31,87,69,31,71,
     dict(muzzle=['thread_308_58'],grip=['mlok'],stock=['ar_buffer'],magazine=['mag_manta300'],optic=['picatinny'],laser=['mlok'],handguard=['hg_ar556'])),
    ('heron308','苍鹭 H308','sniper','308win',14500,4.5,79,65,10,54,95,42,48,95,
     dict(muzzle=['thread_308_58'],grip=['bipod_stud'],stock=['bolt_cheek'],magazine=['mag_heron308'],optic=['picatinny'],laser=['picatinny'],handguard=['hg_heron308'])),
    ('falcon762r','猎隼 F762R','sniper','762x54r',11800,4.2,74,180,10,51,92,46,45,97,
     dict(muzzle=['thread_762_14'],stock=['falcon_cheek'],magazine=['mag_falcon762r'],optic=['side_rail'],handguard=['hg_falcon762r'])),
    ('osprey338','鱼鹰 O338','sniper','338lm',23800,6.1,108,42,5,65,98,29,58,100,
     dict(muzzle=['thread_338_34'],grip=['bipod_stud'],stock=['bolt_cheek'],magazine=['mag_osprey338'],optic=['picatinny'],laser=['picatinny'],handguard=['hg_osprey338'])),
    ('wren556','鹪鹩 W556','sniper','556x45',12200,3.85,49,320,20,39,94,53,43,85,
     dict(muzzle=['thread_556_12'],grip=['bipod_stud'],stock=['ar_buffer'],magazine=['mag_ar556'],optic=['picatinny'],handguard=['hg_ar556'])),
    ('boar12','野猪 B12','shotgun','12g',6200,3.2,76,90,6,58,66,58,15,96,
     dict(muzzle=['thread_12_m22'],grip=['pump_rail'],stock=['shotgun_mount'],magazine=['tube_boar12'],optic=['picatinny'],laser=['picatinny'],handguard=['hg_boar12'])),
    ('ram12','盘羊 R12','shotgun','12g',10900,3.65,72,280,8,51,69,49,17,95,
     dict(muzzle=['thread_12_m22'],grip=['picatinny'],stock=['fold_hinge'],magazine=['mag_ram12'],optic=['picatinny'],laser=['picatinny'],handguard=['hg_ram12'])),
    ('fox20','赤狐 F20','shotgun','20g',4700,2.65,63,110,5,43,72,72,14,87,
     dict(muzzle=['thread_20_m20'],stock=['fox_stock'],magazine=['tube_fox20'],optic=['dovetail'],laser=['trigger_rail'])),
    ('elk12','麋鹿 E12','shotgun','12g',7600,3.35,82,130,2,62,75,60,19,99,
     dict(muzzle=['thread_12_m22'],stock=['shotgun_mount'],magazine=['chamber_elk12'],optic=['dovetail'])),
    ('bison556','野牛 B556','machine_gun','556x45',16800,6.4,36,780,75,38,78,29,37,93,
     dict(muzzle=['thread_556_12'],grip=['bipod_stud'],stock=['bison_socket'],magazine=['belt_bison556'],optic=['picatinny'],laser=['picatinny'],handguard=['hg_bison556'])),
    ('yak762','牦牛 Y762','machine_gun','762x39',13600,5.6,43,650,60,46,76,33,35,95,
     dict(muzzle=['thread_762_14'],grip=['picatinny'],stock=['yak_socket'],magazine=['drum_yak762'],optic=['side_rail'],laser=['picatinny'],handguard=['hg_yak762'])),
    ('rhino762r','犀牛 R762R','machine_gun','762x54r',19800,8.1,55,700,100,52,80,20,42,100,
     dict(muzzle=['thread_762_14'],grip=['bipod_stud'],stock=['rhino_socket'],magazine=['belt_rhino762r'],optic=['side_rail'],laser=['picatinny'],handguard=['hg_rhino762r'])),
    ('aurochs556','原牛 A556','machine_gun','556x45',14900,5.1,35,850,60,36,81,37,36,92,
     dict(muzzle=['thread_556_12'],grip=['mlok'],stock=['ar_buffer'],magazine=['mag_aurochs556'],optic=['picatinny'],laser=['mlok'],handguard=['hg_aurochs556'])),
    ('finch9','金雀 F9','pistol','9x19',2600,0.85,27,440,15,37,78,88,19,62,
     dict(muzzle=['thread_9_13'],magazine=['mag_finch9'],optic=['microplate'],laser=['pistol_rail'])),
    ('ember45','余烬 E45','pistol','45acp',3400,1.12,34,350,8,46,76,79,18,68,
     dict(muzzle=['thread_45_16'],magazine=['mag_ember45'],laser=['trigger_rail'])),
    ('moth57','夜蛾 M57','pistol','57x28',5400,0.92,25,480,20,28,84,86,24,60,
     dict(muzzle=['thread_57_10'],magazine=['mag_moth57'],optic=['microplate'],laser=['pistol_rail'])),
    ('raven9','渡鸦 R9','pistol','9x19',4100,1.25,28,500,20,31,80,75,21,66,
     dict(muzzle=['thread_9_13'],stock=['pistol_brace'],magazine=['mag_raven9'],optic=['picatinny'],laser=['pistol_rail'])),
]
HANDLING = {
 'reed9':'近距离压制见长的 9 mm 冲锋枪，射速高、操控轻快。适合机动搜索和短距离交火。',
 'lynx45':'.45 口径冲锋枪，单发威力较高、射速温和。M 型槽和折叠尾座便于选配握把与枪托。',
 'kestrel57':'轻巧的 5.7 mm 冲锋枪，后坐较小，40 发基础弹容适合持续点射。采用微型瞄具底板。',
 'swift9':'结构紧凑、价格亲民的 9 mm 冲锋枪。灵活性出色，燕尾导轨与专用折叠尾座保留了独特装配选择。',
 'badger556':'均衡的 5.56 mm 突击步枪，适合中距离点射与近距连发。AR 缓冲管和 M 型槽提供多种改装空间。',
 'cedar545':'稳健的 5.45 mm 突击步枪，射速适中。侧挂导轨、钥孔护木与专用尾座需要各自匹配的配件。',
 'jackal762':'单发威力较强的 7.62 mm 突击步枪，后坐明显。适合短点射，补偿器和支撑枪托能改善连续控制。',
 'manta300':'.300 口径紧凑步枪，兼顾威力、精度与近距离操控。搭配同口径消音器可降低暴露风险。',
 'heron308':'.308 口径精确步枪，单发威力高、基础精度出色。射速慢，支架和可调贴腮托适合远距离交火。',
 'falcon762r':'使用 7.62×54R 弹药的半自动精确步枪，兼顾威力与补射速度。侧挂瞄具和专用贴腮托适合稳定瞄准。',
 'osprey338':'.338 口径重型精确步枪，拥有最长有效射程与极高单发威力。重量和缓慢射速要求谨慎选择射击时机。',
 'wren556':'轻口径精确步枪，远距离精度优秀，补射较快。与獾共享 AR 供弹标准，前端采用支架固定柱。',
 'boar12':'可靠的泵动 12 号霰弹枪，近距离威力突出。弹仓管容量有限，泵动前握把能改善控枪。',
 'ram12':'弹匣供弹的 12 号霰弹枪，适合近距离连续交火。折叠尾座与导轨为控制后坐提供多种选择。',
 'fox20':'轻巧灵活的 20 号霰弹枪，后坐比 12 号平台温和。适合狭窄区域机动，远距离伤害受限。',
 'elk12':'双管 12 号霰弹枪，近距离整次射击威力很高。只有两发装填空间，需要把握出手和装填时机。',
 'bison556':'5.56 mm 班用机枪，基础供弹量大，适合控制通道。重量较高，支架和缓冲尾托能改善长点射。',
 'yak762':'7.62 mm 弹鼓机枪，单发威力和携弹量兼顾。后坐偏大，适合依托掩体进行有节奏的压制。',
 'rhino762r':'使用全威力 7.62×54R 弹药的重型机枪，基础 100 发供弹。火力强劲但十分沉重，携行与控枪均需取舍。',
 'aurochs556':'相对轻便的 5.56 mm 支援机枪，射速高、持续火力充足。采用 AR 缓冲管和 M 型槽，供弹盒则为专用。',
 'finch9':'轻便经济的 9 mm 手枪，适合基础出战或轻装搜索。支持微型红点与手枪激光模块。',
 'ember45':'.45 口径手枪，单发威力较高但弹容只有 8 发。无瞄具导轨，可选配扳机护圈激光。',
 'moth57':'5.7 mm 轻型手枪，后坐较低，基础 20 发弹容。微型瞄具和匹配弹药适合精确补射。',
 'raven9':'尺寸较大的 9 mm 手枪，射速和弹容充足。支持专用稳定肩托、顶置导轨瞄具和手枪激光。',
}
for model,name,family,caliber,price,weight,damage,rpm,mag,recoil,accuracy,ergo,reach,noise,slots in WEAPONS:
    add('weapon_'+model,name,'weapon',family,price,weight,
        HANDLING[model],caliber=caliber,slots=slots,
        visual_model=f'res://assets/modular/weapons/weapon_{model}.glb',
        stats=dict(damage=damage,rpm=rpm,magazine=mag,recoil=recoil,accuracy=accuracy,
                   ergonomics=ergo,range=reach,noise=noise))


def att(item_id,name,category,slot,interfaces,price,weight,modifiers,weapon_ids=None,description=''):
    extra=dict(slot=slot,interfaces=interfaces,modifiers=modifiers,
               visual_model=f'res://assets/modular/attachments/att_{item_id}.glb')
    if weapon_ids:
        extra['weapon_ids']=['weapon_'+w for w in weapon_ids]
    add('att_'+item_id,name,'attachment',category,price,weight,
        description or {'grip':'改善握持与控枪表现；请按前端安装标准选择。','stock':'改变后坐与操控手感，需匹配枪械尾座。','magazine':'为对应供弹平台提供容量或装填操控上的取舍。','optic':'提升瞄准精度，较重的高倍率瞄具会降低操控性。','laser':'提供辅助指向，提高近距离射击精度。','handguard':'贴合对应机匣的护木，改善握持、平衡和控枪。'}.get(category,'专为匹配接口设计的枪械部件。'),**extra)


THREAD_NAMES={'thread_9_13':'9 mm / M13','thread_45_16':'.45 / M16','thread_57_10':'5.7 mm / M10',
 'thread_556_12':'5.56 / 1/2','thread_545_14':'5.45 / M14','thread_762_14':'7.62 / M14',
 'thread_308_58':'.30 / 5/8','thread_338_34':'.338 / 3/4','thread_12_m22':'12 号 / M22','thread_20_m20':'20 号 / M20'}
for index,(thread,label) in enumerate(THREAD_NAMES.items()):
    suffix=thread.removeprefix('thread_')
    att('suppressor_'+suffix,'静流消音器 · '+label,'suppressor','muzzle',[thread],1900+index*130,.48,
        dict(noise=-38,recoil=-4,ergonomics=-6,range=1),description='压低开火噪声和被敌人听见的距离，增加前端重量。')
    att('flash_hider_'+suffix,'薄暮消焰器 · '+label,'flash_hider','muzzle',[thread],650+index*45,.12,
        dict(noise=-6,recoil=-2,accuracy=1),description='遮蔽枪口焰；小幅改善控制和隐蔽。')
    att('compensator_'+suffix,'平衡补偿器 · '+label,'compensator','muzzle',[thread],1050+index*60,.19,
        dict(recoil=-9,accuracy=2,noise=4,ergonomics=-1),description='导出上扬气流，明显降低连续射击散布。')
    att('muzzle_brake_'+suffix,'砾岩制退器 · '+label,'muzzle_brake','muzzle',[thread],1300+index*65,.24,
        dict(recoil=-13,accuracy=1,noise=9,ergonomics=-3),description='更强的后坐抑制，同时让枪声更响。')

for item_id,name,interfaces,price,weight,mods in [
 ('grip_vertical','垂直战术握把',['picatinny'],760,.17,dict(recoil=-7,ergonomics=1)),
 ('grip_angled','轻量斜角握把',['picatinny'],890,.12,dict(recoil=-4,ergonomics=7)),
 ('grip_mlok_rubber','M 槽橡胶握把',['mlok'],840,.16,dict(recoil=-6,ergonomics=4)),
 ('grip_mlok_stop','M 槽止滑手挡',['mlok'],560,.07,dict(recoil=-2,ergonomics=8)),
 ('grip_keymod','钥孔短握把',['keymod'],720,.11,dict(recoil=-5,ergonomics=4)),
 ('grip_bipod','折叠支撑脚架',['bipod_stud'],1650,.45,dict(recoil=-11,accuracy=6,ergonomics=-7)),
 ('grip_bipod_carbon','碳纤维支撑脚架',['bipod_stud'],2850,.26,dict(recoil=-9,accuracy=7,ergonomics=-3)),
 ('grip_pump','泵动防滑前握把',['pump_rail'],780,.15,dict(recoil=-6,ergonomics=5)),
]: att(item_id,name,'grip','grip',interfaces,price,weight,mods)

STOCKS=[
 ('ar_light','轻骨伸缩枪托','ar_buffer',950,.28,dict(recoil=-4,ergonomics=8)),
 ('ar_heavy','稳固重型枪托','ar_buffer',1650,.55,dict(recoil=-12,accuracy=3,ergonomics=-4)),
 ('pdw_compact','PDW 紧凑滑轨枪托','pdw_slide',880,.24,dict(recoil=-5,ergonomics=7)),
 ('pdw_padded','PDW 缓冲滑轨枪托','pdw_slide',1200,.39,dict(recoil=-9,ergonomics=2)),
 ('fold_light','双销轻量折叠枪托','fold_hinge',900,.29,dict(recoil=-4,ergonomics=6)),
 ('fold_braced','双销支撑折叠枪托','fold_hinge',1560,.46,dict(recoil=-10,accuracy=2,ergonomics=-2)),
 ('swift','雨燕侧折枪托','swift_hinge',760,.22,dict(recoil=-7,ergonomics=4)),
 ('cedar','雪松尾座枪托','cedar_trunnion',1150,.43,dict(recoil=-10,ergonomics=1)),
 ('bolt','精确可调贴腮托','bolt_cheek',2200,.63,dict(recoil=-8,accuracy=7,ergonomics=-3)),
 ('falcon','猎隼木质贴腮托','falcon_cheek',1400,.52,dict(recoil=-7,accuracy=5,ergonomics=-2)),
 ('shotgun','霰弹缓冲枪托','shotgun_mount',1480,.48,dict(recoil=-13,ergonomics=-1)),
 ('fox','赤狐轻木枪托','fox_stock',850,.31,dict(recoil=-7,ergonomics=5)),
 ('bison','野牛缓冲尾托','bison_socket',1800,.62,dict(recoil=-13,accuracy=2,ergonomics=-3)),
 ('yak','牦牛支撑枪托','yak_socket',1560,.54,dict(recoil=-11,accuracy=3,ergonomics=-2)),
 ('rhino','犀牛重型尾托','rhino_socket',2100,.76,dict(recoil=-15,accuracy=2,ergonomics=-5)),
 ('brace','渡鸦稳定肩托','pistol_brace',1450,.36,dict(recoil=-11,accuracy=4,ergonomics=-3)),
]
for item_id,name,interface,price,weight,mods in STOCKS:
    att('stock_'+item_id,name,'stock','stock',[interface],price,weight,mods)

# Magazine capacity is an additive modifier over each platform's base capacity.
# AR family uses one real shared magazine interface; all other feeds are dedicated.
seen_mag=set()
for model,name,family,caliber,price,weight,damage,rpm,base,recoil,accuracy,ergo,reach,noise,slots in WEAPONS:
    interface=slots['magazine'][0]
    if interface in seen_mag:
        continue
    seen_mag.add(interface)
    users=[w[0] for w in WEAPONS if w[-1]['magazine'][0]==interface]
    if interface=='mag_ar556':
        # The same 10-round extension means 40 rounds on B556 and 30 on W556.
        variants=[('quick','快拔供弹组件',0,7,.02,650),('extended','加长供弹组件',10,-5,.18,1150)]
    elif interface.startswith('tube_'):
        variants=[('follower','低摩擦托弹簧',0,5,.02,500),('extended','延长弹仓管',2,-4,.16,1000)]
    elif interface.startswith('chamber_'):
        variants=[('speed','双管快速装填套件',0,8,.06,600),('reinforced','双管精密闭锁套件',0,-2,.13,1050)]
    elif family=='machine_gun':
        variants=[('quick','轻型供弹盒',0,5,-.05,1000),('extended','大容量供弹盒',40,-10,.55,2200)]
    else:
        extra=max(3,round(base*.5))
        variants=[('quick','快拔弹匣',0,6,.02,550),('extended','扩容弹匣',extra,-6,.2,1250)]
    for tag,label,bonus,ergo_delta,extra_weight,cost in variants:
        mods=dict(magazine=bonus,ergonomics=ergo_delta)
        if interface.startswith('chamber_') and tag=='reinforced':
            mods.update(accuracy=4,recoil=-3)
        att('mag_'+model+'_'+tag,name.split(' ')[0]+' '+label,'magazine','magazine',[interface],cost,max(.05,.18+extra_weight),mods,users)

for item_id,name,interfaces,price,weight,mods in [
 ('red_dot','澄光红点',['picatinny'],900,.12,dict(accuracy=4,ergonomics=3)),
 ('holo','窗式全息镜',['picatinny'],1550,.24,dict(accuracy=6,ergonomics=1)),
 ('scope2','林缘 2 倍棱镜',['picatinny'],1900,.29,dict(accuracy=8,range=3,ergonomics=-2)),
 ('scope4','远望 4 倍瞄具',['picatinny'],2850,.44,dict(accuracy=12,range=7,ergonomics=-7)),
 ('scope8','隼眼 8 倍瞄具',['picatinny'],4200,.61,dict(accuracy=15,range=12,ergonomics=-12)),
 ('thermal','侦察复合瞄具',['picatinny'],6800,.72,dict(accuracy=10,range=8,ergonomics=-10)),
 ('dove_dot','燕尾导轨红点',['dovetail'],750,.13,dict(accuracy=4,ergonomics=2)),
 ('dove_scope','燕尾 3 倍镜',['dovetail'],2100,.36,dict(accuracy=9,range=5,ergonomics=-5)),
 ('side_dot','侧轨反射瞄具',['side_rail'],1150,.22,dict(accuracy=5,ergonomics=1)),
 ('side_scope','侧轨 4 倍镜',['side_rail'],2450,.48,dict(accuracy=11,range=7,ergonomics=-7)),
 ('micro_dot','微型开放红点',['microplate'],850,.05,dict(accuracy=4,ergonomics=4)),
 ('micro_enclosed','微型封闭红点',['microplate'],1480,.08,dict(accuracy=6,ergonomics=2)),
]: att('optic_'+item_id,name,'optic','optic',interfaces,price,weight,mods)

for item_id,name,interfaces,price,weight,mods in [
 ('rail_red','导轨红色激光',['picatinny'],650,.08,dict(accuracy=4,ergonomics=1)),
 ('rail_green','导轨绿色激光',['picatinny'],1250,.11,dict(accuracy=6,ergonomics=-1)),
 ('mlok','M 槽紧凑激光',['mlok'],900,.07,dict(accuracy=5,ergonomics=1)),
 ('keymod','钥孔激光模块',['keymod'],900,.08,dict(accuracy=5)),
 ('trigger','扳机护圈激光',['trigger_rail'],800,.05,dict(accuracy=4,ergonomics=2)),
 ('pistol_red','手枪微型红激光',['pistol_rail'],600,.04,dict(accuracy=4,ergonomics=2)),
 ('pistol_green','手枪绿色激光',['pistol_rail'],1150,.06,dict(accuracy=6)),
 ('rail_ir','侦察复合激光器',['picatinny'],1800,.14,dict(accuracy=7,ergonomics=-2)),
]: att('laser_'+item_id,name,'laser','laser',interfaces,price,weight,mods)

seen_hg=set()
for w in WEAPONS:
    model,name,family,*_=w
    slots=w[-1]
    if 'handguard' not in slots:
        continue
    interface=slots['handguard'][0]
    if interface in seen_hg:
        continue
    seen_hg.add(interface)
    users=[x[0] for x in WEAPONS if x[-1].get('handguard',[])==[interface]]
    att('handguard_'+model,name.split(' ')[0]+' 散热护木','handguard','handguard',[interface],1450,.24,
        dict(recoil=-3,accuracy=2,ergonomics=5),users,
        description='专用护木；仅匹配对应机匣，不会凭空增加其他附件插槽。')

# Twelve helmets and twelve body armor: three distinct trade-offs at each tier.
for level in range(1,5):
    for variant,(code,label,delta,weight,cost,mount) in enumerate([
        ('a','轻巡',-2,.85,0,'visor_rail_a'),
        ('b','守望',0,1.10,500,'visor_rail_b'),
        ('c','堡垒',2,1.35,1050,'visor_rail_a'),
    ]):
        add(f'helmet_moss_{level}{code}',f'{level} 级 · 苔原{label}头盔','armor','helmet',
            1500+level*1400+cost,round(weight+level*.12,2),
            '带一个面罩卡槽；A / B 两种轨道标准互不通用。',
            level=level,protection=level*13+delta,durability=55+level*15+variant*8,
            capacity=0,visor_mount=mount,visor_mounts=[mount],armor_zone='head')
    for variant,(code,label,delta,weight,cost) in enumerate([
        ('a','纤维轻装',-2,2.0,0),('b','复合巡逻',0,2.8,650),('c','陶瓷重装',3,3.6,1400),
    ]):
        add(f'body_armor_fiber_{level}{code}',f'{level} 级 · {label}防弹衣','armor','body_armor',
            2100+level*1850+cost,round(weight+level*.3,2),
            '覆盖躯干；等级影响减伤，重量影响可携物资。',level=level,
            protection=level*13+delta,durability=65+level*19+variant*10,capacity=0,armor_zone='torso')

for item_id,name,capacity,price,weight in [
 ('backpack_daypack','折叠日用背包',12,1100,.65),('backpack_scout','侦察背包',20,2600,1.1),
 ('backpack_patrol','巡逻背包',30,4900,1.7),('backpack_hauler','远征运输背包',42,7900,2.6),
]:
    add(item_id,name,'armor','backpack',price,weight,'不设等级，仅区分容量。容量单位为 kg。',
        capacity=capacity,protection=0,durability=100,armor_zone='none')
for item_id,name,capacity,price,weight in [
 ('armored_rig_scout','紧凑弹挂',8,2800,2.1),('armored_rig_patrol','巡逻弹挂',12,4100,2.65),
 ('armored_rig_operator','行动弹挂',18,5900,3.3),('armored_rig_cargo','装载弹挂',24,7600,4.1),
]:
    # Keep these IDs so existing inventories become plain rigs without migration loss.
    add(item_id,name,'armor','rig',price,weight,
        '普通弹挂，仅提供分区储物格，不具备防弹能力；可与防弹衣、背包同时装备。',
        capacity=capacity,storage_cells=capacity)
for level,(suffix,label,capacity,rig_price,rig_weight) in enumerate([
 ('scout','紧凑',8,2800,2.1),('patrol','巡逻',12,4100,2.65),
 ('operator','行动',18,5900,3.3),('cargo','装载',24,7600,4.1),
],start=1):
    add(f'armored_rig_guard_{suffix}',f'{level} 级 · {label}防弹弹挂','armor','armored_rig',
        rig_price+2100+level*1850+650,round(rig_weight+2.8+level*.3,2),
        '防弹衣与弹挂结合体，提供躯干防护及分区储物格；占用弹挂栏，不能与防弹衣同时装备，可同时携带背包。',
        level=level,capacity=capacity,storage_cells=capacity,protection=level*13,
        durability=75+level*19,armor_zone='torso',visual_alias=f'armored_rig_{suffix}')
for level in (1,2):
    for suffix,mount,label in [('a','visor_rail_a','A 轨'),('b','visor_rail_b','B 轨')]:
        add(f'visor_{level}{suffix}',f'{level} 级 · {label}防护面罩','armor','visor',
            1200+level*1600,.3+level*.12,'仅可装入同标准头盔卡槽；提升头部综合防护。',
            level=level,protection=level*10,durability=45+level*20,capacity=0,visor_mount=mount,armor_zone='face')

CALIBERS={
 '9x19':('9×19 mm',24,.008),'45acp':('.45 ACP',31,.012),'57x28':('5.7×28 mm',28,.006),
 '556x45':('5.56×45 mm',34,.012),'545x39':('5.45×39 mm',33,.010),
 '762x39':('7.62×39 mm',39,.016),'300blk':('.300 BLK',38,.016),
 '308win':('.308 Win',44,.024),'762x54r':('7.62×54R',46,.024),
 '338lm':('.338 LM',55,.042),'12g':('12 号霰弹',18,.038),'20g':('20 号霰弹',16,.028),
}
for caliber,(name,base_pen,weight) in CALIBERS.items():
    for suffix,label,pen,mult,cost in [
        ('fmj','普通',base_pen-10,1.0,16),('ap','穿甲',base_pen+15,.90,44),('hp','扩张',max(3,base_pen-23),1.22,25),
    ]:
        if caliber.endswith('g'):
            label={'fmj':'鹿弹','ap':'独头穿透弹','hp':'近距散弹'}[suffix]
        add(f'ammo_{caliber}_{suffix}',f'{name} · {label}','ammo',caliber,
            cost*(2 if caliber in ['338lm','308win','762x54r'] else 1),weight,
            '普通弹均衡；穿甲弹对护甲更有效；扩张弹对无甲目标伤害更高。',
            caliber=caliber,penetration=pen,damage_multiplier=mult,stack_size=60)

for item_id,name,price,weight,heal in [
 ('bandage_basic','应急绷带',180,.12,25),('medkit_field','野战急救包',700,.5,55),('medkit_surgical','综合医疗箱',1550,.9,85),
]:
    add(item_id,name,'consumable','medical',price,weight,f'战局中恢复 {heal} 点生命。',heal=heal,uses=1)
for item_id,name,price,weight,rarity in [
 ('loot_wire','绝缘导线',420,.25,'common'),('loot_battery','工业电池',760,.6,'common'),
 ('loot_tools','精密工具组',1700,1.2,'uncommon'),('loot_filter','净化滤芯',1280,.55,'uncommon'),
 ('loot_radio','加密电台',2900,.85,'rare'),('loot_processor','运算芯片',4400,.12,'rare'),
 ('loot_watch','机械腕表',6800,.18,'rare'),('loot_statue','旧城金像',12500,1.8,'legendary'),
 ('loot_documents','密封档案',3700,.35,'rare'),('loot_lens','光学镜片',2200,.3,'uncommon'),
 ('loot_fuel','燃料罐',1950,2.2,'uncommon'),('loot_scrap','合金零件',550,.7,'common'),
]:
    add(item_id,name,'loot','valuable',price,weight,'成功撤离后进入仓库，可在交易行出售换取游戏币。',rarity=rarity)


apply_balance(ITEMS)

def validate(require_models=False):
    ids={x['id'] for x in ITEMS}
    assert len(ids)==len(ITEMS),'duplicate IDs'
    guns=[x for x in ITEMS if x['kind']=='weapon']
    attachments=[x for x in ITEMS if x['kind']=='attachment']
    assert len(guns)==24
    assert len({json.dumps(g['slots'],sort_keys=True) for g in guns})==24,'weapon interface profiles must differ'
    assert len(attachments)>=120
    models=guns+attachments
    assert len({x.get('visual_model') for x in models})==169,'each gun/part must own a distinct model'
    for item in models:
        folder='weapons' if item['kind']=='weapon' else 'attachments'
        expected=f'res://assets/modular/{folder}/{item["id"]}.glb'
        assert item.get('visual_model')==expected,f'model declaration mismatch: {item["id"]}'
        if require_models:
            target=ROOT / expected.removeprefix('res://')
            assert target.is_file() and target.stat().st_size>100,f'missing/empty model: {target}'
    for family in ['smg','rifle','sniper','shotgun','machine_gun','pistol']:
        assert len([x for x in guns if x['category']==family])==4
    def compatible(g,a):
        return (a['slot'] in g['slots'] and bool(set(g['slots'][a['slot']])&set(a['interfaces']))
                and (not a.get('weapon_ids') or g['id'] in a['weapon_ids']))
    for a in attachments:
        assert any(compatible(g,a) for g in guns),f'unreachable attachment {a["id"]}'
        assert all(i in ids for i in a.get('weapon_ids',[])),a['id']
    for g in guns:
        for slot in g['slots']:
            assert any(a['slot']==slot and compatible(g,a) for a in attachments),(g['id'],slot)
        assert any(x['kind']=='ammo' and x['caliber']==g['caliber'] for x in ITEMS)
    assert len([x for x in ITEMS if x['category']=='helmet'])==12
    assert len([x for x in ITEMS if x['category']=='body_armor'])==12
    assert len([x for x in ITEMS if x['category']=='visor'])==4
    assert all('level' not in x for x in ITEMS if x['category'] in ['backpack','rig'])
    print(f'{len(ITEMS)} items; {len(guns)} weapons; {len(attachments)} attachments; all compatible and reachable')

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-models',action='store_true',help='Require all 169 exported GLB files to exist')
    options=parser.parse_args()
    validate(options.require_models)
    ROOT.joinpath('data/items.json').write_text(json.dumps(dict(schema_version=1,items=ITEMS),ensure_ascii=False,indent=2)+'\n')
    with ROOT.joinpath('docs/装备目录.csv').open('w',encoding='utf-8-sig',newline='') as f:
        writer=csv.writer(f)
        writer.writerow(['ID','名称','大类','类型','买价（游戏币）','卖价（游戏币）','重量kg','防护等级（背包和普通弹挂无等级）','容量格数','口径','插槽/面罩标准','接口','限定武器','属性/加成','独立3D模型','说明'])
        for x in ITEMS:
            dump=lambda value:json.dumps(value,ensure_ascii=False,separators=(',',':')) if isinstance(value,(dict,list)) else value
            writer.writerow([x['id'],x['name'],x['kind'],x['category'],x['price'],x['sell_price'],x['weight'],x.get('level',''),x.get('capacity',''),x.get('caliber',''),dump(x.get('slots',x.get('slot',x.get('visor_mount','')))),dump(x.get('interfaces','')),dump(x.get('weapon_ids','')),dump(x.get('stats',x.get('modifiers',dict(protection=x.get('protection',''),penetration=x.get('penetration',''),heal=x.get('heal',''))))),x.get('visual_model',''),x['description']])
