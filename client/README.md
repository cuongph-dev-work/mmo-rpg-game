# MMO RPG Client - Godot 4.x

Client game cho MMO RPG được xây dựng bằng Godot Engine 4.x. Client kết nối trực tiếp với Map Server thông qua ENet multiplayer để xử lý gameplay và đồng bộ hóa thực thể thời gian thực.

## 📁 Cấu Trúc Thư Mục

```
client/
├── autoload/           # Singleton scripts (tự động load khi game khởi động)
├── entities/           # Các thực thể game (player, NPCs, mobs)
├── network/            # Xử lý mạng và giao thức
├── scenes/             # Các scene chính của game
├── utils/              # Tiện ích và helper functions
├── data/               # Dữ liệu game (maps, mobs, items)
└── project.godot       # File cấu hình project Godot
```

---

## 🎮 Kiến Trúc Tổng Quan

### Luồng Kết Nối & Khởi Động

```
Bootstrap/World Scene → Direct ENet Connection (port 3001)
    ↓
Connection Established → Server assigns Channel
    ↓
Spawn Player → Receive Mob Sync → Game Loop (Input/Position sync)
```

**Hiện tại:** Client kết nối trực tiếp đến Map Server qua ENet (không qua Gateway WebSocket)

---

## 📂 Chi Tiết Các Thư Mục

### 1. `autoload/` - Singleton Scripts

Các script được tự động load khi game khởi động và có thể truy cập từ bất kỳ đâu trong game.

#### **Autoload Singletons** (Nếu có)
Các script autoload được load tự động khi game khởi động.

**Thông thường bao gồm:**
- **Config**: Quản lý cấu hình (server IP, port, player settings)
- **Bus**: Event bus cho cross-component communication
- **Logger**: Logging system

**Sử dụng:**
```gdscript
# Ví dụ Config autoload
var server_ip = Config.server_ip  # "127.0.0.1"
var server_port = Config.server_port  # 3001

# Ví dụ Bus events
Bus.player_spawned.emit(player_id)
```

**Note:** Autoload configuration phụ thuộc vào implementation cụ thể của project.



---

### 2. `entities/` - Game Entities

Chứa các thực thể trong game như player, NPCs, mobs.

#### **base/Entity.gd**
Base class cho tất cả entities trong game.

**Thuộc tính:**
- `entity_id`: ID duy nhất của entity
- `entity_type`: Loại entity (player, npc, mob)

#### **base/NetworkEntity.gd**
Entity được đồng bộ với server qua network.

**Chức năng:**
- `apply_snapshot(data)`: Áp dụng dữ liệu từ server snapshot
- `interpolate_to(target_pos, rate)`: Smooth interpolation đến vị trí mục tiêu
- Server reconciliation để đồng bộ vị trí

#### **player/Player.gd**
Controller cho player character.

**Chức năng chính:**
- **Client-side prediction**: Di chuyển ngay lập tức dựa trên input
- **Input handling**: Capture input và gửi lên server
- **Server reconciliation**: Điều chỉnh vị trí dựa trên server snapshot
- **Smooth interpolation**: Làm mượt movement khi có chênh lệch nhỏ

**Thuộc tính:**
- `speed`: Tốc độ di chuyển (load từ Config)
- `input_sequence`: Số thứ tự input để server reconciliation
- `reconciliation_threshold`: Ngưỡng để snap position (50 pixels)

**Luồng hoạt động:**
```
Input → Client Prediction → Send to Server → Receive Snapshot → Reconcile Position
```

---

### 3. `network/` - Network Layer

#### **handlers/HelloHandler.gd**
Xử lý authentication flow với Gateway.

**Chức năng:**
- Gửi HELLO message để xác thực
- Nhận SESSION response với session_id và player_id
- Emit signals khi authentication thành công/thất bại

**Signals:**
- `session_established(session_id, player_id)`
- `hello_failed(reason)`

#### **handlers/SnapshotHandler.gd**
Xử lý SNAPSHOT messages từ server.

**Chức năng:**
- Parse snapshot data chứa trạng thái của tất cả entities
- Update entities trong game world
- Spawn/despawn entities khi cần

#### **protocols/**
Định nghĩa các message protocols và data structures.

---

### 4. `scenes/` - Game Scenes

#### **bootstrap/Bootstrap.gd**
Scene khởi động - entry point của game.

**Luồng hoạt động:**
1. **Khởi tạo**: Setup UI, kết nối signals
2. **Connect Gateway**: Kết nối đến Gateway server
3. **Authentication**: Gửi HELLO message
4. **Session Established**: Nhận session_id và player_id
5. **Join Map**: Request join map cụ thể (ví dụ: "meadow")
6. **Map Allocation**: Nhận shard URL và spawn position
7. **Connect Shard**: Kết nối đến MapShard server
8. **Load World**: Chuyển sang World scene

**UI Components:**
- `StatusLabel`: Hiển thị trạng thái kết nối hiện tại

#### **world/World.gd**
Scene game world chính.

**Chức năng:**
- Quản lý EntityContainer chứa tất cả entities
- Spawn player tại vị trí được server chỉ định
- Lắng nghe spawn_position_set event từ Bootstrap

**Cấu trúc:**
```
World (Node2D)
└── EntityContainer (Node2D)
    └── Player (CharacterBody2D)
    └── Other Entities...
```

---

### 5. `utils/` - Utilities

#### **Logger.gd (GameLogger)**
Hệ thống logging có cấu trúc.

**Log Levels:**
- `DEBUG`: Thông tin debug chi tiết
- `INFO`: Thông tin chung
- `WARN`: Cảnh báo
- `ERROR`: Lỗi

