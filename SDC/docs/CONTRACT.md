# Module contract — 2026-10-16
Autoloads: Catalog (scripts/catalog.gd), GameState (scripts/game_state.gd).
Catalog.items Dictionary id -> item Dictionary. Common: id,name,kind,category,price,sell_price,weight,description.
kind weapon/attachment/armor/ammo/loot/consumable.
Weapons: caliber,slots Dictionary slot -> Array[String] interfaces, stats {damage,rpm,magazine,recoil,accuracy,ergonomics,range,noise}. Categories smg,rifle,sniper,shotgun,machine_gun,pistol. Slots muzzle,grip,stock,magazine,optic,laser,handguard. Weapons differ in actual interfaces/slots.
Attachments: slot,interfaces Array[String], optional weapon_ids restrictions,modifiers Dictionary additive stat changes.
Armor categories helmet,body_armor,backpack,armored_rig,visor; level (helmet/body_armor/visor only; backpack and armored_rig have NO LEVEL),protection,durability,capacity, visor_mount(s) for helmet/visor.
Ammo: caliber,penetration,damage_multiplier,stack_size.
Catalog methods: get_item(id)->Dictionary; by_kind(kind)->Array; compatible(weapon_id,attachment_id,slot="")->bool; visor_compatible(helmet_id,visor_id)->bool; weapon_stats(weapon_id,attachments:Dictionary={})->Dictionary; validate_catalog()->Array[String].

GameState properties: credits:int, stash:Dictionary[id->quantity], loadout:Dictionary[weapon,helmet,body_armor,backpack,armored_rig,visor,ammo -> id], attachments:Dictionary[slot->id], raid_active:bool, raid_loot:Dictionary, last_result:Dictionary, last_error:String.
Signals: changed (no args).
Methods: buy(id,quantity=1)->bool,sell(id,quantity=1)->bool,equip(id)->bool,unequip(slot)->bool,install_attachment(id)->bool,remove_attachment(slot)->bool,begin_raid()->bool,add_raid_loot(id,quantity=1)->bool,finish_raid(extracted:bool,details:Dictionary={})->Dictionary,save_game(),reset_progress(),carry_capacity()->float,raid_weight()->float,weapon_stats()->Dictionary.
State selects default starting weapon/ammo from catalog, initial cash ~18000, supplies. begin_raid reserves carried ammunition/meds and marks equipped gear at risk. finish_raid success transfers loot to stash; death loses carried gear and loot; both persist. UI can display last_error. Extra methods allowed; coordinate with gameplay.

RaidWorld (scripts/raid_world.gd) Node3D: signals hud_changed(info:Dictionary),raid_finished(extracted:bool,details:Dictionary).
start_raid() builds/reset world after GameState.begin_raid(); gameplay internally calls GameState.add_raid_loot and GameState.finish_raid before signal raid_finished.
Methods set_move(value:Vector2),set_aim(value:Vector2,firing:bool),reload_weapon(),interact(),use_medkit(),get_hud()->Dictionary.
World handles keyboard WASD, mouse aim + LMB shoot, R reload,F interact,E medkit. Controller x,y maps screen right/down projected onto the ground using camera basis; aim uses the same projection. Camera orthographic angled follows player. HUD info contains hp,max_hp,ammo,magazine,reserve,seconds,objective,nearby,loot_value,extract_progress plus weapon_name; optional minimap positions.
VirtualControls (scripts/virtual_controls.gd) Control: signals move_changed(Vector2),aim_changed(Vector2,bool),reload_pressed,interact_pressed,medkit_pressed; property enabled:bool. Dual finger independent joysticks; fire from right stick. Layout 1280x720 scalable and safe margins.

Main UI (scripts/main.gd) Control owns lobby tabs deployment/stash/market/workbench/catalog, RaidWorld + HUD + VirtualControls. Connect changed. Uses GameState public API above. root scene scenes/main.tscn. Root agent coordinates any conflicts. Color direction slate/charcoal, teal extraction accent, warm amber loot; Chinese UI with NotoSansSC font available assets/fonts/.
