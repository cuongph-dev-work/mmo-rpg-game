import { Injectable, Logger, HttpException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';

export interface CharacterData {
  id: string;
  user_id: string;
  name: string;
  level: number;
  class_id: number;
  map_id: number;
  position: { x: number; y: number };
  stats: Record<string, any>;
}

@Injectable()
export class AuthApiService {
  private readonly logger = new Logger(AuthApiService.name);
  private readonly authServiceUrl: string;

  constructor(
    private readonly configService: ConfigService,
    private readonly httpService: HttpService,
  ) {
    this.authServiceUrl = this.configService.get<string>(
      'AUTH_SERVICE_URL',
      'http://localhost:3000',
    );
  }

  async getCharacterById(characterId: string): Promise<CharacterData> {
    try {
      const url = `${this.authServiceUrl}/characters/${characterId}/internal`;
      this.logger.log(`Fetching character from: ${url}`);

      const response = await firstValueFrom(
        this.httpService.get<CharacterData>(url),
      );

      return response.data;
    } catch (error) {
      this.logger.error(
        `Failed to fetch character ${characterId}: ${error.message}`,
      );
      throw new HttpException('Character not found', 404);
    }
  }

  async verifyCharacterOwnership(
    characterId: string,
    userId: string,
  ): Promise<boolean> {
    try {
      const character = await this.getCharacterById(characterId);
      this.logger.log(`Verifying ownership: Character UserID=${character.user_id}, Client UserID=${userId}`);
      
      // Strict equality check
      if (character.user_id !== userId) {
        this.logger.warn(`Ownership mismatch! '${character.user_id}' !== '${userId}'`);
        return false;
      }
      return true;
    } catch (error) {
      this.logger.error(
        `Failed to verify character ownership: ${error.message}`,
      );
      return false;
    }
  }
}
