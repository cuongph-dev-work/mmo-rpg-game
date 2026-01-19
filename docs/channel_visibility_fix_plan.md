# Channel Visibility Fix - Implementation Plan

## 🐛 Vấn đề hiện tại

Khi Player A chuyển từ Channel 1 sang Channel 2:

| Góc nhìn | Hiện tại | Mong đợi |
|----------|----------|----------|
| **Player A nhìn Players ở Channel 1** | ❌ Vẫn thấy | ✅ Không thấy |
| **Player A nhìn Players ở Channel 2** | ❌ Không thấy | ✅ Thấy |
| **Players Channel 1 nhìn A** | ❌ Vẫn thấy | ✅ Không thấy |
| **Players Channel 2 nhìn A** | ❌ Không thấy | ✅ Thấy |

**Root Cause:** Hàm `change_player_channel()` chỉ xử lý Mobs, không xử lý visibility của Players khác.

---

## 🎯 Mục tiêu

1. **Correctness:** Player-to-Player visibility đúng theo Channel.
2. **Clean Code:** Tách logic visibility thành helper functions.
3. **Optimize:** Giảm số lần duyệt vòng lặp, tận dụng Channel object.

---

## 📐 Thiết kế Solution

### 1. Tạo Helper Functions (DRY Principle)

Thay vì lặp code visibility ở nhiều chỗ, tạo các hàm tái sử dụng:

```gdscript
# map_server.gd

## Cập nhật visibility của 1 entity cho 1 player
func _set_entity_visibility(entity: Node, player_id: int, visible: bool):
    if entity.has_node("MultiplayerSynchronizer"):
        entity.get_node("MultiplayerSynchronizer").set_visibility_for(player_id, visible)

## Cập nhật visibility của tất cả entities trong 1 channel cho 1 player
func _sync_channel_entities_to_player(channel_id: int, player_id: int, visible: bool):
    for child in entity_container.get_children():
        var entity_channel = child.get("channel_id") if "channel_id" in child else -1
        if entity_channel == channel_id:
            _set_entity_visibility(child, player_id, visible)

## Cập nhật visibility của 1 entity cho tất cả players trong 1 channel
func _sync_entity_to_channel_players(entity: Node, channel_id: int, visible: bool):
    var channel = map_instance.get_channel(channel_id)
    if not channel: return
    for pid in channel.players.keys():
        _set_entity_visibility(entity, pid, visible)
```

### 2. Refactor `change_player_channel()`

**Luồng mới:**

```
1. Validation (giữ nguyên)
2. OLD CHANNEL CLEANUP:
   a. Hide Mobs of old channel from Player A       ← Có sẵn
   b. Hide Player A from OTHER players in old channel  ← MỚI
   c. Hide OTHER players of old channel from Player A  ← MỚI (RPC despawn)
   d. Remove from Channel object
   e. Update processing
3. NEW CHANNEL SETUP:
   a. Add to Channel object
   b. Update Player node channel_id
   c. Show Mobs of new channel to Player A         ← Có sẵn
   d. Show Player A to OTHER players in new channel   ← MỚI
   e. Show OTHER players of new channel to Player A   ← MỚI (RPC spawn)
   f. Update processing
```

### 3. Cần thêm RPC cho Player spawn/despawn

Hiện Client có `spawn_mob` / `despawn_mob`. Cần thêm:
- `spawn_player(id, pos)`
- `despawn_player(id)`

Hoặc dùng cơ chế có sẵn (MultiplayerSynchronizer + visibility change sẽ auto spawn/despawn?).

**Kiểm tra:** Godot 4 với `MultiplayerSynchronizer.set_visibility_for(pid, false)` sẽ:
- Ngừng sync data cho peer đó.
- **KHÔNG** tự động xóa node trên client (cần manual despawn hoặc MultiplayerSpawner).

**Kết luận:** Cần explicit RPC `spawn_player` / `despawn_player` tương tự mobs.

---

## 📝 Danh sách Thay đổi

### File: `server/game/map_server.gd`

| # | Thay đổi | Mô tả |
|---|----------|-------|
| 1 | Thêm `_set_entity_visibility()` | Helper đơn giản |
| 2 | Thêm `_sync_channel_entities_to_player()` | Batch visibility cho 1 player |
| 3 | Thêm `_sync_entity_to_channel_players()` | Batch visibility cho 1 entity |
| 4 | Refactor `_on_player_connected()` | Dùng helpers, thêm sync OTHER players |
| 5 | Refactor `change_player_channel()` | Xử lý Player visibility |
| 6 | Refactor `_on_player_disconnected()` | Đảm bảo hide từ tất cả |

