import { Injectable, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { RedisService } from '../redis/redis.service';
import { REDIS_KEYS } from '@mmo-rpg/shared';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly redisService: RedisService,
  ) {}

  async validateToken(token: string): Promise<{ userId: string } | null> {
    try {
      const secret = this.configService.get<string>('JWT_SECRET');
      const payload = this.jwtService.verify(token, { secret });
      
      // Validate token version if present in payload
      if (payload.tokenVersion !== undefined) {
        const isValidVersion = await this.validateTokenVersion(payload.sub, payload.tokenVersion);
        if (!isValidVersion) {
          this.logger.warn(`Token version mismatch for user ${payload.sub}`);
          return null;
        }
      }
      
      return { userId: payload.sub };
    } catch (e) {
      this.logger.error(`Validation failed: ${e.message}`);
      return null;
    }
  }

  private async validateTokenVersion(userId: string, tokenVersion: number): Promise<boolean> {
    try {
      const redis = this.redisService.getClient();
      const key = REDIS_KEYS.TOKEN_VERSION(userId);
      
      const currentVersion = await redis.get(key);
      
      if (!currentVersion) {
        // No version stored means this is a legacy token or first login
        // For backwards compatibility, allow it
        return true;
      }
      
      return parseInt(currentVersion, 10) === tokenVersion;
    } catch (error) {
      this.logger.error(`Token version validation failed: ${error.message}`);
      // On Redis error, allow the connection (fail open for availability)
      return true;
    }
  }
}

