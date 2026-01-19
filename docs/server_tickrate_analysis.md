# Server Tickrate Management - Technical Analysis

## 📊 Hiện trạng

### Tickrate hiện tại: **MẶC ĐỊNH GODOT**

**Kết luận:** Server **KHÔNG** có cấu hình tickrate tùy chỉnh. Đang sử dụng giá trị mặc định của Godot Engine.

---

## 🔍 Phân tích Chi tiết

### 1. Godot Engine Tickrate Defaults

Godot có 2 loại tick chính:

| Tick Type | Default Value | Mục đích |
|-----------|---------------|----------|
| **Physics Tick** | `60 ticks/s` | `_physics_process(delta)` - Game logic, movement, collision |
| **Render/Process Tick** | Variable (VSync) | `_process(delta)` - Rendering, UI updates |

**Server hiện tại:**
- Physics tick: **60 Hz** (mặc định)
- Process tick: ~60 Hz (theo VSync hoặc unlimited nếu headless)

### 2. Nơi Cấu hình Tickrate

#### [`project.godot`](file:///Users/cuongph/Workspace/mmo_rpg_game/server/project.godot)

```ini
; KHÔNG CÓ cấu hình physics_ticks_per_second
; → Sử dụng mặc định 60 FPS
```

**Cách thêm cấu hình:**
```ini
[physics]

common/physics_ticks_per_second=30  # Ví dụ: giảm xuống 30 TPS
```

#### Code (Runtime Configuration)

**Không tìm thấy** code nào set tickrate trong:
- ❌ `map_server.gd`
- ❌ `main.gd`
- ❌ Bất kỳ file `.gd` nào

**Nếu muốn set runtime:**
```gdscript
# Trong map_server.gd _ready()
Engine.physics_ticks_per_second = 30  # Server tick 30 Hz
```

---

## 🎮 Entities đang sử dụng Tick nào?

### Players ([`player_server.gd`](file:///Users/cuongph/Workspace/mmo_rpg_game/server/game/player_server.gd#L27))

```gdscript
func _physics_process(_delta):
    # Process input buffer
    # move_and_slide()
    # Update server_sync_position
```

**→ Chạy ở Physics Tick: 60 Hz**

### Mobs ([`mob_server.gd`](file:///Users/cuongph/Workspace/mmo_rpg_game/server/game/mob_server.gd#L91))

```gdscript
func _physics_process(delta):
    # AI logic
    velocity = ai_comp.physics_process(delta)
    move_and_slide()
    server_sync_position = position
```

**→ Chạy ở Physics Tick: 60 Hz**

### MapServer ([`map_server.gd`](file:///Users/cuongph/Workspace/mmo_rpg_game/server/game/map_server.gd#L419-L424))

```gdscript
func _process(_delta):
    # Log stats periodically
    if Engine.get_process_frames() % 600 == 0:  # Every 10 seconds
        var total_players = map_instance.get_total_player_count()
        if total_players > 0:
            print("📊 Stats: %d players online" % total_players)
```

**→ Chạy ở Process Tick: ~60 Hz (nhưng chỉ log mỗi 10s)**

---

## 📈 Hiệu năng Hiện tại

### Tính toán Bandwidth

**Giả định:**
- 60 ticks/s
- 1 player, 100 mobs trong cùng channel
- MultiplayerSynchronizer sync position mỗi tick

**Per-tick data:**
```
1 Player position: ~16 bytes (2x float64 for Vector2)
100 Mobs positions: ~1600 bytes
Total: ~1616 bytes/tick
```

**Bandwidth:**
```
1616 bytes × 60 ticks = ~96KB/s per client
```

**Với 50 players/channel:**
```
50 clients × 96KB/s = ~4.8 MB/s outbound
```

> [!WARNING]
> **Vấn đề:** Với 60 Hz, bandwidth rất cao nếu sync toàn bộ positions mỗi tick.
> 
> **Giải pháp hiện có:** MultiplayerSynchronizer có delta compression + chỉ sync entities visible (channel isolation).

---

## 🔧 Khuyến nghị Tối ưu

### 1. Giảm Tickrate xuống 20-30 Hz

**Lý do:**
- ✅ Giảm 50-66% bandwidth
- ✅ Giảm CPU usage
- ✅ Vẫn đủ smooth cho game type này (RPG, không phải FPS)
- ✅ Delta = 0.033s (30Hz) hoặc 0.05s (20Hz) vẫn acceptable

**Cách implement:**

#### Option 1: Project Settings (Recommended)

