# MMO RPG Game - System Architecture & Service Workflows

## System Overview

The MMO RPG system consists of 4 main services working together:

```mermaid
graph TB
    Client[Godot Client]
    Auth[Auth Service<br/>NestJS - Port 3000]
    WorldDir[World Directory<br/>NestJS - Port 3001]
    Gateway[Gateway Service<br/>NestJS WebSocket - Port 3002]
    MapServer[Map Server<br/>Godot Headless - Port 4001+]
    
    Client -->|HTTP: Login/Register| Auth
    Client -->|HTTP: Characters| Auth
    Client -->|WebSocket: Enter World| Gateway
    Client -->|ENet: Game Play| MapServer
    
    Gateway -->|HTTP: Verify Character| Auth
    Gateway -->|HTTP: Get Map Server| WorldDir
    
    MapServer -->|HTTP: Register/Heartbeat| WorldDir
    
    style Client fill:#e1f5ff
    style Auth fill:#fff4e1
    style WorldDir fill:#ffe1f5
    style Gateway fill:#e1ffe1
    style MapServer fill:#f5e1ff
```

---

## Service Details

### 1. Auth Service (Port 3000)
**Technology**: NestJS + Prisma + PostgreSQL  
**Responsibilities**:
- User authentication (register/login)
- Character management (CRUD)
- Character class data
- JWT token generation

**Key Endpoints**:
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/auth/register` | ❌ | Create new user account |
| POST | `/auth/login` | ❌ | Login and get JWT token |
| GET | `/characters` | ✅ | Get user's characters |
| POST | `/characters` | ✅ | Create new character |
| GET | `/characters/:id/internal` | ❌ | Internal: Get character for gateway |
| GET | `/character-classes` | ❌ | Get available classes |

**Environment Variables**:
```env
PORT=3000
DATABASE_URL=postgresql://...
JWT_SECRET=your-super-secret-jwt-key-change-this-in-production
```

---

### 2. World Directory (Port 3001)
**Technology**: NestJS + Redis  
**Responsibilities**:
- Map Server registry (discovery service)
- Session management (track online users)
- Map allocation for players

**Key Endpoints**:
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/map-registry/register` | ❌ | Map Server self-registration |
| POST | `/map-registry/heartbeat` | ❌ | Map Server health check |
| GET | `/map-registry/map/:mapId` | ❌ | Find server hosting a map |
| POST | `/session/online` | ❌ | Mark user online |
| DELETE | `/session/:userId` | ❌ | Remove user session |

**Environment Variables**:
```env
PORT=3001
REDIS_URL=redis://localhost:6379
```

---

### 3. Gateway Service (Port 3002)
**Technology**: NestJS + WebSocket (ws library)  
**Responsibilities**:
- WebSocket connection hub
- JWT validation for clients
- Character ownership verification
- Map allocation coordination

**WebSocket Messages**:
| Event | Direction | Payload | Description |
|-------|-----------|---------|-------------|
| `connect` | Client → Server | `?token=<JWT>` | Initial connection with auth |
| `welcome` | Server → Client | `{message}` | Connection confirmed |
| `enter_world` | Client → Server | `{character_id}` | Request to enter game world |
| `enter_world_success` | Server → Client | `{map_ip, map_port, ticket, spawn_pos}` | Map allocation result |
| `error` | Server → Client | `{code, message}` | Error notification |

**Environment Variables**:
```env
GATEWAY_PORT=3002
AUTH_SERVICE_URL=http://localhost:3000
WORLD_DIRECTORY_URL=http://localhost:3001
JWT_SECRET=your-super-secret-jwt-key-change-this-in-production
GATEWAY_ID=gateway-1
```

---

### 4. Map Server (Port 4001+)
**Technology**: Godot 4.x (Headless)  
**Responsibilities**:
- Game world simulation
- Player movement & combat
- Mob AI & spawning
- Physics & collision
- Channel isolation

**Self-Registration Flow**:
```json
POST http://localhost:3001/map-registry/register
{
  "id": "map-server-1",
  "name": "Map Server 1",
  "ip": "127.0.0.1",
  "port": 4001,
  "supported_maps": [1],
  "max_players": 100
}
```

**Heartbeat (every 15s)**:
```json
POST http://localhost:3001/map-registry/heartbeat
{
  "id": "map-server-1",
  "current_players": 5,
  "load": 5
}
```

**Environment Variables**:
```bash
WORLD_DIRECTORY_URL=http://localhost:3001  # Optional, defaults to localhost:3001
SERVER_IP=127.0.0.1  # Optional, defaults to 127.0.0.1
```

**Command Line Args**:
```bash
./start_server.sh <map_id> <port>
# Example: ./start_server.sh 1 4001
```

