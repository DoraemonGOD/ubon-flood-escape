# UBON FLOOD ESCAPE (Alpha — Early Access)

> **เล่นบนเว็บได้เลย:** https://doraemongod.github.io/ubon-flood-escape/
> เบราว์เซอร์บนคอมพิวเตอร์ (Chrome / Edge / Firefox) · ใช้คีย์บอร์ด · โหลดครั้งแรกประมาณ 40 MB
>
> เกมยังอยู่ในช่วง alpha: อาจเจอบัค ความสมดุลยังปรับอยู่ — ฝากบอกได้ที่หน้า Issues ของ repo นี้

**เรื่องย่อ:** น้ำท่วมฉับพลันกลางคืนที่อุบลราชธานี ถนนทุกสายถูกตัด คุณมีเวลา 60 วินาทีพาครอบครัวและขนของจำเป็นขึ้นเรือ
(Part 1) แล้วเอาชีวิตรอดบนเรือให้ถึงวันที่น้ำลด (Part 2 — แบบบันทึกรายวันคล้าย 60 Seconds)

**ปุ่ม (คอม):** WASD / ลูกศร เดิน · Shift วิ่ง · E หยิบของ / พาคน · Q โยนขึ้นเรือ · Esc หยุดเกม / ข้าม cutscene
**มือถือ:** เลือก "มือถือ / แท็บเล็ต" ตอนเปิดเกม (เปลี่ยนได้ที่ปุ่มมุมซ้ายล่างของเมนู) · ถือแนวนอน · จอยสติ๊กซ้าย (ดันสุด = วิ่ง) · ปุ่ม หยิบ / โยน / II

ฟอนต์: Noto Sans Thai, Noto Sans — SIL Open Font License 1.1 (`assets/fonts/OFL.txt`)

---

# สำหรับนักพัฒนา — Part 1: Scavenging

เกม 2D (Godot 4.7, GDScript, renderer: Compatibility) — ผู้เล่นมีเวลา 60 วินาทีวิ่งเก็บของในบ้านที่อุบลฯ
หยิบได้ครั้งละ 3 ชิ้น แล้ววิ่งไปโยนขึ้นเรือช่วยเหลือที่ระเบียง ของที่ขึ้นเรือเท่านั้นจะติดไปถึง Part 2

## วิธีเปิด / เล่น
1. เปิด Godot 4.7 → Import → เลือก `project.godot` ในโฟลเดอร์นี้
2. กด F5 (เริ่มที่ `scenes/main_menu/main_menu.tscn`)
3. ปุ่ม: **WASD / ลูกศร** เดิน · **Shift** วิ่ง · **E** หยิบของ · **Q** โยนของขึ้นเรือ · **Esc** หยุด/เล่นต่อ
   (Input Map ใช้ *physical key* จึงใช้ได้แม้เปิดแป้นพิมพ์ภาษาไทยอยู่)

## โครงสร้างโปรเจกต์
```
autoload/            GameState, ItemDatabase, Inventory   (ลงทะเบียนใน Project Settings → Globals แล้ว)
scenes/main_menu/    main_menu.tscn
scenes/scavenging/   scavenging.tscn (ฉากเล่นหลัก), house.tscn (แผนที่บ้าน), furniture.tscn (ฉากเฟอร์นิเจอร์ใช้ร่วม)
scenes/player/       player.tscn
scenes/items/        item_pickup.tscn (ไอเทมทุกชนิดใช้ฉากเดียว)
scenes/ui/           hud.tscn, inventory_bar.tscn, inventory_slot.tscn, pause_menu.tscn
scenes/summary/      summary.tscn
scripts/…            สคริปต์แยกตามหน้าที่ (player / inventory / items / game / ui)
resources/items/     ItemData 8 ไฟล์ (.tres)
resources/tilesets/  floor_tileset.tres
assets/…             ภาพ SVG ทุกชิ้น, เสียง .wav, theme UI
tools/               ตัวสร้างภาพ (Node.js) และตัวสร้างฉากบ้าน (GDScript)
tests/               ชุดทดสอบอัตโนมัติ + ตัวถ่ายภาพหน้าจอ
```