Thêm vào [`project.godot`](file:///Users/cuongph/Workspace/mmo_rpg_game/server/project.godot):

```ini
[physics]

common/physics_ticks_per_second=30
```

#### Option 2: Runtime Code

Trong [`map_server.gd:_ready()`](file:///Users/cuongph/Workspace/mmo_rpg_game/server/game/map_server.gd#L22):

```gdscript
func _ready():
    # Set server tickrate
    Engine.physics_ticks_per_second = 30  # 30 TPS
    
    # Existing code...
    map_id = get_map_id_from_args()
    port = get_port_from_args()
    # ...
```

### 2. Snapshot Rate Decoupling

**Ý tưởng:** Physics tick 60 Hz, nhưng chỉ broadcast snapshot 20 Hz.

```gdscript
# map_server.gd
var snapshot_rate: float = 20.0  # Hz
var snapshot_accumulator: float = 0.0

func _physics_process(delta):
    snapshot_accumulator += delta
    
    if snapshot_accumulator >= 1.0 / snapshot_rate:
        snapshot_accumulator = 0.0
        _broadcast_snapshot()

func _broadcast_snapshot():
    # Trigger MultiplayerSynchronizer sync
    # Or manual RPC broadcast positions
    pass
```

**Lợi ích:**
- Game logic vẫn 60 Hz (responsive AI, collision)
- Network chỉ 20 Hz (tiết kiệm bandwidth)

### 3. Interest Management

**Hiện có:** Channel isolation đã giảm ~90% bandwidth.

**Thêm:** Distance-based interest.

```gdscript
# Chỉ sync mobs trong bán kính 1000px quanh player
func should_sync_to_player(mob_pos: Vector2, player_pos: Vector2) -> bool:
    return mob_pos.distance_squared_to(player_pos) < 1000 * 1000
```

### 4. Delta Compression

**MultiplayerSynchronizer tự động làm:**
- Chỉ gửi khi position thay đổi
- Delta encoding (chỉ gửi diff, không phải absolute)

**Có thể cấu hình thêm:**
```gdscript
# Trong MultiplayerSynchronizer settings
sync_properties:
  - "position"  # Chỉ sync khi thay đổi > threshold
```

---

## 🧪 Testing & Profiling

### 1. Đo Actual Tickrate

Thêm vào [`map_server.gd`](file:///Users/cuongph/Workspace/mmo_rpg_game/server/game/map_server.gd):

```gdscript
var tick_counter: int = 0
var tick_timer: float = 0.0

func _physics_process(delta):
    tick_counter += 1
    tick_timer += delta
    
    if tick_timer >= 1.0:
        print("📈 Actual TPS: %d" % tick_counter)
        tick_counter = 0
        tick_timer = 0.0
```

### 2. Bandwidth Monitoring

```gdscript
# Monitor ENet bandwidth
func _process(_delta):
    if Engine.get_process_frames() % 60 == 0:  # Every second
        var peer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
        if peer:
            # ENet doesn't expose bandwidth directly
            # But we can estimate from packet count
            print("📊 Active peers: %d" % (peer.get_peer_count()))
```

### 3. Performance Metrics

```gdscript
func _ready():
    # Enable performance monitoring
    Performance.add_custom_monitor("game/active_mobs", func():
        return entity_container.get_child_count()
    )
    
    Performance.add_custom_monitor("game/active_channels", func():
        var active = 0
        for ch in map_instance.channels.values():
            if ch.get_player_count() > 0: active += 1
        return active
    )
```

---

## 📊 Comparative Analysis

### Tickrate thông dụng trong game servers:

| Game Type | Typical Tickrate | Ví dụ |
|-----------|------------------|-------|
| **FPS Competitive** | 64-128 Hz | CS:GO, Valorant |
| **FPS Casual** | 30-64 Hz | Battlefield, Call of Duty |
| **MOBA** | 20-30 Hz | League of Legends, Dota 2 |
| **MMO RPG** | 10-30 Hz | WoW (~20Hz), FF14 (~15Hz) |
| **Battle Royale** | 20-60 Hz | Fortnite, PUBG |

**Recommendation cho MMO RPG:** **20-30 Hz** là sweet spot.

---

## 🎯 Action Plan

### Immediate (Quick Wins)

1. **Set tickrate to 30 Hz** trong `project.godot`:
   ```ini
   [physics]
   common/physics_ticks_per_second=30
   ```

2. **Add tickrate logging** để verify:
   ```gdscript
   print("⚙️ Server tickrate: %d Hz" % Engine.physics_ticks_per_second)
   ```

### Short-term

3. **Profile bandwidth** với tool monitoring
4. **Test gameplay** ở 30 Hz vs 60 Hz
5. **Measure CPU usage** trước/sau thay đổi

### Long-term

6. **Snapshot rate decoupling** nếu cần tối ưu thêm
7. **Distance-based interest management**
8. **Adaptive tickrate** (tăng/giảm theo load)

---

## 📝 Tổng kết

### Hiện trạng:
- ❌ **KHÔNG có** cấu hình tickrate tùy chỉnh
- ✅ Đang dùng mặc định Godot: **60 Hz**
- ✅ `_physics_process()` cho Players/Mobs
- ✅ MultiplayerSynchronizer auto-sync

### Vấn đề tiềm ẩn:
- ⚠️ Bandwidth cao (60 Hz × nhiều entities)
- ⚠️ CPU usage cao không cần thiết
- ⚠️ Không tối ưu cho server MMO

### Giải pháp đề xuất:
1. **Giảm tickrate → 30 Hz** (giảm 50% bandwidth/CPU)
2. **Monitoring** actual performance
3. **Xem xét snapshot decoupling** nếu cần optimize thêm

### Code changes needed:

**File:** [`server/project.godot`](file:///Users/cuongph/Workspace/mmo_rpg_game/server/project.godot)
```diff
+ [physics]
+ 
+ common/physics_ticks_per_second=30
```

**File:** [`server/game/map_server.gd`](file:///Users/cuongph/Workspace/mmo_rpg_game/server/game/map_server.gd#L138-L146)
```diff
  print("✅ Map Server started: %s (ID: %d)" % [map_name, map_id])
  print("   Port: %d" % port)
+ print("   Tickrate: %d Hz" % Engine.physics_ticks_per_second)
  print("   Channels: %d" % map_instance.get_channel_count())
```
