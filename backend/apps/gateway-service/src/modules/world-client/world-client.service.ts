import { Injectable, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';
import { MapServerInfoDto } from '@mmo-rpg/shared';

@Injectable()
export class WorldClientService {
  private readonly logger = new Logger(WorldClientService.name);
  private readonly baseUrl: string;

  constructor(
    private readonly httpService: HttpService,
    private readonly configService: ConfigService,
  ) {
    this.baseUrl = this.configService.get<string>('WORLD_DIRECTORY_URL', 'http://localhost:3001');
  }

  async registerSession(userId: string, gatewayId: string): Promise<void> {
    try {
      await firstValueFrom(
        this.httpService.post(`${this.baseUrl}/session/online`, {
          userId,
          gatewayId,
        }),
      );
    } catch (error) {
      this.logger.error(`Failed to register session for user ${userId}: ${error.message}`);
    }
  }

  async removeSession(userId: string): Promise<void> {
    try {
      await firstValueFrom(
        this.httpService.delete(`${this.baseUrl}/session/${userId}`),
      );
    } catch (error) {
      this.logger.error(`Failed to remove session for user ${userId}: ${error.message}`);
    }
  }

  async getMapServer(mapId: number): Promise<MapServerInfoDto | null> {
    try {
      const response = await firstValueFrom(
        this.httpService.get<MapServerInfoDto>(`${this.baseUrl}/map-registry/map/${mapId}`),
      );
      return response.data;
    } catch (error) {
      this.logger.warn(`Failed to get map server for map ${mapId}: ${error.message}`);
      return null;
    }
  }
}