### Autoload (เพิ่มไว้ใน `project.godot` แล้ว ลำดับสำคัญ)
| ชื่อ | ไฟล์ | หน้าที่ |
|---|---|---|
| `GameState` | `autoload/game_state.gd` | เปลี่ยนฉาก, เก็บผลรอบล่าสุด, จุดต่อ Part 2 (`PART_2_SCENE`) |
| `ItemDatabase` | `autoload/item_database.gd` | หา `ItemData` จาก id |
| `Inventory` | `autoload/inventory_manager.gd` | **คลังถาวร = ของที่อยู่บนเรือแล้ว**: ช่อง, การซ้อน, น้ำหนัก — อยู่ข้ามฉาก |
| `BoatCargo` | `autoload/boat_cargo.gd` | บันทึกการส่งของขึ้นเรือ (id, ชนิด, ชื่อ, จำนวน, รวมที่ส่ง) แล้วบันทึกต่อลง `Inventory` |

### Signals หลัก
- `CarryInventory.carry_inventory_changed`, `CarryInventory.item_picked_up(item)`
- `Player.throw_started(count)`, `Player.nearest_pickup_changed`, `Player.boat_range_changed(boat)`, `Player.feedback(text, warning)`
- `BoatCargo.item_delivered(item, total)`, `BoatCargo.boat_cargo_changed`
- `Inventory.item_collected(item, amount)`, `Inventory.inventory_changed`, `Inventory.add_failed(item, reason)`
- `ScavengeTimer.timer_updated(time_left)`, `warning_started`, `time_up`
- `ScavengingLevel.scavenging_finished`
- `Player.nearest_pickup_changed(pickup)`

### Y-sort / มุมกล้อง
มุม oblique (top-down 3/4) — `World` และทุกโหนดใต้ `House` เปิด `y_sort_enabled`
**ตำแหน่ง (origin) ของทุกวัตถุ = จุดที่แตะพื้นด้านหน้า** ตัวละครจึงเดินอ้อมหลังเฟอร์นิเจอร์สูงได้ถูกต้อง
ผนังภายในเป็นแบบ cutaway (เตี้ย) ไม่บังตัวละคร ผนังด้านหลังสูงเต็ม

## ปรับค่าที่ใช้บ่อย (ผ่าน Inspector)
| อยากเปลี่ยน | เปิด | โหนด / ค่า |
|---|---|---|
| เวลา 60 วิ / เตือนที่ 15 วิ | `scavenging.tscn` | `ScavengeTimer` → `duration`, `warning_threshold` |
| ความจุเรือ (ช่อง) / น้ำหนักสูงสุด | `scavenging.tscn` | `ScavengingLevel` → `boat_hold_slots` (12), `max_boat_weight` (0 = ไม่จำกัด) |
| ถือได้กี่ชิ้นต่อรอบ | `scripts/inventory/carry_inventory.gd` | `MAX_CARRY_ITEMS = 3` (UI ปรับจำนวนช่องตามเอง) |
| ความเร็วเดิน / วิ่ง / ซูมกล้อง | `player.tscn` | `Player.move_speed`, `run_speed`, `Camera2D.zoom` |
| ความเร็ว/ความโค้งของการโยน | `scenes/items/throw_item.tscn` | `ThrowItem.duration`, `arc_height` |
| ชื่อ/คำอธิบาย/น้ำหนัก/ซ้อนได้กี่ชิ้นต่อช่อง | `resources/items/*.tres` | `ItemData` |
| จำนวนที่เก็บได้ / ตำแหน่งไอเทม | `house.tscn` → `Items/…` | `ItemPickup.quantity`, `elevation`, position |

### เพิ่มไอเทมชนิดใหม่
1. คัดลอก `resources/items/rope.tres` → แก้ `id` (ห้ามซ้ำ), ชื่อ, `icon`
2. เพิ่ม `preload(...)` ในรายการ `ITEMS` ของ `autoload/item_database.gd`
3. ลาก `scenes/items/item_pickup.tscn` ลงใน `house.tscn/Items` แล้วเลือก `item`

### เพิ่มเฟอร์นิเจอร์ / ห้อง
ลาก `scenes/scavenging/furniture.tscn` ลงใน `Props` → ตั้ง `texture` และ `footprint` (กล่องชนบนพื้น)
พื้นวาดด้วย TileMapLayer `Floor` (TileSet 64×48) — แก้ได้ใน TileMap editor
**หมายเหตุ:** `house.tscn` สร้างจาก `tools/build_level.gd` — แก้ในเอดิเตอร์ได้เลย
แต่ถ้ารัน build_level อีกครั้ง ไฟล์จะถูกเขียนทับ

