#!/usr/bin/env python3
"""Seeded catalog-based economy scenarios, not observed player success rates."""
import json
import math
import random
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = json.loads((ROOT/'data/items.json').read_text())['items']
ITEMS = {x['id']:x for x in DATA}
RNG = random.Random(20261016)
LOOT = [x for x in DATA if x['kind']=='loot']
PARTS = [x for x in DATA if x['kind']=='attachment' and x['weight'] <= 1.5]
AMMO = ITEMS['ammo_9x19_fmj']
SAMPLES = 20000


def build_price(gun, parts=()):
    return ITEMS[gun]['price'] + sum(ITEMS[x]['price'] for x in parts)


def premium_build(gun_id):
    gun=ITEMS[gun_id]
    parts=[]
    for slot, interfaces in gun['slots'].items():
        choices=[x for x in PARTS if x['slot']==slot and set(interfaces).intersection(x['interfaces']) and (not x.get('weapon_ids') or gun_id in x['weapon_ids'])]
        if choices:
            parts.append(max(choices,key=lambda x:x['price'])['id'])
    return build_price(gun_id,parts)


def sample(crate_count, guards):
    # World container indices 1/3/5 have a part; index 1 also has a medical kit.
    indices = RNG.sample(range(7),crate_count)
    revenue = 0
    for index in indices + [7]*guards:
        revenue += RNG.choices(LOOT,weights=[x['drop_weight'] for x in LOOT])[0]['sell_price']
        revenue += RNG.randint(8,20)*AMMO['sell_price']
        if index % 2 == 1:
            revenue += RNG.choice(PARTS)['sell_price']
        if index == 1:
            revenue += ITEMS['medkit_field']['sell_price']
    return revenue


def scenario(label, crates, guards, rounds, medkits):
    values=sorted(sample(crates,guards) for _ in range(SAMPLES))
    consumables=rounds*AMMO['price']+medkits*ITEMS['medkit_field']['price']
    return dict(label=label,crates=crates,guards=guards,spent_rounds=rounds,spent_medkits=medkits,
        gross_p10=values[SAMPLES//10],gross_median=round(statistics.median(values)),gross_p90=values[SAMPLES*9//10],
        mean_gross=round(statistics.mean(values)),consumables=consumables,
        net_median=round(statistics.median(values))-consumables,
        net_mean=round(statistics.mean(values))-consumables)


def run():
    scenarios=[scenario('常规搜集',4,0,45,1),scenario('深度搜集',7,2,100,2)]
    upgrades={
        '入门握把':ITEMS['att_grip_vertical']['price'],
        '入门冲锋枪':ITEMS['weapon_swift9']['price'],
        '中档步枪':ITEMS['weapon_badger556']['price'],
        '高端精确步枪整枪':premium_build('weapon_osprey338'),
    }
    # Automatic full-build quotes remain authoritative; scenario includes only compatible examples.
    # A deliberately explicit budget loadout for risk assumptions, not a guaranteed return.
    budget_kit=build_price('weapon_swift9')+90*AMMO['price']+3*ITEMS['bandage_basic']['price']
    risk=[dict(assumed_success_rate=rate,expected_change_per_deployment=round(rate*scenarios[0]['net_mean']-(1-rate)*budget_kit)) for rate in (.5,.65,.8)]
    catalog_cost=sum(x['price'] for x in DATA if x['kind'] in ('weapon','attachment','armor'))
    common_net=scenarios[0]['net_median']
    report=dict(seed=20261016,samples_per_scenario=SAMPLES,assumptions='All sampled containers fully collected and sold; capacity sufficient; no resale of equipped gear. Success rates below are hypothetical, not measured.',
        scenarios=scenarios,prices=upgrades,successful_runs_at_common_median={k:math.ceil(v/common_net) for k,v in upgrades.items()},
        new_save_credits=12000,full_gun_part_armor_catalog_cost=catalog_cost,budget_kit_replacement=budget_kit,risk_sensitivity=risk,
        legendary_chance_per_container=round(sum(x['drop_weight'] for x in LOOT if x['rarity']=='legendary')/sum(x['drop_weight'] for x in LOOT),5))
    assert all(0<=x['sell_price']<x['price'] for x in DATA), 'Buying and selling must never create money'
    assert common_net>ITEMS['att_grip_vertical']['price'], 'A normal successful raid should afford a tangible upgrade'
    assert 1.5 < upgrades['中档步枪']/common_net < 5, 'Midrange guns need a few extractions'
    assert upgrades['高端精确步枪整枪']/common_net > 6, 'Premium full builds should require sustained progress'
    assert 12000+2*scenarios[1]['gross_p90'] < catalog_cost*.2, 'Two rich raids cannot clear out the equipment catalog'
    assert report['legendary_chance_per_container']<.01
    (ROOT/'docs/economy-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(report,ensure_ascii=False,indent=2))


if __name__=='__main__':
    run()
