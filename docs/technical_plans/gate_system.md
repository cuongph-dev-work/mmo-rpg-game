# Hệ thống Gate (Cổng dịch chuyển)

## 1. Tổng quan
Hệ thống Gate cho phép người chơi di chuyển từ Map này sang Map khác.
Trong kiến trúc Sharded Server (Mỗi Map là 1 Server Process riêng biệt), việc "đi qua cổng" thực chất là quy trình:
1.  Disconnect khỏi Server Map hiện tại.
2.  Kết nối tới Server Map đích.

## 2. Thiết kế Dữ liệu (Data Design) - Centralized Approach

Theo yêu cầu quản lý tập trung, toàn bộ thông tin về Gate sẽ được lưu trong một file tổng `data/gates.json` (Registry), thay vì nằm rải rác trong từng Map Config.

### 2.1. File `data/gates.json` (Gate Registry)
Chứa thông tin vị trí, đích đến và điều kiện của tất cả các gate trong game.

```json
[
  {
    "id": 101,
    "name": "Gate to Forest",
    "belong_map_id": 1,          // Gate này nằm ở Map 1
    "position": [800, 600],      // Vị trí đặt cổng
    "target_map_id": 2,          // Đích đến
    "target_spawn_pos": [100, 100], // Vị trí xuất hiện bên kia
    "required_level": 1,
    "type": "portal_blue"        // Visual template (optional)
  },
  {
    "id": 201,
    "name": "Gate back to Village",
    "belong_map_id": 2,
    "position": [100, 100],
    "target_map_id": 1,
    "target_spawn_pos": [800, 550],
    "required_level": 1
  }
]
```

### 2.2. File `data/maps/map_X.json`
Map config chỉ cần tham chiếu ID của gate (và override size/visual nếu cần).

```json
{
  "map_id": 1,
  // ...
  "gates": [
    {
      "gate_id": 101, // Server sẽ lookup thông tin chi tiết từ connection_gates.json
      "size": [50, 50] // Override size hitbox (Area2D)
    }
  ]
}
```

### 2.3. Lợi ích
- **Quản lý tập trung:** Dễ dàng nhìn thấy luồng di chuyển (Topology) của toàn bộ thế giới trong 1 file.
- **Dễ bảo trì:** Muốn sửa đích đến (Target) không cần sửa file Map.

## 3. Kiến trúc Server (Godot)

Chúng ta cần tạo một System mới: `GateSystem`.

### 3.1. Nhiệm vụ
- Đọc config `gates` từ `MapConfig`.
- Instantiate các `Area2D` (với `CollisionShape2D`) tại vị trí cổng.
- Lắng nghe signal `body_entered` để phát hiện Player.

### 3.2. Code Flow (Dự kiến)

```gdscript
# GateSystem.gd
func _setup_gates():
    for gate_data in config.gates:
        var area = Area2D.new()
        # Setup collision shape...
        area.body_entered.connect(_on_player_entered_gate.bind(gate_data))
        add_child(area)

func _on_player_entered_gate(body: Node, gate_data: Dictionary):
    var player_id = int(str(body.name))
    
    # 1. Validate (Level check, Combat check...)
    if not is_allowed_to_travel(player_id, gate_data):
        return

    # 2. Gửi lệnh chuyển map cho Client
    # Client sẽ xử lý việc disconnect và connect sang server mới
    rpc_id(player_id, "on_map_transfer_requested", 
        gate_data.target_map_id, 
        gate_data.target_spawn_pos
    )
```

## 4. Kiến trúc Client & Service Discovery

Client không thể tự biết IP/Port của Map 2. Quy trình "Xin địa chỉ" sẽ thông qua **Gateway Service**:

1.  **Trigger:** Client nhận RPC `on_map_transfer_requested(target_map_id)`.
2.  **Request:** Client gửi HTTP Packet `POST /api/matchmaking/join` (hoặc socket message) lên **Gateway**.
    *   Body: `{ "mapId": 2 }`
3.  **Resolution (Service Discovery):**
    *   Gateway gọi sang **World Directory Service** (hoặc check Redis).
    *   Tìm xem Server nào đang phụ trách Map 2 (Load Balancing).
    *   Trả về: `{ "ip": "10.0.0.5", "port": 3002, "ticket": "xyz" }`.
4.  **Connect:**
    *   Client disconnect Map 1.
    *   Client connect Map 2 với IP/Port và Ticket vừa nhận.

## 5. Các bước triển khai (Implementation Steps)

1.  **Backend/Config:** Thêm data `gates` vào JSON.
2.  **Server System:** Code `GateSystem.gd` để spawn Area2D.
3.  **Network Protocol:** Định nghĩa RPC `on_map_transfer_requested`.
4.  **Client:** Xử lý logic Reconnect.

## 7. Dynamic & Event Gates (Cổng sự kiện)
Ngoài các cổng cố định (Static Gates) nạp từ Config, hệ thống hỗ trợ **Dynamic Gates** phục vụ cho Events hoặc Admin Commands.

### 7.1. Workflow
1.  **Admin Panel / Game Event:** Gửi lệnh spawn gate tới Game Server (qua Redis PubSub hoặc API nội bộ).
2.  **Game Server:** Gọi `GateSystem.spawn_dynamic_gate(params)`.
3.  **Broadcast:** Thông báo cho tất cả Client trong vùng để hiển thị Visual (Cổng không gian mở ra).

### 7.2. Data Structure cho Dynamic Gate
```gdscript
var dynamic_gate_params = {
    "position": Vector2(1200, 1500),
    "target_map_id": 99,       # Map Event/Dungeon
    "duration_seconds": 300,   # Tồn tại trong 5 phút
    "allowed_min_level": 50,
    "max_players": 10          # Giới hạn số người vào
}
```

### 7.3. Implementation Logic
```gdscript
# GateSystem.gd

func spawn_dynamic_gate(params: Dictionary):
    var gate = area_scene.instantiate()
    gate.position = params.position
    
    # Setup properties
    gate.set_meta("gate_data", params)
    gate.set_meta("is_dynamic", true)
    
    # Auto Destroy timer
    if params.has("duration_seconds"):
        get_tree().create_timer(params.duration_seconds).timeout.connect(gate.queue_free)
        
    add_child(gate)
    
    # Notify Clients for VFX
    rpc("on_dynamic_gate_spawned", params.position, params.duration_seconds)
```

### 7.4. Admin Tool Integration
Admin Panel sẽ gửi JSON command tới Server:
`POST /api/server/{id}/spawn_gate`
Body:
```json
{
  "x": 100, "y": 100,
  "target_map": 2,
  "duration": 600
}
```
Lệnh này được chuyển tiếp vào Game Server Process để thực thi ngay lập tức (Runtime).
