"""Versioned tuning pass shared by catalog generation and economy simulations."""
from math import sqrt

VELOCITY = dict(zip(
    ['9x19','45acp','57x28','556x45','545x39','762x39','300blk','308win','762x54r','338lm','12g','20g'],
    [360,280,715,890,880,715,640,820,830,900,410,410]))
# Farthest corner on the chest plane, measured from the player's normal follow
# position with the actual orthographic camera at 1680x720 (21:9).
# tests/test_screen_damage.gd verifies this against Camera3D projection.
SCREEN_REFERENCE_DISTANCE = 37.4176025390625
CONTACT_DAMAGE_REFERENCE = 22.8
SCREEN_EDGE_DAMAGE_REFERENCE = 20.5
FULL_DAMAGE_DISTANCE = 2.0
REFERENCE_CURVE_DISTANCE = (SCREEN_REFERENCE_DISTANCE-FULL_DAMAGE_DISTANCE) / sqrt(1-SCREEN_EDGE_DAMAGE_REFERENCE/CONTACT_DAMAGE_REFERENCE)
CURVE_DISTANCE_FACTORS = {
    'smg':1.0, 'rifle':1.25, 'sniper':1.75,
    'shotgun':.65, 'machine_gun':1.3, 'pistol':.90,
}
LOOT_WEIGHTS = {'common':12.0, 'uncommon':6.0, 'rare':2.5, 'legendary':.3}


def rounded(value, step=50):
    return max(step, int(value / step + .5) * step)


def apply_balance(items):
    for item in items:
        kind, old = item['kind'], item['price']
        if kind == 'weapon':
            scale = 1 if old <= 6000 else 1.15 if old <= 11000 else 1.35 if old <= 17000 else 1.6
            item['price'] = rounded(old * scale, 100)
            reach = item['stats']['range']
            item['ballistics'] = dict(muzzle_velocity=VELOCITY[item['caliber']],
                reference_velocity=VELOCITY[item['caliber']], full_damage_distance=FULL_DAMAGE_DISTANCE,
                screen_reference_distance=SCREEN_REFERENCE_DISTANCE,
                curve_distance=round(REFERENCE_CURVE_DISTANCE*(reach/23)*CURVE_DISTANCE_FACTORS[item['category']],6),
                falloff_exponent=2.0)
        elif kind == 'attachment':
            benefit = sum(abs(v) for v in item['modifiers'].values())
            item['price'] = rounded(old * (1 + min(.85, benefit/70)))
        elif kind == 'armor':
            scale = {1:.72,2:1.05,3:1.4,4:1.9}.get(item.get('level'),1.15)
            item['price'] = rounded(old * scale)
        elif kind == 'ammo':
            variant = item['id'].rsplit('_',1)[1]
            item['price'] = max(6,round(old * {'fmj':.65,'ap':1.15,'hp':.9}[variant]))
            heavy = item['caliber'] in ('308win','762x54r','338lm')
            shells = item['caliber'] in ('12g','20g')
            bonus = {'fmj':2.0,'ap':1.0,'hp':5.0}[variant] * (1.4 if heavy else 1.2 if shells else 1)
            item['ballistics'] = dict(bonus_damage=bonus,
                velocity_multiplier={'fmj':1.0,'ap':1.025,'hp':.985}[variant],
                power_multiplier={'fmj':1.0,'ap':1.008,'hp':.994}[variant],
                drag_multiplier={'fmj':1.0,'ap':.92,'hp':1.12}[variant])
            # Legacy save/catalog readers retain this field; combat uses the additive profile.
            item['damage_multiplier'] = 1.0
        elif kind == 'loot':
            item['drop_weight'] = LOOT_WEIGHTS[item['rarity']]
        if kind != 'loot':
            item['sell_price'] = round(item['price'] * (.25 if kind == 'ammo' else .45))
