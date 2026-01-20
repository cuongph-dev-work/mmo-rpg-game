import { Injectable, UnauthorizedException, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';
import { UsersService } from '../users/users.service';
import { RedisService } from '../redis/redis.service';
import { RegisterDto, LoginDto, LoginResponseDto, REDIS_KEYS } from '@mmo-rpg/shared';
import * as bcrypt from 'bcryptjs';

interface SessionStatusResponse {
  online: boolean;
  gatewayId?: string;
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  private readonly worldDirectoryUrl: string;

  constructor(
    private usersService: UsersService,
    private jwtService: JwtService,
    private redisService: RedisService,
    private httpService: HttpService,
    private configService: ConfigService,
  ) {
    this.worldDirectoryUrl = this.configService.get<string>(
      'WORLD_DIRECTORY_URL',
      'http://localhost:3001',
    );
  }

  async register(dto: RegisterDto): Promise<{ id: string; username: string }> {
    const user = await this.usersService.create(dto.username, dto.password, dto.email);
    
    return {
      id: user.id,
      username: user.username,
    };
  }

  async login(dto: LoginDto): Promise<LoginResponseDto> {
    const user = await this.validateUser(dto.username, dto.password);
    
    // Check if user already has an active session
    await this.kickExistingSession(user.id);
    
    // Increment token version (invalidates old tokens)
    const tokenVersion = await this.incrementTokenVersion(user.id);
    
    // Create JWT with token version
    const payload = { sub: user.id, username: user.username, tokenVersion };
    const access_token = this.jwtService.sign(payload);

    this.logger.log(`User ${user.username} logged in with token version ${tokenVersion}`);

    return {
      access_token,
      user_id: user.id,
    };
  }

  async validateUser(username: string, password: string) {
    const user = await this.usersService.findByUsername(username);

    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const isPasswordValid = await bcrypt.compare(password, user.password_hash);

    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    return user;
  }

  /**
   * Check if user has an existing session and kick them if so
   */
  private async kickExistingSession(userId: string): Promise<void> {
    try {
      // Check session status from world-directory
      const url = `${this.worldDirectoryUrl}/session/${userId}/status`;
      const response = await firstValueFrom(
        this.httpService.get<SessionStatusResponse>(url),
      );

      if (response.data.online && response.data.gatewayId) {
        this.logger.log(`User ${userId} already online on gateway ${response.data.gatewayId}, kicking...`);
        
        // Get gateway URL and send kick command
        const gatewayUrl = this.configService.get<string>(
          'GATEWAY_SERVICE_URL',
          'http://localhost:3002',
        );
        
        try {
          await firstValueFrom(
            this.httpService.post(`${gatewayUrl}/kick/${userId}`),
          );
          this.logger.log(`Kicked user ${userId} from gateway`);
        } catch (kickError) {
          // Gateway might not have the kick endpoint yet, or user already disconnected
          this.logger.warn(`Failed to kick user ${userId}: ${kickError.message}`);
        }
      }
    } catch (error) {
      // Session check failed (user not online or world-directory unavailable)
      this.logger.debug(`Session check for ${userId}: ${error.message}`);
    }
  }

  /**
   * Increment and return the new token version for a user
   */
  private async incrementTokenVersion(userId: string): Promise<number> {
    const redis = this.redisService.getClient();
    const key = REDIS_KEYS.TOKEN_VERSION(userId);
    
    // Increment and get new value (INCR is atomic)
    const newVersion = await redis.incr(key);
    
    // Set expiry (same as JWT expiry, e.g., 24h = 86400 seconds)
    await redis.expire(key, 86400);
    
    return newVersion;
  }

  /**
   * Validate if a token version is still valid (for gateway use)
   */
  async validateTokenVersion(userId: string, tokenVersion: number): Promise<boolean> {
    const redis = this.redisService.getClient();
    const key = REDIS_KEYS.TOKEN_VERSION(userId);
    
    const currentVersion = await redis.get(key);
    
    if (!currentVersion) {
      // No version stored, token is invalid
      return false;
    }
    
    return parseInt(currentVersion, 10) === tokenVersion;
  }
}