## ระบบขนของขึ้นเรือ (Carry & Throw)
ลำดับ: หยิบ (E) → `CarryInventory` (ในมือ, สูงสุด 3) → โยน (Q) ในเขตเรือ → `ThrowItem` บินเป็นวิถีโค้ง
→ ตกถึงเรือ → `BoatCargo.deliver()` → `Inventory` → ลบออกจากมือ
- ของในมือ **ยังไม่นับ** จนกว่าจะตกถึงเรือ ถ้าหมดเวลาขณะถืออยู่ = ตกค้าง (หน้าสรุปแจ้งจำนวน)
- กัน E/Q ซ้ำ: Player มี state `FREE / PICKUP / THROW` + ItemPickup.`reserve()` + ไม่รับ key echo
- ยกเลิกก่อนจังหวะปล่อย (`set_controls_enabled(false)`, หมดเวลา) → ของยังอยู่ในมือ ไม่หาย ไม่นับซ้ำ
- ของที่ปล่อยออกจากมือแล้วจะบินต่อจนถึงเรือและนับตามปกติ แม้หมดเวลาระหว่างบิน
- Pause หยุดทั้ง Timer, AnimationPlayer และของที่กำลังบิน (`ScavengingLevel.process_mode = Pausable`)

### เรือ (`scenes/scavenging/boat.tscn`, script `scripts/game/boat.gd`)
| โหนดลูก | หน้าที่ | ปรับยังไง |
|---|---|---|
| `Sprite` | ภาพเรือ (ขอบล่าง/แนวน้ำ = origin) | เปลี่ยน texture ได้ |
| `Hull` (StaticBody2D) | กันเดินทะลุเรือ | ขยับ/ปรับขนาด shape |
| `InteractionZone` (Area2D, mask = player) | ยืนในกรอบนี้ถึงกด Q ได้ | **ลากกรอบให้ครอบพื้นที่ที่ผู้เล่นยืนได้** (ตอนนี้ครอบปลายระเบียงด้านขวา) |
| `DropPoint` (Marker2D) | จุดรับของบนพื้นเรือ ของแต่ละชิ้นกระจายรอบจุดนี้ (`DROP_SPREAD`) | วางกลางพื้นเรือ |
| `CargoPile` | ไอคอนของที่ส่งแล้วกองบนเรือ | — |
| `PromptAnchor` | ตำแหน่งป้าย "Q — โยนของขึ้นเรือ" | — |
ย้ายเรือทั้งลำ: เลือกโหนด `World/Boat` ใน `scavenging.tscn` แล้วขยับ (อย่าเปิด Y Sort ที่โหนด Boat)

### Animation ตัวละคร
- **AnimatedSprite2D** (`assets/characters/player_frames.tres`) — เฟรม 64×96, pivot ที่เท้า (32, 90) → `offset = (0, -42)`
  ทิศ: `down`, `up`, `side` (หันขวา; ซ้าย = `flip_h`)

  | ชุด | เฟรม | fps | วนซ้ำ |
  |---|---|---|---|
  | idle / carry_idle | 2 | 3 | ✓ |
  | walk / carry_walk | 4 (ก้าวซ้าย, กลาง, ก้าวขวา, กลาง) | 9 | ✓ |
  | run / carry_run | 4 (ก้าวยาว + เอนตัว) | 13 | ✓ |
  | pickup | 2 (ยื่นมือ, ย่อตัวจับของ) | — | AnimationPlayer คุม |
  | throw | 3 (ง้างแขน, ปล่อย, คืนท่า) | — | AnimationPlayer คุม |
- **AnimationPlayer** (`assets/characters/player_animations.tres`) — คลิป `pickup` (0.45 วิ), `throw_start` (0.16), `throw_release` (0.2), `throw_recover` (0.2)
  แต่ละคลิปมี track: `AnimatedSprite2D:frame` (เลือกเฟรมท่า), `:scale` (ย่อ/ยืดตัว), `:position` (ยุบตัว)
  และ Method track: `_on_pickup_grab_frame` ที่ 0.2 วิ (ของเข้ามือ), `_on_throw_release_frame` ที่ 0.05 วิ (ของหลุดมือ)
  เปิดแก้ใน Animation panel ได้ (เลือกโหนด AnimationPlayer ใน `player.tscn`)
