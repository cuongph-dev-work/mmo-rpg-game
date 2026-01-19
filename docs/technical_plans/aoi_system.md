# Kế hoạch Triển khai AOI (Area of Interest) System

## 1. Mục tiêu
Tối ưu hóa băng thông mạng (Network Bandwidth) và CPU Client bằng cách chỉ gửi dữ liệu của các Entity (Player/Mob) nằm trong tầm nhìn của người chơi.

**Target:**
- Giảm Network Traffic từ O(N^2) xuống O(N * M) (M là số lượng entity trung bình trong AOI).
- Hỗ trợ 200-500 CCU trên một Map mà không lag.

## 2. Kiến trúc Kỹ thuật

### 2.1. Grid-based Spatial Hashing
Thay vì tính khoảng cách giữa tất cả players (Performance cost cao), chúng ta chia bản đồ thành lưới (Grid).

- **Grid Size:** `32x32` hoặc `64x64` pixels (tương đương kích thước màn hình client hoặc lớn hơn chút).
- **Logic:**
    - Player đứng ở ô `(x, y)`.
    - AOI = Ô `(x, y)` + 8 ô xung quanh (3x3 region).

### 2.2. Data Structures
Trong `ReplicationSystem` hoặc một `AOIManager` mới:

```gdscript
# Mapping từ Grid ID sang danh sách Entity IDs
# Key: Vector2i (Grid Coords) -> Value: Array[int] (Entity IDs)
var grid_entities: Dictionary = {}

# Mapping từ Entity ID sang Grid ID hiện tại (để detect di chuyển)
var entity_grid_pos: Dictionary = {}
```

## 3. Quy trình Xử lý (Implementation Steps)

### Phase 1: Grid Tracking (Theo dõi vị trí)
**Mục tiêu:** Luôn biết entity nào đang ở ô nào.

1.  **Hàm `update_entity_grid(entity_id, position)`:**
    *   Tính `new_grid_pos = floor(position / CELL_SIZE)`.
    *   So sánh với `old_grid_pos`.
    *   Nếu khác:
        *   Xóa ID khỏi `grid_entities[old_grid_pos]`.
        *   Thêm ID vào `grid_entities[new_grid_pos]`.
        *   Emit signal `grid_changed(entity_id, old, new)` (để xử lý visibility sau này).

### Phase 2: Visibility Management (Godot Integration)
**Mục tiêu:** Dùng `MultiplayerSynchronizer` để ẩn/hiện entity.

1.  **Tích hợp vào `ReplicationSystem`:**
    *   Lắng nghe signal di chuyển.
    *   Khi Player A di chuyển sang Grid mới:
        *   Tính danh sách 9 ô xung quanh (Interest Grids).
        *   Lấy danh sách **Visible Entities** trong 9 ô đó.
        *   Lấy danh sách **Old Visible Entities** (từ vị trí cũ).
        *   **Diffing:**
            *   Entity mới xuất hiện -> `sync.set_visibility_for(player_peer_id, true)`
            *   Entity bị khuất -> `sync.set_visibility_for(player_peer_id, false)`

### Phase 3: Optimization Refresh Rate
**Mục tiêu:** Không check mỗi frame.

1.  Move logic check Grid vào `Timer` hoặc `_physics_process` nhưng chỉ chạy mỗi 0.1s - 0.2s.
2.  Chỉ check những entity **Có di chuyển** (dirty flag).

## 4. Code Snippet (Dự kiến)

```gdscript
# Trong ReplicationSystem.gd

const GRID_SIZE = 1000 # Pixels (Khá lớn để giảm số lượng cell update)

func _process_aoi():
    for player in player_list:
        var grid_pos = Vector2i(player.position) / GRID_SIZE
        if grid_pos != player.last_grid_pos:
            _update_player_visibility(player, grid_pos)
            player.last_grid_pos = grid_pos

func _update_player_visibility(player, center_grid: Vector2i):
    var visible_peers = []
    
    # Quét 9 ô xung quanh
    for x in range(-1, 2):
        for y in range(-1, 2):
            var check_grid = center_grid + Vector2i(x, y)
            visible_peers.append_array( grid_entities.get(check_grid, []) )
            
    # Cập nhật Visibility cho MultiplayerSynchronizer
    for entity_id in all_entities:
        var is_visible = entity_id in visible_peers
        var sync_node = get_sync_node(entity_id)
        sync_node.set_visibility_for(player.peer_id, is_visible)
```

## 5. Lưu ý quan trọng
- **Global Entities:** Một số entity quan trọng (như Boss thế giới, Sự kiện toàn server) có thể cần `Always Visible`. Cần cơ chế whitelist.
- **Edge Cases:** Khi teleport, player di chuyển rất xa -> cần force update toàn bộ visibility.
- **Client Side:** Client vẫn cần xử lý việc "Node xuất hiện đột ngột" (Interpolation/Fade in) để tránh giật hình.
