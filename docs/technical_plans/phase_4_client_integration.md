# Phase 4: Godot Client Integration Plan

## 1. Overview
**Goal**: Implement a complete flow from Client Login, Character Selection, to Entering the Game World via Gateway.

**Current State**:
- `auth-service`: Ready (Login, Register, Character CRUD).
- `gateway-service`: WebSocket Ready (Join Map basic logic).
- `world-directory`: Session & Map Registry Ready.
- `client`: Basic structure exists.

## 2. Detailed Implementation Steps

### Step 1: Login UI & Logic (Client)
*   **Scene**: `scenes/Login/Login.tscn` (Create if missing).
*   **Logic**: `scenes/Login/Login.gd`.
*   **Functionality**:
    *   Input fields: Username, Password.
    *   Buttons: Login, Register.
    *   **Network**: Use `HTTPRequest` to call `POST http://<AUTH_URL>/auth/login`.
    *   **Storage**: Save `access_token` and `user_id` to `AutoLoad/GameState.gd` (or `Auth.gd`).
*   **Transition**: On success -> Change Scene to `CharacterSelect`.

### Step 2: Character Selection UI (Client)
*   **Scene**: `scenes/CharacterSelect/CharacterSelect.tscn`.
*   **Logic**: `scenes/CharacterSelect/CharacterSelect.gd`.
*   **Functionality**:
    *   **Fetch**: On `_ready()`, call `GET http://<AUTH_URL>/characters` using stored Token.
    *   **Display**: List characters (Name, Level, Class).
    *   **Create**: Simple Popup to `POST /characters` with Name/Class.
    *   **Select**: Clicking "Enter World" sets `GameState.current_character` and triggers Gateway Connection.

### Step 3: Gateway Protocol Update (Backend)
*   **Context**: Currently `Gateway` only has `join_map`. We need `enter_world` to handle Character context.
*   **Update `app.gateway.ts`**:
    *   Add `@SubscribeMessage('enter_world')`.
    *   Payload: `{ character_id: string }`.
    *   **Logic**:
        *   Verify `character_id` belongs to `client.userId` (Call `auth-service` or query DB directly via a shared library - *Decision*: For MVP, Gateway will assume `userId` is valid from Token, and trust the `character_id` if we want speed, BUT better to verify. Let's start with basic verification).
        *   Fetch Character Data (Map ID, Position) from `auth-service` (or shared DB).
        *   Store `character_id` in `AuthenticatedSocket`.
        *   Automatically trigger `join_map` logic for the character's last saved Map ID.

### Step 4: World Connection (Client)
*   **Network Manager**: Update `autoload/Network.gd` (or `GatewayClient.gd`).
*   **Flow**:
    1.  `WebSocketPeer` connect to `ws://<GATEWAY_URL>?token=<TOKEN>`.
    2.  On `connected`: Send `{ event: "enter_world", data: { character_id: "..." } }`.
    3.  Handle `enter_world_success`:
        *   Contains: `map_ip`, `map_port`, `ticket`, `spawn_pos`.
    4.  **UDP Connection**:
        *   `ENetMultiplayerPeer` connect to `map_ip:map_port`.
        *   Send Identification (Ticket).

## 3. Task Breakdown

- [ ] **Client**: Create `Login` Scene & Script.
- [ ] **Client**: Create `CharacterSelect` Scene & Script.
- [ ] **Backend**: Update `GatewayService` to handle `enter_world`.
- [ ] **Client**: Implement `GatewayClient` connection logic.
- [ ] **Client**: Implement `World` scene loading based on Gateway response.