- ถือหลายชิ้น: `throw_start` → `throw_release` → (`throw_start` ×2.5 เร็ว → `throw_release`)… → `throw_recover`
- เปลี่ยนเป็น Sprite Sheet จริง: แทนไฟล์ SVG ใน `assets/characters/player/` (ชื่อ `<ชุด>_<ทิศ>_<เลขเฟรม>.svg`)
  หรือแก้ SpriteFrames ใน Inspector — **คงชื่อชุดและจำนวนเฟรมไว้** (pickup = 2, throw = 3) ไม่งั้นต้องแก้ key ใน AnimationPlayer ด้วย
- ของที่ถือ: `Player/CarryStack` (Sprite2D 3 อัน) วาดไอคอนในอ้อมแขน, ของที่โยน: `scenes/items/throw_item.tscn` (แยกจากตัวละคร มีเงาบนพื้น)

## งานภาพ (Art pipeline)
ภาพทั้งหมดเป็น SVG แยกชิ้น สร้างจาก `tools/art/generate_art.mjs` ด้วย style guide เดียวกัน
(palette มัสตาร์ด/เขียวมะกอก/น้ำตาล/เบจ/ฟ้าหม่น/น้ำท่วม, เส้นขอบหมึก 3px สั่นแบบวาดมือ, เงาระบายทึบ)
ข้อความใน UI ทั้งหมดเป็น Label ของ Godot — ไม่มีตัวหนังสืออยู่ในภาพ

**ภาพเป็น placeholder ระดับใช้เล่นได้ ยังไม่ใช่ภาพวาดมือคุณภาพสุดท้าย**
แทนที่ด้วยภาพจริงได้ทันที: วาง PNG (พื้นโปร่งใส) ขนาดเดิมทับชื่อเดิม หรือเปลี่ยน `texture` ใน Inspector
- เฟอร์นิเจอร์: ขอบล่างด้านหน้าของวัตถุต้องอยู่สูงจากขอบภาพ 6px (`Furniture.BASE_PAD`)
- ตัวละคร: เฟรม 64×96 เท้าอยู่ที่ y=90 — แทนที่ไฟล์ใน `assets/characters/player/`
  หรือเปิด `assets/characters/player_frames.tres` (SpriteFrames) แล้วใส่ sprite sheet ใหม่
  ชื่อแอนิเมชันต้องคงไว้: `idle_down/up/side`, `walk_down/up/side` (ซ้าย = side + flip)
- สร้างภาพ SVG ใหม่ทั้งหมด: `node tools/art/generate_art.mjs`

ฟอนต์: `SystemFont` (Leelawadee UI → Tahoma → Noto Sans Thai → Sarabun) ใน `assets/ui/game_theme.tres`
ถ้าจะ export ไปเครื่องอื่น/มือถือ แนะนำวางไฟล์ฟอนต์ไทย (เช่น Kanit / Sarabun จาก Google Fonts, OFL)
ใน `assets/fonts/` แล้วเปลี่ยน `default_font` ใน theme เป็นไฟล์นั้น

## สร้างฉากบ้านใหม่ / ทดสอบ (command line)
```bash
# 1) import asset (ครั้งแรกหรือหลังสร้างภาพใหม่)
godot --headless --path . --import
# 2) สร้าง TileSet, SpriteFrames, เสียง และ house.tscn ใหม่
godot --headless --path . --script res://tools/build_level.gd
# 3) รันชุดทดสอบ (exit code = จำนวนข้อที่ไม่ผ่าน)
godot --headless --path . res://tests/test_part1.tscn
# 4) ถ่ายภาพหน้าจอ (ต้องมีหน้าต่าง)  --shot = menu | level | pause | summary
godot --path . res://tests/screenshot.tscn -- --shot=level --out=C:/temp/level.png
```
ชุดทดสอบ (81 จุดตรวจ) ครอบคลุม: เดิน/วิ่ง/หยุด, ชนผนังและขอบระเบียง, หยิบ 1–3 ชิ้นและชิ้นที่ 4 ไม่ได้,
Animation หยิบ/โยน, วิ่งพร้อมของ, Q นอกระยะ/ในระยะเรือ, Carry ลดทีละชิ้น, BoatCargo นับเฉพาะตอนตกถึงเรือ,
กด Q รัว, ยกเลิกก่อนปล่อย, Pause กลางการโยน, หมดเวลาแล้วหยิบ/โยนไม่ได้, หน้าสรุป, เริ่มใหม่แล้วรีเซ็ต, ฟอนต์ไทย
ภาพหน้าจอ: `--shot=throw --x=590 --y=870 --cargo=4 --wait=0.42` (ระหว่างโยน), `--shot=frames` (ดูทุกเฟรมตัวละคร)

