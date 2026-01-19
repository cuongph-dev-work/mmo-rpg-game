import { Injectable, Logger } from '@nestjs/common';
import { RedisService } from '../redis/redis.service';
import { UserSessionDto, REDIS_KEYS, REDIS_TTL } from '@mmo-rpg/shared';

@Injectable()
export class SessionService {
  private readonly logger = new Logger(SessionService.name);

  constructor(private redisService: RedisService) {}

  async setUserOnline(userId: string, gatewayId: string): Promise<void> {
    const redis = this.redisService.getClient();
    const key = REDIS_KEYS.USER_SESSION(userId);

    const sessionData: UserSessionDto = {
      userId,
      gatewayId,
      timestamp: new Date(),
    };

    await redis.set(key, JSON.stringify(sessionData), 'EX', REDIS_TTL.USER_SESSION);
    this.logger.log(`User ${userId} is now online on gateway ${gatewayId}`);
  }

  async setUserOffline(userId: string): Promise<void> {
    const redis = this.redisService.getClient();
    const key = REDIS_KEYS.USER_SESSION(userId);

    await redis.del(key);
    this.logger.log(`User ${userId} is now offline`);
  }

  async getUserSession(userId: string): Promise<UserSessionDto | null> {
    const redis = this.redisService.getClient();
    const key = REDIS_KEYS.USER_SESSION(userId);

    const data = await redis.get(key);
    return data ? JSON.parse(data) : null;
  }

  async isUserOnline(userId: string): Promise<boolean> {
    const redis = this.redisService.getClient();
    const key = REDIS_KEYS.USER_SESSION(userId);

    const exists = await redis.exists(key);
    return exists === 1;
  }

  async extendSession(userId: string): Promise<void> {
    const redis = this.redisService.getClient();
    const key = REDIS_KEYS.USER_SESSION(userId);

    const exists = await redis.exists(key);
    if (exists) {
      await redis.expire(key, REDIS_TTL.USER_SESSION);
    }
  }

  async getOnlineUserCount(): Promise<number> {
    const redis = this.redisService.getClient();
    const pattern = REDIS_KEYS.USER_SESSION('*');
    
    const keys = await redis.keys(pattern);
    return keys.length;
  }
}
