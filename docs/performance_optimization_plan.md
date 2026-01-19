# Server Performance Optimization Plan (Future)

Tài liệu này phác thảo kế hoạch triển khai các kỹ thuật tối ưu hóa nâng cao cho Game Server. Dành cho giai đoạn khi lượng CCU (Concurrent Users) tăng cao hoặc khi gặp các vấn đề về nút thắt cổ chai (bottleneck) mạng/CPU.

---

## 📅 Phase 1: Performance Monitoring System

**Mục tiêu:** Hiểu rõ Server đang "khỏe" hay "yếu" thông qua các chỉ số thực tế (Metrics). Không đoán mò.

### 1. Các Metrics cần đo lường

| Metric | Ý nghĩa | Ngưỡng báo động (Cảnh báo) |
|--------|---------|----------------------------|
| **Actual TPS** (Ticks Per Second) | Số lần Physics Process chạy thực tế trong 1s | < 28 (Mục tiêu: 30) |
| **Frame Time (Physics)** | Thời gian CPU xử lý 1 tick | > 25ms (Mục tiêu: < 16ms) |
| **Process Memory** | RAM server đang chiếm dụng | > 1GB (tùy VPS) |
| **Active Mobs** | Số lượng quái đang active (không ngủ) | > 2000 |
| **Bandwidth (Out)** | Băng thông gửi đi trung bình | > 80 Mbps |

### 2. Giải pháp Kỹ thuật (Implementation)

Tạo một Autoload script `ServerMonitor.gd` trên Server.

```gdscript
# ServerMonitor.gd
extends Node

var tick_count: int = 0
var time_accumulator: float = 0.0
var current_tps: int = 0

func _physics_process(delta):
    tick_count += 1
    time_accumulator += delta
    
    if time_accumulator >= 1.0:
        current_tps = tick_count
        _log_metrics()
        tick_count = 0
        time_accumulator = 0.0

func _log_metrics():
    var mem_usage = OS.get_static_memory_usage() / 1024.0 / 1024.0
    var fps = Engine.get_frames_per_second()
    # Performance.TIME_PHYSICS_PROCESS trả về giây
    var physics_time = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000 
    
    print("------- SERVER HEALTH -------")
    print("TPS (Target 30): %d" % current_tps)
    print("Physics Time: %.2f ms" % physics_time)
    print("Memory: %.2f MB" % mem_usage)
    print("-----------------------------")
```

---

## 📅 Phase 2: Snapshot Decoupling (Tách rời chu kỳ gửi tin)

**Mục tiêu:** Giảm băng thông mạng (Network Usage) mà KHÔNG làm giảm độ chính xác của logic game (Physics).

**Vấn đề:** Khi Server chạy 30Hz, nó gửi 30 gói tin/giây. Nếu map có 1000 người, băng thông sẽ khổng lồ.

### 1. Nguyên lý Decoupling

Tách biệt tần số xử lý và tần số gửi tin:
*   **Physics Rate (CPU):** Giữ nguyên **30Hz** (hoặc tăng lên 60Hz cho game đối kháng).
*   **Snapshot Rate (Net):** Giảm xuống **15Hz** hoặc **10Hz** tùy theo khoảng cách của người chơi (LOD - Level of Detail).

### 2. Giải pháp 1: Global Rate Reduction (Đơn giản)

Sử dụng tính năng có sẵn của `MultiplayerSynchronizer`.

*   **Config:** Set `replication_interval` trong các file `.tscn` (Player/Mob).
*   **Giá trị:** `0.066` (tương đương 15Hz - gửi 1 lần mỗi 2 tick server).

```gdscript
# Ưu điểm: Cực dễ làm, chỉ cần sửa property.
# Nhược điểm: Áp dụng cho mọi entities, kể cả boss quan trọng.
```

### 3. Giải pháp 2: Adaptive/Interest Management (Nâng cao)

Chỉ gửi cập nhật thường xuyên cho những thứ quan trọng/gần người chơi.

*   **Gần (0-20m):** Gửi 30Hz (Mượt nhất).
*   **Xa (20-50m):** Gửi 10Hz (Tiết kiệm).
*   **Rất xa (>50m):** Không gửi hoặc 1Hz.

**Implementation Concept:**

```gdscript
# Trong MobServer.gd
func _physics_process(delta):
    # Logic di chuyển vẫn chạy 30Hz
    move_and_slide()
    
    # Custom Network Sync Logic
    var time_now = Time.get_ticks_msec()
    
    # Duyệt qua các players trong channel
    for player_id in view_subscribers:
        var dist = position.distance_squared_to(player_pos)
        
        # Quyết định có sync cho player này tick này không
        if dist < NEAR_DIST and tick % 1 == 0:
            force_sync_to(player_id)
        elif dist < FAR_DIST and tick % 3 == 0:
            force_sync_to(player_id)
```

*(Lưu ý: Godot 4 `MultiplayerSynchronizer` có hỗ trợ `set_visibility_for` nhưng chỉnh tần số per-client là phức tạp, cần viết custom spawner/sync).*

---

## 📅 Phase 3: Stress Testing

Trước khi optimize, cần làm server "sập" để biết điểm giới hạn.

**Kế hoạch test:**
1.  Viết script bot client (headless Godot client).
2.  Spawn 100 bots, cho chúng di chuyển ngẫu nhiên và spam skill.
3.  Spawn 50 bots vào cùng 1 channel, cùng 1 vị trí (Hotspot).
4.  Theo dõi Dashboard ở Phase 1 để xem khi nào TPS tụt xuống dưới 20.

---

## 📝 Action Items (Tóm tắt)

1.  [ ] Implement `ServerMonitor.gd` (Mức độ khó: Dễ).
2.  [ ] Chạy Stress Test với 50-100 bots giả lập.
3.  [ ] Nếu Bandwidth cao > CPU thấp: Implement **Solution 1 (Config Interval)**.
4.  [ ] Nếu CPU cao > Bandwidth thấp: Cần tối ưu code logic (GDScript -> C# hoặc C++ module).
