# Logs Directory

This directory contains all service logs for the MMO RPG Game.

## Log Files

- `auth.log` - Auth Service (NestJS, Port 3000)
- `world.log` - World Directory (NestJS, Port 3001)
- `gateway.log` - Gateway Service (NestJS WebSocket, Port 3002)
- `map_server.log` - Map Server (Godot Headless, Port 4001)

## Usage

### View all logs in real-time
```bash
../scripts/monitor-logs.sh
```

### View individual logs
```bash
tail -f auth.log
tail -f world.log
tail -f gateway.log
tail -f map_server.log
```

### Search logs
```bash
grep "error" *.log
grep "connected" gateway.log
grep "Registered" map_server.log
```

## Note
This directory is auto-created by `start-all.sh`.
Log files are not tracked in git (.gitignore).
