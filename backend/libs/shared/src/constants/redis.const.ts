// Redis Key Patterns
export const REDIS_KEYS = {
  MAP_SERVER: (id: string) => `map_server:${id}`,
  MAP_ALLOCATION: (mapId: number) => `map_allocation:${mapId}`,
  USER_SESSION: (userId: string) => `session:${userId}`,
  GATEWAY: (gatewayId: string) => `gateway:${gatewayId}`,
  TOKEN_VERSION: (userId: string) => `token_version:${userId}`,
} as const;

// TTL Values (in seconds)
export const REDIS_TTL = {
  MAP_SERVER: 30, // 30 seconds - servers must heartbeat regularly
  USER_SESSION: 3600, // 1 hour - extend on activity
  GATEWAY: 60, // 1 minute - gateways heartbeat frequently
} as const;
