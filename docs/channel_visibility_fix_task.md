# Channel Visibility Fix - Task Tracker

## Implementation Checklist

- [ ] 1. Thêm helper `_set_entity_visibility()`
- [ ] 2. Thêm helper `_sync_channel_entities_to_player()`
- [ ] 3. Thêm helper `_sync_entity_to_channel_players()`
- [ ] 4. Thêm RPC `spawn_player` / `despawn_player` ở Server World.gd
- [ ] 5. Thêm RPC handler ở Client World.gd
- [ ] 6. Refactor `_on_player_connected()` - sync existing players
- [ ] 7. Refactor `change_player_channel()` - full player visibility
- [ ] 8. Refactor `_on_player_disconnected()` - cleanup visibility
- [ ] 9. Test: 2 clients, chuyển kênh, verify visibility
- [ ] 10. Copy implementation plan to docs/