---

## Complete Workflows

### Workflow 1: User Registration & Login

```mermaid
sequenceDiagram
    participant Client
    participant Auth
    participant DB
    
    %% Registration
    Client->>Auth: POST /auth/register<br/>{username, password}
    Auth->>DB: Check if username exists
    alt Username taken
        Auth-->>Client: 409 Conflict
    else Available
        Auth->>DB: Create user (bcrypt hash password)
        Auth->>Auth: Generate JWT token
        Auth-->>Client: 201 Created<br/>{access_token, user_id}
        Client->>Client: Store token in GameState
    end
    
    %% Login
    Client->>Auth: POST /auth/login<br/>{username, password}
    Auth->>DB: Find user by username
    Auth->>Auth: Verify password (bcrypt.compare)
    alt Valid credentials
        Auth->>Auth: Generate JWT token
        Auth-->>Client: 200 OK<br/>{access_token, user_id}
        Client->>Client: Store token in GameState
    else Invalid
        Auth-->>Client: 401 Unauthorized
    end
```

---

### Workflow 2: Character Selection

```mermaid
sequenceDiagram
    participant Client
    participant Auth
    participant DB
    
    %% Fetch character classes
    Client->>Auth: GET /character-classes
    Auth->>DB: SELECT * FROM CharacterClass
    Auth-->>Client: 200 OK<br/>[{id, name, description}]
    
    %% Fetch user's characters
    Client->>Auth: GET /characters<br/>Header: Bearer <token>
    Auth->>Auth: Validate JWT, extract userId
    Auth->>DB: SELECT * FROM Character<br/>WHERE user_id = userId
    Auth-->>Client: 200 OK<br/>[{id, name, level, class_name}]
    
    %% Create new character
    Client->>Auth: POST /characters<br/>{name, class_id}
    Auth->>Auth: Validate JWT, extract userId
    Auth->>DB: INSERT INTO Character<br/>(user_id, name, class_id, ...)
    Auth-->>Client: 201 Created<br/>{character}
```

---

### Workflow 3: Enter World (Critical Flow)

```mermaid
sequenceDiagram
    participant Client
    participant Gateway
    participant Auth
    participant WorldDir
    participant MapServer
    
    %% WebSocket Connection
    Client->>Gateway: WebSocket connect<br/>ws://...?token=<JWT>
    Gateway->>Gateway: Validate JWT token
    alt Invalid token
        Gateway-->>Client: Close(1008, "Invalid token")
    else Valid
        Gateway->>WorldDir: POST /session/online<br/>{userId, gatewayId}
        Gateway-->>Client: {"event":"welcome"}
    end
    
    %% Enter World Request
    Client->>Gateway: {"event":"enter_world",<br/>"data":{"character_id":"..."}}
    
    %% Character Ownership Verification
    Gateway->>Auth: GET /characters/:id/internal
    Auth-->>Gateway: 200 OK<br/>{character data, user_id}
    Gateway->>Gateway: Verify userId matches JWT
    alt Not owner
        Gateway-->>Client: {"event":"error",<br/>"code":"FORBIDDEN"}
    end
    
    %% Map Allocation
    Gateway->>WorldDir: GET /map-registry/map/:mapId
    WorldDir->>WorldDir: Find registered Map Server
    alt No server found
        WorldDir-->>Gateway: 404 Not Found
        Gateway-->>Client: {"event":"error",<br/>"code":"MAP_NOT_FOUND"}
    else Server available
        WorldDir-->>Gateway: 200 OK<br/>{ip, port, id}
        
        %% Generate ticket (TODO: Real HMAC)
        Gateway->>Gateway: Generate ticket (mock)
        Gateway-->>Client: {"event":"enter_world_success",<br/>"data":{map_ip, map_port, ticket, spawn_pos}}
        
        %% Client connects to Map Server
        Client->>MapServer: ENet connect<br/>Send ticket
        MapServer->>MapServer: Validate ticket
        MapServer-->>Client: Spawn player
    end
```

---

### Workflow 4: Map Server Lifecycle

```mermaid
sequenceDiagram
    participant MapServer
    participant WorldDir
    participant Redis
    
    %% Startup & Registration
    MapServer->>MapServer: Parse args (map_id, port)
    MapServer->>MapServer: Load map config & spawn mobs
    MapServer->>WorldDir: POST /map-registry/register<br/>{id, name, ip, port, supported_maps}
    WorldDir->>Redis: SET map-server-1<br/>{...server info}<br/>EX 30
    WorldDir-->>MapServer: 201 Created
    MapServer->>MapServer: Start heartbeat timer (15s)
    
    %% Heartbeat Loop
    loop Every 15 seconds
        MapServer->>WorldDir: POST /map-registry/heartbeat<br/>{id, current_players, load}
        WorldDir->>Redis: EXPIRE map-server-1 30<br/>(Refresh TTL)
        alt Server found
            WorldDir-->>MapServer: 200 OK
        else Server not in registry
            WorldDir-->>MapServer: 404 Not Found
            MapServer->>MapServer: Re-register
        end
    end
    
    %% Shutdown
    MapServer->>WorldDir: DELETE /map-registry/server/:id
    WorldDir->>Redis: DEL map-server-1
```

