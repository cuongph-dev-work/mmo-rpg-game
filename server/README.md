# MMO RPG Game Server

Godot 4.5 Game Server cho MMO RPG với hệ thống Multi-Channel, Mob AI và Component-Based Architecture.

## 🎯 Kiến trúc Hệ thống

**Server Architecture:**
- **MapServer (Godot)**: Core game server với ENet multiplayer
- **Component System**: StatsComponent, MobAIComponent
- **Channel Isolation**: Hoàn toàn cô lập giữa các channels
- **Entity Management**: Players, Mobs với MultiplayerSynchronizer

**Network Flow:**
```
Client (ENet) → MapServer → Channel Assignment → Entity Sync
```

## 📁 Cấu trúc thư mục

```
server/
├── game/                        # Core game logic
│   ├── components/              # Entity components
│   │   ├── stats_component.gd   # HP, Defense, Damage system
│   │   └── mob_ai_component.gd  # AI FSM, Aggro, Pathfinding
│   │
│   ├── data/                    # Game data loaders
│   │   ├── map_data.gd          # Map definitions
│   │   └── mob_data.gd          # Mob templates
│   │
│   ├── game_server.gd            # Main server controller
│   ├── map.gd                   # Map + Channel management
│   ├── channel.gd               # Channel isolation logic
│   ├── player_manager.gd        # Player tracking
│   ├── player_entity.gd         # Player entity (CharacterBody2D)
│   └── mob_entity.gd            # Mob entity (CharacterBody2D)
│
├── scenes/                      # Godot scenes
│   ├── player/Player.tscn       # Player scene template
│   ├── mob/Mob.tscn             # Mob scene template
│   └── world/World.tscn         # World container scene
│
├── data/                        # JSON game data
│   ├── maps/
│   │   ├── map_1.json           # Forest map config
│   │   └── map_2.json           # Dragon's Lair config
│   └── mob_templates.json       # Mob definitions & AI configs
│
├── main.gd                      # Entry point
├── main.tscn                    # Main scene
├── project.godot                # Godot project config
└── start_server.sh              # Launch script
```

## 🚀 Cách chạy

### Chạy Game Server

```bash
# Default (Map 1, Port 3001)
./start_server.sh

# Chỉ định map và port
./start_server.sh 1 3001

# Map 2 trên port 3002
./start_server.sh 2 3002
```

Hoặc trực tiếp:
```bash
godot --headless --map-id=1 --port=3001
```

### Chạy nhiều servers

```bash
# Terminal 1: Map 1
./start_server.sh 1 3001

# Terminal 2: Map 2
./start_server.sh 2 3002

# Terminal 3: Map 3
./start_server.sh 3 3003
```

## 🗺️ Map Configuration

Mỗi map được định nghĩa trong file JSON:

**File:** `data/maps/map_<id>.json`

```json
{
	"map_id": 1,
	"map_name": "Forest Village",
	"max_channels": 3,
	"max_players_per_channel": 50,
	"scene_path": "res://scenes/maps/forest_village.tscn",
	"description": "A peaceful forest village where players start their journey"
}
```

**Các trường:**
- `map_id`: ID của map (phải khớp với tên file)
- `map_name`: Tên hiển thị
- `max_channels`: Số lượng channels
- `max_players_per_channel`: Max players mỗi channel
- `scene_path`: Đường dẫn scene (optional)
- `description`: Mô tả (optional)

### Maps hiện có

- **Map 1**: Forest Village (3 channels, 50 players/channel)
- **Map 2**: Dragon's Lair (5 channels, 30 players/channel)

## 🎮 Core Features

### 1. Channel Isolation System
**Hoàn toàn cô lập giữa các channels** - xem chi tiết tại [`docs/channel_isolation_system.md`](../docs/channel_isolation_system.md)

**4 Lớp Isolation:**
- ✅ **Network Visibility**: `MultiplayerSynchronizer.set_visibility_for()` 
- ✅ **AI Filtering**: Mobs chỉ aggro players cùng channel
- ✅ **Collision**: `collision_mask = 1` (chỉ với World)
- ✅ **RPC Targeting**: Chỉ gửi spawn/despawn cho players đúng channel

