# Phase 3: Gateway Service (WebSocket)

## 1. Mục tiêu
Xây dựng **Gateway Service** đóng vai trò là cổng kết nối duy nhất (Singular Entry Point) cho WebSocket Client.
Nhiệm vụ chính:
1.  **Maintain Connection:** Giữ kết nối persistent với Client.
2.  **Authentication:** Xác thực User ngay từ bước Handshake (WS Connection).
3.  **Routing:** Điều hướng User vào Map Server (thông qua World Directory).
4.  **Features:** Xử lý Chat Global, Party, Guild (Layer ứng dụng).

## 2. Architecture & Flow

### 2.1. Handshake & Auth
1.  **Client** mở kết nối WS tới `ws://gateway-host:port?token=JWT`.
2.  **Gateway** chặn connection tại `handleConnection`:
    -   Verify JWT (dùng Secret từ Auth Service/Env).
    -   Nếu Valid: Decrypt lấy `user_id`.
    -   Gọi **World Directory** (`POST /session/online`) để đăng ký session.
    -   Lưu `user_id` vào socket instance.
    -   Nếu Invalid: Drop connection (`client.close()`).

### 2.2. Map Routing (Join Map)
1.  **Client** gửi message: `{ "cmd": "join_map", "data": { "map_id": 1 } }`.
2.  **Gateway**:
    -   Gọi **World Directory** (`GET /map-registry/map/1`) để lấy thông tin Server (`ip`, `port`).
    -   (Optional) Gọi **Map Server** (Internal API) để xin "Travel Ticket".
3.  **Gateway** trả về Client: `{ "cmd": "join_map_response", "data": { "ip": "...", "port": ..., "ticket": "..." } }`.
4.  **Client** ngắt kết nối gateway (hoặc giữ để chat) và connect UDP tới Map Server.

*Note: Trong kiến trúc này, chúng ta sẽ giữ kết nối WebSocket song song với UDP. UDP cho Movement/Skill, WS cho Chat/System.*

### 2.3. Disconnect
1.  **Client** disconnect (hoặc timeout).
2.  **Gateway** gọi **World Directory** (`DELETE /session/:user_id`) để xóa session.

## 3. Tech Stack Checklist
-   **Framework:** NestJS.
-   **WebSocket Library:** `@nestjs/platform-ws` (Sử dụng pure WebSocket adapter thay vì Socket.IO để tối ưu performance cho Game Clients).
-   **Communication:** `axios` (để gọi REST API sang World Directory).
-   **Shared:** Sử dụng lại `libs/shared` (DTOs, Constants).

## 4. Components Design

### 4.1. Gateway Module
-   `AppGateway` (WebSocketGateway): Class chính xử lý các sự kiện socket.
    -   `handleConnection(client, request)`: Auth logic.
    -   `handleDisconnect(client)`: Cleanup logic.
    -   `@SubscribeMessage('chat_message')`: Xử lý chat.
    -   `@SubscribeMessage('join_map')`: Xử lý chuyển map.

### 4.2. Helper Services
-   `AuthHelper`: Validate JWT Token.
-   `WorldClient`: Service wrapper để gọi API sang World Directory (Register Session, Get Map).

## 5. Protocol Specification (JSON)

### C -> S (Request)
```json
// Chat
{ "event": "chat", "data": { "message": "Hello World", "scope": "global" } }

// Join Map
{ "event": "join_map", "data": { "map_id": 1 } }
```

### S -> C (Response)
```json
// Chat Broadcast
{ "event": "chat", "data": { "sender": "Player1", "message": "Hello World" } }

// Join Map Result
{ "event": "join_map_success", "data": { "map_ip": "10.0.0.1", "map_port": 6000 } }

// Error
{ "event": "error", "data": { "code": "MAP_NOT_FOUND", "message": "..." } }
```

## 6. Các bước triển khai (Implementation Steps)

### Step 1: Project Setup
- [ ] Initialize NestJS App (`apps/gateway-service`).
- [ ] Install dependencies: `@nestjs/platform-ws`, `@nestjs/websockets`, `ws`.
- [ ] Config `tsconfig` & `webpack` (tương tự World Directory).

### Step 2: Auth Integration
- [ ] Implement `JwtStrategy` hoặc thủ công verify bằng `jsonwebtoken`.
- [ ] Implement `handleConnection`: Verify Token, Extract UserID.
- [ ] Test Connect bằng Postman (WS mode) hoặc `wscat`.

### Step 3: World Directory Integration
- [ ] Implement `WorldService` (HTTP Client).
- [ ] Gọi `Register Session` khi connect success.
- [ ] Gọi `Remove Session` khi disconnect.

### Step 4: Map Routing
- [ ] Implement `join_map` handler.
- [ ] Logic lookup map từ World Directory.
- [ ] Return connection info cho Client.

### Step 5: Basic Chat (MVP)
- [ ] Implement `chat` handler.
- [ ] Broadcast message tới tất cả connected clients (Global chat).

### Step 6: Verification
- [ ] Test flow: Connect -> Auth -> Session Created (Check Redis) -> Chat -> Routing -> Disconnect -> Session Removed.