---

## Key Technical Decisions

### Authentication
- **JWT Tokens**: Stateless auth, shared secret between Auth & Gateway
- **Secret**: `JWT_SECRET` env var (must match across services)
- **Token Payload**: `{userId: string, iat: number, exp: number}`

### Service Discovery
- **Registry**: World Directory acts as service registry
- **Discovery**: Gateway queries World Directory for Map Servers
- **Health Check**: Heartbeat every 15s, TTL 30s in Redis

### Map Server Registration
- **Self-Registration**: Map Servers register themselves on startup
- **Retry Logic**: Exponential backoff (5s, 10s, 15s... max 30s)
- **Max Retries**: 10 attempts
- **Auto-Recovery**: Re-register if heartbeat returns 404

### Data Flow
- **Authentication**: Client ↔ Auth (HTTP/REST)
- **Real-time**: Client ↔ Gateway (WebSocket)
- **Gameplay**: Client ↔ Map Server (ENet)
- **Service-to-Service**: HTTP/REST

---

## Port Summary

| Service | Port | Protocol | URL |
|---------|------|----------|-----|
| Auth Service | 3000 | HTTP | http://localhost:3000 |
| World Directory | 3001 | HTTP | http://localhost:3001 |
| Gateway Service | 3002 | WebSocket | ws://localhost:3002/ws |
| Map Server (Main) | 4001 | ENet | - |
| Map Server (Additional) | 4002+ | ENet | - |

---

## Startup Sequence

### Backend Services
```bash
cd backend
./scripts/start-dev.sh
```

This script:
1. Kills existing processes on ports 3000, 3001, 3002
2. Starts Auth Service (port 3000)
3. Starts World Directory (port 3001)
4. Starts Gateway Service (port 3002)
5. Logs to `logs/auth.log`, `logs/world.log`, `logs/gateway.log`

### Map Server
```bash
cd server
./start_server.sh 1 4001
```

This:
1. Starts Godot headless instance
2. Loads Map ID 1
3. Listens on port 4001
4. Registers with World Directory
5. Logs to `map_server.log`

### Client
```bash
# Open Godot Editor and run project
# OR export and run executable
```

Flow:
1. Login scene (main scene)
2. Character Select scene
3. World scene (connects to Map Server)

---

## Security Considerations

### Current (Development)
- JWT secret is shared via environment variables
- Mock tickets for map server auth
- No HTTPS/WSS (plain HTTP/WS)
- Passwords hashed with bcryptjs

### Production Requirements
- **HMAC Tickets**: Real cryptographic tickets for Map Server
- **HTTPS/WSS**: TLS encryption for all connections
- **JWT Rotation**: Short-lived tokens with refresh mechanism
- **Rate Limiting**: Protect against abuse
- **Input Validation**: Already implemented via class-validator
- **Secret Management**: Use vault (not env vars)

---

## Troubleshooting

### "FORBIDDEN - You do not own this character"
- **Cause**: `JwtAuthGuard` on `/characters/:id/internal`
- **Fix**: Remove guard from internal endpoint (already fixed)

### "MAP_NOT_FOUND"
- **Cause**: No Map Server registered for requested map
- **Fix**: Start Map Server with `./start_server.sh <map_id> <port>`

### Gateway fails to validate JWT
- **Cause**: `JWT_SECRET` mismatch between Auth & Gateway
- **Fix**: Ensure identical secret in both `.env` files

### Map Server registration fails
- **Cause**: World Directory not running or wrong URL
- **Fix**: Check World Directory is on port 3001
- **Fix**: Set `WORLD_DIRECTORY_URL` env var if needed

---

## Monitoring

### Logs
```bash
# Backend logs
tail -f backend/logs/auth.log
tail -f backend/logs/world.log
tail -f backend/logs/gateway.log

# Map Server log
tail -f server/map_server.log
```

### Key Log Messages
```
✅ Registered with World Directory successfully!  # Map Server OK
👋 Welcome message: Connected to Gateway         # Client connected
User <id> connected                               # Gateway accepted client
```

### Redis Monitoring
```bash
redis-cli
> KEYS map-server-*
> GET map-server-1
> TTL map-server-1
```