## Cutscene เปิดเกม + ครอบครัว + ของสุ่มตำแหน่ง
- **Cutscene** (`scenes/cutscene/intro_cutscene.tscn`, script `scripts/cutscene/intro_cutscene.gd`) เล่นเมื่อกด "เริ่มเกม"
  ครอบครัวนั่งดูทีวี → ข่าวด่วน: เขื่อนระบายน้ำ, น้ำท่วมฉับพลันคืนนี้, ถนนทุกสายถูกตัด, เจ้าหน้าที่เข้าไม่ถึง → ไฟดับ ฟ้าผ่า น้ำเข้าบ้าน → "น้ำจะมาถึงใน 60 วินาที" → Part 1
  - คลิก / Space / Enter = บรรทัดถัดไป · Esc หรือปุ่ม "ข้าม" = ข้ามทั้งหมด · แก้บทพูดได้ที่ `_run()`
  - ปุ่ม "เล่นอีกครั้ง" (จากหน้าสรุป) ไม่เล่น cutscene ซ้ำ: `GameState.start_new_game(false)`
- **สมาชิกครอบครัว** แม่ / น้องฝน / ตาบุญ เป็นไอเทม `category = person`, `slot_size = 2` (`resources/items/family_*.tres`)
  - ต้องมีมือว่าง 2 ช่อง (CARRY 3 ช่อง → ถือของได้อีก 1 ชิ้น) และกินที่บนเรือ 2 ช่อง
  - ตอนจบ Part 1: `GameState.rescued_family` / `left_behind` → Part 2 เริ่มด้วย "คุณ + คนที่พามา" (`SurvivalState.start_with_family`)
- **สุ่มตำแหน่งของ** ทุกครั้งที่เริ่มเกม: `House.randomize_layout(rng)` สุ่มของไปที่จุด `ItemSpots` (28 จุด) และคนไปที่ `FamilySpots` (9 ที่นั่ง)
  - เพิ่มจุดใหม่: เพิ่ม Marker2D ใต้ `ItemSpots` ใน `tools/build_level.gd` (meta `elevation` = ความสูงบนเฟอร์นิเจอร์)
  - ปิดสุ่มได้ด้วย `randomize_layout = false` ที่ Scavenging (ชุดทดสอบใช้แบบนี้)
- **ดูของก่อนเริ่ม 5 วินาที**: กล้องซูมออกให้เห็นทั้งบ้าน + นับถอยหลัง แล้วเวลา 60 วินาทีจึงเริ่ม (กด E เพื่อเริ่มทันที)
  - ปรับที่ Scavenging → `look_seconds` (0 = ไม่มีช่วงดูของ)
- ท่าเดิน/วิ่งด้านข้าง: ขาแบบมีเข่า + แขนแกว่ง แก้ท่าได้ที่ `WALK_SIDE` / `RUN_SIDE` ใน `tools/art/generate_art.mjs`
- ภาพหน้าจอ: cutscene `--shot=intro --lines=5 --wait=3.5` · ช่วงดูของ `--shot=level --look=5` · ท่าตัวละครขยาย `--shot=frames --scale=2.2 --sets=walk,run --dirs=side`

## จุดเชื่อมต่อ Part 2
- `Inventory` (= ของบนเรือ) และ `BoatCargo` ไม่ถูกล้างตอนเข้าหน้าสรุป — Part 2 อ่าน `Inventory.get_slots()`, `BoatCargo.get_records()` ได้เลย
- ของที่ตกค้างในมือตอนหมดเวลา: `GameState.last_undelivered`
- ใช้ของ: `Inventory.remove_item(id, amount)` · เซฟ/โหลด: `to_save_data()` / `load_save_data(data)`
- ตั้ง `GameState.PART_2_SCENE = "res://scenes/survival/…tscn"` แล้วปุ่ม "ออกเดินทาง (Part 2)" ในหน้าสรุปจะเปิดใช้เอง

---

# Part 2 — เอาชีวิตรอดบนเรือ (บันทึกรายวันแบบ 60 Seconds)

