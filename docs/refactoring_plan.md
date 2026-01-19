# Server Refactoring Plan: Modular Architecture

**Mục tiêu:** Chuyển đổi từ mô hình "God Class" (`map_server.gd` đang ôm đồm quá nhiều) sang mô hình **Modular Systems**. Giúp code dễ đọc, dễ mở rộng (Scalable) và dễ debug.

---

## 🏗️ Proposed Architecture

Cấu trúc thư mục mới đề xuất:

```
server/game/
├── core/
│   ├── GameServer.gd        # (Main Entry) Khởi tạo và kết nối các system
│   ├── NetworkManager.gd    # Quản lý ENet connection, signals peer connect/disconnect
│   └── EntityManager.gd     # Quản lý Node Container, lookup entity ID
├── managers/
│   ├── ChannelManager.gd    # logic Channel Isolation, Visibility, Switch Channel
│   └── PlayerManager.gd     # (Đã có) Quản lý data player
├── systems/
│   ├── MobSpawnerSystem.gd  # Logic đọc config map và spawn/respawn mobs
│   ├── CombatSystem.gd      # Xử lý Skill, Damage, Death (Server Auth)
│   ├── LootSystem.gd        # Xử lý Drop đồ, Inventory
│   └── ReplicationSystem.gd # (New) Snapshot Decoupling & Interest Management
└── components/              # Các thành phần gắn vào Entity (Node)
    ├── StatsComponent.gd
    ├── MobAIComponent.gd
    └── ...
```

---

## 🛠️ Step-by-Step Implementation

### Phase 1: Core Separation (Quan trọng nhất)

Tách các logic phức tạp ra khỏi `map_server.gd`.

#### 1. Extract `ChannelManager`
*   **Trách nhiệm:** Quản lý danh sách channels, logic `change_channel`, và logic `visibility` (ẩn/hiện entity).
*   **Code cần chuyển:**
    *   3 helper functions: `_set_entity_visibility`, `_sync_channel...`
    *   Hàm `change_player_channel` (Logic khó nhất).
    *   Hàm `_update_channel_processing` (Optimization).

#### 2. Extract `MobSpawnerSystem`
*   **Trách nhiệm:** Đọc `Map.config`, tính toán vị trí spawn, quản lý `next_mob_id`.
*   **Code cần chuyển:**
    *   `_spawn_mobs_from_config`
    *   `_spawn_mob_node`
    *   `next_mob_id` counter.

### Phase 1.5: Network Optimization (Future-proofing)

#### 1. Create `ReplicationSystem`
*   **Trách nhiệm:** Quản lý `Snapshot Decoupling`.
*   **Logic:**
    *   Chạy loop độc lập (hoặc trong physics process nhưng có timer).
    *   Điều khiển `MultiplayerSynchronizer` update rate.
    *   Quyết định tần số gửi tin dựa trên khoảng cách (LOD).
    *   *Note:* Tạm thời giữ Server Physics 60Hz, chuẩn bị nền tảng để Network chạy 20-30Hz.

### Phase 2: Game Logic Centralization

Chuyển logic game từ rải rác về Systems.

#### 1. Create `CombatSystem`
*   Thay vì Client gửi RPC thẳng vào Player/Mob để trừ máu (nếu có), Client gửi RPC vào `CombatSystem`.
*   System sẽ verify và gọi `StatsComponent.take_damage()`.

---

## 🔄 Dependency Injection Flow

`GameServer` (Root) sẽ đóng vai trò là **Service Locator** hoặc **Mediator**.

```gdscript
# GameServer.gd
var channel_manager: ChannelManager
var mob_spawner: MobSpawnerSystem

func _ready():
    # 1. Setup Managers
    channel_manager = ChannelManager.new()
    channel_manager.game_server = self
    add_child(channel_manager)
    
    # 2. Setup Systems
    mob_spawner = MobSpawnerSystem.new()
    mob_spawner.setup(map_instance, entity_container)
    add_child(mob_spawner)
    
    # 3. Start
    mob_spawner.spawn_initial_mobs()
```

---

## 📝 Lợi ích

1.  **Dễ đọc:** `GameServer.gd` sẽ chỉ còn khoảng 100 dòng code thay vì 500+ dòng.
2.  **Dễ sửa Channel:** Muốn sửa logic Visibility? Vào `ChannelManager.gd`. Không sợ lỡ tay xóa logic Spawn mob.
3.  **Tái sử dụng:** `MobSpawner` có thể dùng cho map khác hoặc event khác dễ dàng.

## ✅ Action Plan

1.  [x] Tạo thư mục `core/`, `managers/`, `systems/`.
2.  [x] Tạo script `ChannelManager.gd` và move code visibility sang.
3.  [x] Tạo script `MobSpawnerSystem.gd` và move code spawn sang.
4.  [x] Refactor `map_server.gd` để gọi 2 class trên.
5.  [x] Verify: Chạy lại server thấy hoạt động y hệt là thành công.
6.  [x] Tạo `NetworkManager.gd` và tách logic ENet.
7.  [x] Tạo `EntityManager.gd` và tách logic quản lý node.
8.  [x] Tạo `ReplicationSystem.gd` và tích hợp vào map server (Phase 1.5).
9.  [x] Tạo `CombatSystem.gd` và `LootSystem.gd` (Phase 2).
10. [x] Refactor hoàn tất: `GameServer.gd` (renamed from `map_server.gd`) đóng vai trò Orchestrator.
11. [x] Cleanup: Rename `map_server.gd` -> `GameServer.gd`.
12. [x] Cleanup: Move entity scripts to `game/entity/`.
13. [x] Cleanup: Move `player_manager.gd` -> `managers/`, `map.gd`, `channel.gd` -> `models/`.
14. [x] Cleanup: Rename all files to `snake_case` (Godot Best Practice).
15. [x] Verification: Fix Broken References in TCN files and run server successfully.

