import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { RedisService } from '../redis/redis.service';
import { RegisterMapServerDto, HeartbeatDto, MapServerInfoDto, REDIS_KEYS, REDIS_TTL } from '@mmo-rpg/shared';

@Injectable()
export class MapRegistryService {
  private readonly logger = new Logger(MapRegistryService.name);

  constructor(private redisService: RedisService) {}

  async register(dto: RegisterMapServerDto): Promise<MapServerInfoDto> {
    const redis = this.redisService.getClient();
    const key = REDIS_KEYS.MAP_SERVER(dto.id);

    const serverInfo: MapServerInfoDto = {
      ...dto,
      last_heartbeat: new Date(),
      current_players: 0,
      load: 0,
    };

    // Store server info with TTL
    await redis.set(key, JSON.stringify(serverInfo), 'EX', REDIS_TTL.MAP_SERVER);

    // Store map allocation (which server hosts which map)
    if (dto.supported_maps && dto.supported_maps.length > 0) {
      for (const mapId of dto.supported_maps) {
        const allocationKey = REDIS_KEYS.MAP_ALLOCATION(mapId);
        await redis.set(allocationKey, dto.id, 'EX', REDIS_TTL.MAP_SERVER);
      }
    }

    this.logger.log(`Map server "${dto.name}" (${dto.id}) registered at ${dto.ip}:${dto.port}`);
    return serverInfo;
  }

  async heartbeat(dto: HeartbeatDto): Promise<void> {
    const redis = this.redisService.getClient();
    const key = REDIS_KEYS.MAP_SERVER(dto.id);

    // Check if server exists
    const existingData = await redis.get(key);
    if (!existingData) {
      throw new NotFoundException(`Map server ${dto.id} not found. Must register first.`);
    }

    // Update server info
    const serverInfo: MapServerInfoDto = JSON.parse(existingData);
    serverInfo.last_heartbeat = new Date();
    if (dto.current_players !== undefined) serverInfo.current_players = dto.current_players;
    if (dto.load !== undefined) serverInfo.load = dto.load;

    // Refresh TTL
    await redis.set(key, JSON.stringify(serverInfo), 'EX', REDIS_TTL.MAP_SERVER);

    // Refresh map allocations TTL
    if (serverInfo.supported_maps) {
      for (const mapId of serverInfo.supported_maps) {
        const allocationKey = REDIS_KEYS.MAP_ALLOCATION(mapId);
        await redis.expire(allocationKey, REDIS_TTL.MAP_SERVER);
      }
    }

    this.logger.debug(`Heartbeat received from map server ${dto.id}`);
  }

  async findServerForMap(mapId: number): Promise<MapServerInfoDto | null> {
    const redis = this.redisService.getClient();
    const allocationKey = REDIS_KEYS.MAP_ALLOCATION(mapId);

    const serverId = await redis.get(allocationKey);
    if (!serverId) {
      return null;
    }

    const serverKey = REDIS_KEYS.MAP_SERVER(serverId);
    const serverData = await redis.get(serverKey);

    if (!serverData) {
      return null;
    }

    return JSON.parse(serverData);
  }

  async findServerById(serverId: string): Promise<MapServerInfoDto | null> {
    const redis = this.redisService.getClient();
    const key = REDIS_KEYS.MAP_SERVER(serverId);
    const data = await redis.get(key);

    return data ? JSON.parse(data) : null;
  }

  async listAllServers(): Promise<MapServerInfoDto[]> {
    const redis = this.redisService.getClient();
    const pattern = REDIS_KEYS.MAP_SERVER('*');
    
    const keys = await redis.keys(pattern);
    const servers: MapServerInfoDto[] = [];

    for (const key of keys) {
      const data = await redis.get(key);
      if (data) {
        servers.push(JSON.parse(data));
      }
    }

    return servers;
  }

  async unregister(serverId: string): Promise<void> {
    const redis = this.redisService.getClient();
    
    // Get server info to remove map allocations
    const serverInfo = await this.findServerById(serverId);
    if (serverInfo && serverInfo.supported_maps) {
      for (const mapId of serverInfo.supported_maps) {
        await redis.del(REDIS_KEYS.MAP_ALLOCATION(mapId));
      }
    }

    // Delete server key
    await redis.del(REDIS_KEYS.MAP_SERVER(serverId));
    
    this.logger.log(`Map server ${serverId} unregistered`);
  }
}