คู่มือเกมฉบับเต็มสำหรับทดสอบ (เหตุการณ์ทั้งหมด ฉากจบ แผนทดสอบ): https://claude.ai/artifact/GpDrbFdLqPbhuT7Jk1tqbb

## วิธีเล่น
แต่ละวันเปิดสมุดบันทึกทางขวา มี 4 แท็บ แล้วกด **จบวัน** (ผลจะเขียนลงบันทึกของวันถัดไป)
1. **บันทึก** — เมื่อคืนเกิดอะไรขึ้น ใครหิว/กระหาย/ป่วย + ปุ่มเปิดวิทยุ (ถ้ามี)
2. **แบ่งเสบียง** — ติ๊กให้น้ำ / อาหาร / ยา รายคน (ยังไม่ถูกใช้จนกว่าจะจบวัน)
3. **เหตุการณ์** — เลือกวิธีรับมือ ตัวเลือกที่ต้องใช้ของจะมีไอคอนและ [ต้องมี…] ถ้าไม่มีจะกดไม่ได้
4. **ออกสำรวจ** — ส่งคนออกไปหาเสบียง 2 วัน พกไฟฉาย (เจอของมากขึ้น) / เชือก (ไม่หลงหาย) ไปได้

5. **ล่องเรือ** (ทุก 3 วัน) — เลือกจุดหมาย 1 ใน 5 สถานที่ แล้วเล่นมินิเกมกดปุ่มตามป้าย (WASD/ลูกศร) เก็บของ/หลบสิ่งกีดขวาง

ฉากหลังเปลี่ยนตามช่วงเวลา (เช้า/กลางวัน/เย็น/กลางคืน) อากาศ (ฝน พายุ ฟ้าแลบ หมอก) ระดับน้ำ (ขึ้นถึงวันที่ 9–15 แล้วลด) และสถานที่

**จบเกม (8 แบบ):** เรือกู้ภัยเห็นแสงไฟ · ชื่อในบัญชีผู้ประสบภัย · เรือกู้ภัยที่แล่นผ่าน · เฮลิคอปเตอร์ · เรือของวัด · รถอพยพบนสะพาน · น้ำลดวันที่ 30 · ทุกคนเสียชีวิต — เงื่อนไขอยู่ในคู่มือ
**ตาย:** ไม่มีน้ำ 6 วัน · ไม่มีอาหาร 9 วัน · ป่วยไม่ได้ยา 5 วัน · บาดเจ็บไม่ได้ยา 8 วัน

## ของแต่ละชิ้นมีประโยชน์ต่างกัน
| ของ | ใช้ทำอะไร |
|---|---|
| น้ำดื่ม / อาหารกระป๋อง | แบ่งให้รายคน (ไม่ให้ = กระหาย/หิวสะสม) · เช็ดตัวลดไข้ |
| ยาสามัญ | รักษาป่วย/บาดเจ็บ · แบ่งให้เพื่อนบ้าน (เขากลับมาตอบแทนน้ำ+อาหาร) |
| ไฟฉาย | ส่งสัญญาณเรือกู้ภัยตอนกลางคืน · ไล่ขโมย/งู · หาคนในความมืด · ออกสำรวจเจอของมากขึ้น (ใช้ไฟ 1 ครั้งต่อการใช้) |
| แบตเตอรี่ | เติมไฟให้ไฟฉาย/วิทยุอัตโนมัติเมื่อไฟหมด (1 ก้อน = 3 ครั้ง) |
| เชือก | ผูกเรือตอนพายุ · โยนช่วยคน · ทำเบ็ดตกปลา · ซ่อมเรือรั่ว · ออกสำรวจปลอดภัยขึ้น |
| วิทยุพกพา | ฟังข่าววันละครั้ง ครบ 4 ครั้งจะรู้ว่าเรือกู้ภัยมองหาแสงไฟ → ปลดล็อกเหตุการณ์ช่วยเหลือ |
| เอกสารสำคัญ | ลงทะเบียนกับเรือ อบต. → ได้น้ำ+อาหาร และเจ้าหน้าที่กลับมาเรียกชื่อพาไปช่วย · ฉากจบดีกว่า |

