# MMO RPG Game - Quick Start Scripts

This directory contains utility scripts to manage the entire game stack.

## 📜 Available Scripts

### `start-all.sh` (Root)
**Location**: `/start-all.sh`

Starts all services in one command:
- Auth Service (port 3000)
- World Directory (port 3001)
- Gateway Service (port 3002)
- Map Server (port 4001, Map ID 1)

**Usage**:
```bash
./start-all.sh
```

**Output**:
- All logs written to `logs/` directory
- PIDs saved for easy cleanup
- Service status summary displayed

---

### `stop-all.sh`
**Location**: `/scripts/stop-all.sh`

Stops all running services safely.

**Usage**:
```bash
./scripts/stop-all.sh
```

**What it does**:
- Kills processes on ports 3000, 3001, 3002, 4001
- Terminates all Godot processes
- Cleans up PID file

---

### `monitor-logs.sh`
**Location**: `/scripts/monitor-logs.sh`

Monitor all service logs in real-time.

**Usage**:
```bash
./scripts/monitor-logs.sh
```

**Features**:
- Uses `multitail` if available (split view)
- Falls back to standard `tail -f` otherwise
- Shows all 4 service logs simultaneously

**Alternative - Individual logs**:
```bash
tail -f logs/auth.log
tail -f logs/world.log
tail -f logs/gateway.log
tail -f logs/map_server.log
```

---

## 📂 Log Directory Structure

```
logs/
├── auth.log          # Auth Service logs
├── world.log         # World Directory logs
├── gateway.log       # Gateway Service logs
├── map_server.log    # Map Server (Godot) logs
└── .pids             # Saved PIDs (auto-generated)
```

---

## 🚀 Quick Start Workflow

### 1. Start Everything
```bash
./start-all.sh
```

### 2. Monitor Logs
In a new terminal:
```bash
./scripts/monitor-logs.sh
```

### 3. Run Client
- Open Godot client project
- Press F5 or click Play

### 4. Stop Everything
```bash
./scripts/stop-all.sh
```

---

## 🔧 Manual Service Management

If you need to start services individually:

### Backend Services
```bash
cd backend
npm run start:dev auth-service      # Port 3000
npm run start:dev world-directory   # Port 3001
npm run start:dev gateway-service   # Port 3002
```

### Map Server
```bash
cd server
./start_server.sh 1 4001  # Map ID, Port
```

---

## ⚠️ Troubleshooting

### Port Already in Use
If you see "address already in use" errors:
```bash
./scripts/stop-all.sh  # Clean up first
./start-all.sh         # Then restart
```

### Services Not Starting
Check individual logs:
```bash
tail -n 50 logs/auth.log
tail -n 50 logs/world.log
tail -n 50 logs/gateway.log
tail -n 50 logs/map_server.log
```

### Map Server Registration Failed
Check if World Directory is running:
```bash
curl http://localhost:3001/map-registry/servers
```

---

## 📊 Service Health Check

After starting, verify services are running:

```bash
# Auth Service
curl http://localhost:3000/

# World Directory  
curl http://localhost:3001/

# Gateway Service (WebSocket - should connect)
wscat -c ws://localhost:3002/ws?token=test

# Map Server (check logs)
tail -n 20 logs/map_server.log | grep "Registered with World Directory"
```

Expected output: `✅ Registered with World Directory successfully!`

---

## 🎯 Development Tips

### Run services in development mode
Services auto-reload on code changes (NestJS watch mode).

### View real-time player count
```bash
tail -f logs/map_server.log | grep "Players:"
```

### Monitor Gateway connections
```bash
tail -f logs/gateway.log | grep "connected"
```

### Check Map Server heartbeats
```bash
tail -f logs/world.log | grep "heartbeat"
```