**Sử dụng:**
```gdscript
GameLogger.info("Player connected", "Network")
GameLogger.error("Failed to load map", "World")
GameLogger.set_level(GameLogger.Level.DEBUG)
```

---

## 🔄 Network Protocol (ENet Multiplayer)

### Connection Setup

**Client kết nối:**
```gdscript
var peer = ENetMultiplayerPeer.new()
var error = peer.create_client("127.0.0.1", 3001)
if error == OK:
    multiplayer.multiplayer_peer = peer
```

**Server auto-assign channel và sync entities.**

### Entity Synchronization

**MultiplayerSynchronizer:**
- Mỗi entity (Player, Mob) có MultiplayerSynchronizer node
- Server set visibility per player: `sync.set_visibility_for(peer_id, true/false)`
- Chỉ entities cùng channel được sync

**Player Input:**
```gdscript
@rpc("any_peer")
func receive_input(input: Vector2, seq: int):
    # Server receives và processes input
```

**Position Sync:**
```gdscript
# Synced variable trong Player/Mob
var server_sync_position: Vector2 = Vector2.ZERO
# MultiplayerSynchronizer tự động replicate từ server → clients
```

**Interpolation Tuning:**
- Server Tickrate: **30 Hz**.
- Client Interpolation Factor: `delta * 10` (Tuned for smoothness).
- Giúp movement mượt mà dù nhận data frequency thấp hơn render frequency (60Hz+).

---

## 🎯 Client-Side Prediction & Server Reconciliation

### Client-Side Prediction
Player di chuyển ngay lập tức khi nhận input, không đợi server response.

```gdscript
# Player.gd - _physics_process()
velocity = input_vector * speed
move_and_slide()  # Di chuyển ngay lập tức
```

### Server Reconciliation
Khi nhận snapshot từ server, client điều chỉnh vị trí nếu cần.

```gdscript
func apply_server_position(server_pos: Vector2):
    var distance = position.distance_to(server_pos)
    
    if distance > reconciliation_threshold:
        # Chênh lệch lớn → snap ngay
        position = server_pos
    else:
        # Chênh lệch nhỏ → smooth interpolation
        position = position.lerp(server_pos, 0.1)
```

**Lợi ích:**
- ✅ Movement mượt mà, responsive
- ✅ Giảm lag cảm nhận
- ✅ Đồng bộ chính xác với server

---

## ⚙️ Configuration

### `Config.gd`
Quản lý cấu hình game thông qua các biến static trong script (gateway URL, player speed, etc.).

### `project.godot`
Cấu hình Godot project:
- **Autoload singletons**: Net, Config, Bus
- **Input mapping**: move_left, move_right, move_up, move_down
- **Display settings**: Window size, vsync, etc.

---

## 🚀 Cách Chạy

1. **Cài đặt Godot 4.x**
   - Download từ [godotengine.org](https://godotengine.org/)
   - Godot 4.3+ recommended

2. **Mở project**
   ```bash
   cd client
   godot project.godot
   ```

3. **Đảm bảo server đang chạy trước**
   ```bash
   cd ../server
   ./start_server.sh  # Port 3001 by default
   ```

4. **Chạy game**
   - Nhấn F5 hoặc click nút Play
   - Client sẽ tự động kết nối đến `127.0.0.1:3001`
   - Server assign channel và sync mobs

---

## 🐛 Debug & Troubleshooting

### Common Issues

**1. Connection refused / Failed to connect**
```
ERROR: Cannot connect to server
```
- ✅ Kiểm tra server có đang chạy không: `cd server && ./start_server.sh`
- ✅ Verify IP và port đúng (mặc định `127.0.0.1:3001`)
- ✅ Check firewall settings

**2. Player không nhìn thấy mobs**
- Server có thể chưa sync mobs (check server logs)
- Player có thể ở channel khác với mobs
- MultiplayerSynchronizer visibility chưa được set

**3. Node not found errors**
- Đảm bảo scene structure đúng (World → EntityContainer)
- Check player scene có MultiplayerSynchronizer node

**4. Movement lag / jittering**
- Kiểm tra network latency
- Adjust interpolation settings
- Server reconciliation threshold có thể cần điều chỉnh

---

## 📚 Tài Liệu Tham Khảo

- [Godot 4 Documentation](https://docs.godotengine.org/en/stable/)
- [WebSocket API](https://docs.godotengine.org/en/stable/classes/class_websocketpeer.html)
- [Client-Side Prediction](https://www.gabrielgambetta.com/client-side-prediction-server-reconciliation.html)

---

## 📝 TODO & Roadmap

**Networking:**
- [ ] Implement smooth interpolation cho other players/mobs
- [ ] Client-side hit detection
- [ ] Lag compensation

**Gameplay:**
- [ ] Combat UI (target health bar, damage numbers)
- [ ] Inventory system
- [ ] Skills/abilities UI
- [ ] Experience bar & leveling UI

**Social:**
- [ ] Chat system
- [ ] Party UI
- [ ] Channel selection UI

**Polish:**
- [ ] Sound effects (footsteps, combat, ambient)
- [ ] Background music per map
- [ ] Visual effects (hit impacts, spells)
- [ ] Minimap

---

## 👥 Đóng Góp

Khi thêm tính năng mới:
1. Tuân thủ cấu trúc thư mục hiện tại
2. Sử dụng Bus.gd cho cross-component communication
3. Document code với comments `##`
4. Test kỹ network synchronization

---

**Version:** 1.0.0  
**Engine:** Godot 4.x  
**License:** MIT