## ข้อมูลกลาง
| ข้อมูล | ที่อยู่ |
|---|---|
| เสบียง | Autoload `Inventory` (ของที่ตกถึงเรือใน Part 1) — ที่เดียว |
| คน วัน อากาศ ไฟในอุปกรณ์ flags ประวัติ การสำรวจ ตอนจบ | Autoload `SurvivalState` (`autoload/survival_state.gd`) — กติกาทั้งหมดอยู่ที่นี่ |
| ตัวเลขสมดุลเกม (วันตาย โอกาส ไฟ แบต การสำรวจ ข่าววิทยุ วันที่น้ำลด) | `resources/part2/survival_rules.tres` |
| เหตุการณ์ 38 แบบ | `resources/part2/events/*.tres` (EventData → EventChoice → ChoiceOutcome) — ผูกสถานที่ (`locations`), ช่วงเวลา (`time_of_day`), ตัวเลือกที่ต้องมีคน (`required_survivor`) / flag (`required_flag`) |
| สถานที่ 5 แห่ง | `resources/part2/locations/*.tres` (ชื่อ คำอธิบาย ของที่ลอยมาในมินิเกม สิ่งกีดขวาง) |
| ผู้รอดชีวิต | `resources/part2/survivors/*.tres` |
| ข้อมูลตัวอย่าง (ไม่มี Part 1) | `SurvivalState.DEFAULT_SUPPLIES` |

**เพิ่มเหตุการณ์ใหม่:** ก๊อปไฟล์ใน `resources/part2/events/` แก้ใน Inspector — โหลดอัตโนมัติ ไม่ต้องแก้โค้ด
- `min_day` / `max_day` / `weight` / `once` / `required_flags` / `blocked_flags` / `has_subject` ({subject})
- ตัวเลือก: `required_item` (+ `consumes_item`), ผลลัพธ์: `weight`, `journal_lines`, `supply_changes`, `lose_random_supplies`,
  `condition_target` + `condition`, `extra_hunger_days`, `shelter_nights`, `set_flags`, `ending`

## ไฟล์
| ไฟล์ | หน้าที่ |
|---|---|
| `scenes/part2/survival.tscn` + `scripts/part2/survival_game.gd` | ฉากเรือกลางน้ำ + สมุด + เปลี่ยนวัน + ฉากจบ |
| `scenes/ui/journal/journal.tscn` + `scripts/ui/journal/*.gd` | สมุด 4 แท็บ (report / ration / event / expedition) + `ending_panel` |
| `scenes/part2/survival_boat.tscn`, `survivor.tscn` | เรือโยก, คนบนเรือ (ซ่อนคนที่ออกสำรวจ/เสียชีวิต, ไอคอนสถานะเหนือหัว) |
| `scripts/part2/event_data.gd`, `event_choice.gd`, `choice_outcome.gd`, `survival_rules.gd`, `survivor_data.gd` | โครงสร้างข้อมูล |

เปิดฉาก: จบ Part 1 → ปุ่ม **ออกเดินทาง (Part 2)** · หรือเมนูหลัก → **ทดสอบ Part 2: เอาชีวิตรอด** · หรือเปิด `survival.tscn` กด F6

## ทดสอบ
```bash
godot --headless --path . res://tests/test_part2.tscn
```
180 จุดตรวจ: เสบียง ความตาย ตัวเลือกที่ต้องใช้ของ/คน/flag การแลกของ อุปกรณ์และแบต วิทยุ เหตุการณ์ตามสถานที่ ช่วงเวลา ระดับน้ำ
ล่องเรือ (ข้อมูล + มินิเกมเล่นอัตโนมัติ 100% / 0%) เส้นทางไปฉากจบแต่ละแบบ ออกสำรวจ วันที่ 30 UI สมุด 5 แท็บ ฉากจบ + ลองใหม่ ฟอนต์ไทย

จำลองสมดุลเกม (บอทเล่นอัตโนมัติ):
```bash
godot --headless --path . res://tests/balance_sim.tscn -- --runs=300 --data=part1
```
ผลล่าสุด (300 รอบ, บอทกดทัน 70%): ของครบจาก Part 1 รอด 92% (เฉลี่ยเหลือ 2.2/4 คน) · ข้อมูลตัวอย่าง 88% · มีแค่น้ำ+อาหารอย่างละ 2 รอด 59%
ภาพหน้าจอ: `godot --path . res://tests/screenshot.tscn -- --shot=survival --data=part1 --survivors=4 --page=2 --out=C:/temp/s.png`
(`--days=N` จำลองไปก่อน N วัน, `--event=<id>` บังคับเหตุการณ์, `--page=0..3`)