**Kết quả:**
- Players khác channel **KHÔNG** nhìn thấy nhau
- Mobs **KHÔNG** tấn công players khác channel
- **KHÔNG** collision cross-channel

### 2. Mob AI System
**Component-based AI với FSM** - xem chi tiết tại [`docs/mob_ai_system.md`](../docs/mob_ai_system.md)

**State Machine:**
- `IDLE`: Nghỉ ngơi, chờ đợi
- `PATROL`: Tuần tra ngẫu nhiên trong patrol_radius
- `CHASE`: Truy đuổi target với highest threat
- `RETURN`: Quay về spawn point, reset hate_table

**Aggression Behaviors:**
- **Passive**: Không bao giờ tấn công
- **Neutral**: Chỉ đánh trả khi bị tấn công
- **Hostile**: Tự động aggro trong aggro_range

**Threat System:**
- Hate table: `{ Entity → Threat }`
- 1 damage = 1 threat
- Hysteresis 10%: Target mới phải >110% threat để switch
- Auto-cleanup: Xóa entities khác channel

### 3. Component Architecture

#### StatsComponent (`game/components/stats_component.gd`)
```gdscript
- max_hp, current_hp
- defense
- take_damage(amount, attacker)
- Signals: damaged(amount, attacker), died()
```

#### MobAIComponent (`game/components/mob_ai_component.gd`)
```gdscript
- FSM: State enum + process functions
- Hate table: add_threat(), _update_target()
- Configs: aggro_range, chase_range, leash_range
- Behavior filtering: passive/neutral/hostile
```

### 4. Entity Management

**Players:**
- CharacterBody2D với `collision_mask = 1`
- Input buffering + sequence tracking
- `channel_id` property
- MultiplayerSynchronizer cho position sync

**Mobs:**
- Spawned từ `mob_templates.json`
- Component-based: Stats + AI
- Channel-specific spawning
- Respawn system với configurable timer
- Elite variants (2x HP, 1.5x ATK)

### 6. Tickrate & Network Performance

**Server Tickrate: 30 Hz**
- Cấu hình trong `project.godot`: `common/physics_ticks_per_second=30`
- **Lý do**:
  - Tiết kiệm 50% CPU & Bandwidth so với mặc định 60Hz.
  - Chuẩn mực cho MMO RPG (WoW ~20Hz, MOBA ~30Hz).

**Replication Strategy:**
- `Replication Interval`: **0** (Mặc định - Gửi mỗi Tick).
- Kết quả: Server gửi snapshot **30 lần/giây**.
- Client Interpolation: Đã tinh chỉnh (`delta * 10`) để hiển thị mượt mà với data 30Hz.

### 5. Performance Optimizations

**Channel Sleep:**
```gdscript
// Tắt mobs khi channel empty
if channel.get_player_count() == 0:
    mob.process_mode = PROCESS_MODE_DISABLED
```

**Network Bandwidth:**
- Visibility filtering: Chỉ sync entities cùng channel
- ~90% bandwidth savings với multi-channel

**Collision Optimization:**
- Entities không va chạm nhau → giảm physics calculations
- Chỉ collide với terrain (Layer 1)

## 🔌 Client Connection

Client kết nối trực tiếp đến Game Server:

```gdscript
# Client code
var peer = ENetMultiplayerPeer.new()
peer.create_client("127.0.0.1", 3001)
multiplayer.multiplayer_peer = peer
```

Server sẽ tự động:
1. Accept connection
2. Add player vào PlayerManager
3. Assign player vào channel available
4. Log connection info

## 📊 Monitoring & Logging

Server tự động log các hoạt động quan trọng:

**Startup:**
```
✅ Map Server started: Forest Village (ID: 1)
   Port: 3001
   Channels: 3
   Max players/channel: 50
   Waiting for players...

🧟 Spawning mobs from config for ALL channels...
   👉 Spawning for Channel 1
🧟 Spawned Mob 20000 (slime) at (100, 200) Group: 0 Channel: 1
🧠 AI Init: Aggro 200 Chase 400 Behavior: hostile
✅ Mob slime (Elite: false) Initialized with Components
```

**Player Connection:**
```
🎮 Player 123456 connected
✨ Spawned player node for 123456 at: /root/World/EntityContainer/123456
✅ Player 123456 assigned to Channel 1
DEBUG: Checking entities for sync to player 123456 (Channel 1)...
DEBUG: Synced 10 mobs to player 123456
```

**Channel Switch:**
```
� Player 123456 requested switch to Channel 2
   ✅ Switching 1 -> 2
   ✅ Switched and synced 8 new mobs
```

**Mob Death & Respawn:**
```
💀 Mob slime died
💀 Mob 20000 died (Group: 0). Scheduling respawn...
[After 5s]
🧟 Spawned Mob 20001 (slime) at (105, 195) Group: 0 Channel: 1
```

**Periodic Stats:**
```
📊 Stats: 5 players online
```

## 🛠️ Development

### Thêm Map mới

1. Tạo file JSON:
```bash
# data/maps/map_3.json
{
	"map_id": 3,
	"map_name": "Desert Oasis",
	"max_channels": 4,
	"max_players_per_channel": 40,
	"scene_path": "res://scenes/maps/desert_oasis.tscn",
	"description": "A mysterious oasis in the desert"
}
```

2. Start server:
```bash
./start_server.sh 3 3003
```

### Thay đổi Channel count

Chỉnh sửa `max_channels` trong file JSON và restart server.

### Thay đổi Port

```bash
./start_server.sh 1 9999  # Custom port
```

## 🔮 Roadmap

### ✅ Completed Features
- ✅ ENet multiplayer server
- ✅ Multi-channel system với hoàn toàn cô lập
- ✅ Component-based architecture (Stats, AI)
- ✅ Mob AI với FSM (4 states: IDLE, PATROL, CHASE, RETURN)
- ✅ Aggression behaviors (Passive, Neutral, Hostile)
- ✅ Hate table + threat system với hysteresis
- ✅ Channel-specific mob spawning
- ✅ Respawn system
- ✅ Elite mob variants
- ✅ Performance optimizations (channel sleep, visibility filtering)
- ✅ Player input buffering
- ✅ MultiplayerSynchronizer integration

### 🚧 In Progress
- [ ] Combat system (player attack mobs)
- [ ] Loot drops
- [ ] Experience & leveling

### 📋 Planned Features
- [ ] Flee behavior cho passive mobs
- [ ] Group AI (mobs gọi hỗ trợ)
- [ ] Patrol paths (thay vì random)
- [ ] Skill system cho mobs
- [ ] Boss mechanics
- [ ] World events
- [ ] Chat system
- [ ] Party system

## 📝 Technical Notes

- **ENet Protocol**: Direct client-server communication (port 3001+)
- **No authentication**: MVP accepts all connections without validation
- **Channel isolation**: 4 layers (network, AI, collision, RPC)
- **Component pattern**: Entities use composition (Stats + AI components)
- **Godot 4.5+**: Uses MultiplayerSynchronizer for entity sync
- **JSON configs**: Maps & mobs defined in data/ directory

## 📚 Documentation

Xem thêm tài liệu chi tiết:
- [`docs/mob_ai_system.md`](../docs/mob_ai_system.md) - AI FSM, behaviors, threat system
- [`docs/channel_isolation_system.md`](../docs/channel_isolation_system.md) - Channel isolation analysis

## 🐛 Troubleshooting

**Port already in use:**
```bash
# Kill process using port
lsof -ti:3001 | xargs kill -9

# Or use different port
./start_server.sh 1 3002
```

**Map config not found:**
- Check file exists: `data/maps/map_<id>.json`
- Server will use default config if file missing

**Players can't connect:**
- Check server is running
- Check port is correct
- Check firewall settings
