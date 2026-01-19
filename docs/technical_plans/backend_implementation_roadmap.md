# Backend Implementation Roadmap

## Tech Stack
- **Languages:** TypeScript (NestJS), GDScript (Godot)
- **Databases:** PostgreSQL (Auth), Redis (Session/State)
- **Communication:** HTTP/REST, WebSocket, UDP

## Phase 1: Authentication Service (Auth)

**Mục tiêu:** Cho phép User đăng ký và đăng nhập, trả về JWT Token.

1.  **Project Setup:**
    -   Khởi tạo NestJS project: `nest new backend-auth`.
    -   Setup Docker Compose cho PostgreSQL & PgAdmin.
2.  **Database Design:**
    -   Table `users`: id, username, password_hash, email, created_at.
    -   Entity & Migration (TypeORM hoặc Prisma).
3.  **API Implementation:**
    -   `POST /auth/register`: Validate input -> Hash pass -> Save DB.
    -   `POST /auth/login`: Verify pass -> Sign JWT -> Return AccessToken.
4.  **Verification:**
    -   Test bằng Postman/Curl.

## Phase 2: World Directory Service (State)

**Mục tiêu:** Quản lý trạng thái các Server và Player Online.

1.  **Project Setup:**
    -   Khởi tạo NestJS project: `nest new backend-world-directory`.
    -   Setup Redis (Docker).
2.  **Core Logic:**
    -   **Server Regis:** API cho Map Server đăng ký IP/Port (Internal).
    -   **Service Discovery:** API cho Gateway hỏi IP của Map Server.
    -   **Session Storage:** Lưu `user_id -> gateway_id` để biết user đang kết nối vào gateway nào.
3.  **Integration:**
    -   Viết Client Library (SDK) để các service khác gọi World Dir dễ dàng.

## Phase 3: Gateway Service (Connection)

**Mục tiêu:** Cổng kết nối WebSocket duy nhất cho Client.

1.  **Project Setup:**
    -   Khởi tạo NestJS project: `backend-gateway`.
    -   Cài đặt `ws`.
2.  **Authentication:**
    -   WebSocket Handshake: Validate JWT Token từ query param/header.
    -   Kick connection nếu Token invalid.
3.  **Routing Mechanics:**
    -   Implementation `on('join_map', map_id)`:
        -   Gọi World Directory lấy IP Map.
        -   Trả về IP/Port cho Client.
4.  **Chat System (MVP):**
    -   Implementation `on('chat_msg')` -> Broadcast cho room global.

## Phase 4: Godot Client Integration

**Mục tiêu:** Client kết nối được vào hệ thống mới.

1.  **HTTP Request:**
    -   Tạo UI Login.
    -   Code `HTTPRequest` node gọi API Login -> Lưu Token.
2.  **WebSocket Client:**
    -   Dùng `WebSocketPeer` connect vào Gateway với Token.
    -   Xử lý packet `JoinMapResponse`.
3.  **Map Transition:**
    -   Nhận IP -> Gọi `ENetMultiplayerPeer.create_client(ip, port)`.

## Phase 5: Deployment & DevOps (Optional MVP)
- Dockerize toàn bộ 3 services.
- Viết `docker-compose.yml` để chạy toàn bộ stack với 1 lệnh.