### File: `server/scenes/world/World.gd`

| # | Thay đổi | Mô tả |
|---|----------|-------|
| 7 | Thêm `spawn_player()` RPC stub | Để forward xuống client |
| 8 | Thêm `despawn_player()` RPC stub | Để forward xuống client |

### File: `client/scenes/world/World.gd`

| # | Thay đổi | Mô tả |
|---|----------|-------|
| 9 | Thêm `spawn_player()` RPC handler | Spawn remote player khi server bảo |
| 10 | Thêm `despawn_player()` RPC handler | Despawn remote player khi server bảo |
| 11 | Refactor `_on_peer_connected` | Có thể không cần nữa nếu dùng RPC |

---

## 🔄 Code Flow sau khi Fix

### Player A (id=100) chuyển từ Channel 1 → Channel 2

```
SERVER: change_player_channel(100, 2)
│
├─ OLD CHANNEL (1) CLEANUP:
│   ├─ Hide Mobs[ch1] from 100         # set_visibility_for(100, false)
│   ├─ Hide Player[100] from [200,300] # set_visibility_for(200, false), ...
│   ├─ RPC despawn_player(100) to [200, 300]
│   ├─ Hide Players[200,300] from 100  # set_visibility_for(100, false)
│   ├─ RPC despawn_player(200) to 100
│   ├─ RPC despawn_player(300) to 100
│   └─ channel1.remove_player(100)
│
└─ NEW CHANNEL (2) SETUP:
    ├─ channel2.add_player(100)
    ├─ Show Mobs[ch2] to 100           # set_visibility_for(100, true)
    ├─ RPC spawn_mob(...) to 100
    ├─ Show Player[100] to [400,500]   # set_visibility_for(400, true), ...
    ├─ RPC spawn_player(100, pos) to [400, 500]
    ├─ Show Players[400,500] to 100
    ├─ RPC spawn_player(400, pos) to 100
    └─ RPC spawn_player(500, pos) to 100
```

---

## ⚡ Optimization Notes

1. **Batch RPC:** Thay vì gọi `rpc_id` cho từng entity, có thể gom thành 1 RPC với danh sách.
   - `spawn_entities([{id, pos, type}, ...])`
   - Giảm overhead network.

2. **Skip self:** Khi sync players, không gửi visibility/RPC cho chính mình.

3. **Cache channel.players.keys():** Lấy 1 lần, dùng nhiều chỗ.

4. **MultiplayerSpawner (Future):** Xem xét dùng `MultiplayerSpawner` để auto spawn/despawn khi visibility thay đổi. Hiện tại dùng manual RPC cho rõ ràng.

---

## ✅ Checklist Implementation

- [ ] 1. Thêm helper `_set_entity_visibility()`
- [ ] 2. Thêm helper `_sync_channel_entities_to_player()`
- [ ] 3. Thêm helper `_sync_entity_to_channel_players()`
- [ ] 4. Thêm RPC `spawn_player` / `despawn_player` ở Server World.gd
- [ ] 5. Thêm RPC handler ở Client World.gd
- [ ] 6. Refactor `_on_player_connected()` - sync existing players
- [ ] 7. Refactor `change_player_channel()` - full player visibility
- [ ] 8. Refactor `_on_player_disconnected()` - cleanup visibility
- [ ] 9. Test: 2 clients, chuyển kênh, verify visibility
- [ ] 10. Update docs nếu cần

---

## 🧪 Test Cases

| # | Kịch bản | Kết quả mong đợi |
|---|----------|------------------|
| 1 | A vào Channel 1, B vào Channel 1 | A thấy B, B thấy A |
| 2 | A vào Channel 1, B vào Channel 2 | A không thấy B, B không thấy A |
| 3 | A ở Ch1, B ở Ch1. B chuyển sang Ch2 | A không thấy B nữa, B không thấy A nữa |
| 4 | A ở Ch1, B ở Ch2. B chuyển sang Ch1 | A thấy B, B thấy A |
| 5 | A disconnect | Tất cả players khác không thấy A |
