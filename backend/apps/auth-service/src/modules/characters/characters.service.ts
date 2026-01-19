import { Injectable, ConflictException, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { CreateCharacterDto, UpdateCharacterDto, CharacterResponseDto, SelectCharacterResponseDto, GAME_CONSTANTS } from '@mmo-rpg/shared';

@Injectable()
export class CharactersService {
  constructor(private prisma: PrismaService) {}

  async findAllByUser(userId: string): Promise<CharacterResponseDto[]> {
    const characters = await this.prisma.character.findMany({
      where: { user_id: userId },
      orderBy: { created_at: 'desc' },
    });

    return characters.map(char => this.toResponseDto(char));
  }

  async create(userId: string, dto: CreateCharacterDto): Promise<CharacterResponseDto> {
    // Check character count limit
    const userCharacterCount = await this.prisma.character.count({
      where: { user_id: userId },
    });

    if (userCharacterCount >= GAME_CONSTANTS.MAX_CHARACTERS_PER_USER) {
      throw new BadRequestException(`Maximum ${GAME_CONSTANTS.MAX_CHARACTERS_PER_USER} characters per user`);
    }

    // Check if character name is already taken
    const existingCharacter = await this.prisma.character.findUnique({
      where: { name: dto.name },
    });

    if (existingCharacter) {
      throw new ConflictException('Character name already taken');
    }

    // Create character with defaults
    const character = await this.prisma.character.create({
      data: {
        user_id: userId,
        name: dto.name,
        class_id: dto.class_id,
        appearance: dto.appearance || {},
        level: GAME_CONSTANTS.DEFAULT_LEVEL,
        map_id: GAME_CONSTANTS.DEFAULT_MAP_ID,
        position: GAME_CONSTANTS.DEFAULT_POSITION,
        stats: GAME_CONSTANTS.DEFAULT_STATS,
      },
    });

    return this.toResponseDto(character);
  }

  async update(id: string, userId: string, dto: UpdateCharacterDto): Promise<CharacterResponseDto> {
    // Check ownership
    const character = await this.prisma.character.findUnique({
      where: { id },
    });

    if (!character) {
      throw new NotFoundException('Character not found');
    }

    if (character.user_id !== userId) {
      throw new ForbiddenException('You do not own this character');
    }

    // If updating name, check uniqueness
    if (dto.name && dto.name !== character.name) {
      const existingCharacter = await this.prisma.character.findUnique({
        where: { name: dto.name },
      });

      if (existingCharacter) {
        throw new ConflictException('Character name already taken');
      }
    }

    // Update character
    const updated = await this.prisma.character.update({
      where: { id },
      data: {
        ...(dto.name && { name: dto.name }),
        ...(dto.appearance && { appearance: dto.appearance }),
      },
    });

    return this.toResponseDto(updated);
  }

  async delete(id: string, userId: string): Promise<void> {
    // Check ownership
    const character = await this.prisma.character.findUnique({
      where: { id },
    });

    if (!character) {
      throw new NotFoundException('Character not found');
    }

    if (character.user_id !== userId) {
      throw new ForbiddenException('You do not own this character');
    }

    // Delete character
    await this.prisma.character.delete({
      where: { id },
    });
  }

  async select(id: string, userId: string): Promise<SelectCharacterResponseDto> {
    // Check ownership
    const character = await this.prisma.character.findUnique({
      where: { id },
    });

    if (!character) {
      throw new NotFoundException('Character not found');
    }

    if (character.user_id !== userId) {
      throw new ForbiddenException('You do not own this character');
    }

    const charData = this.toResponseDto(character);

    return {
      character: {
        id: charData.id,
        name: charData.name,
        level: charData.level,
        class_id: charData.class_id,
        map_id: charData.map_id,
        position: charData.position,
        stats: charData.stats,
      },
      map_connect_info: {
        map_id: charData.map_id,
        // Will be populated in Phase 2 with Gateway URL
      },
    };
  }

  private toResponseDto(character: any): CharacterResponseDto {
    return {
      id: character.id,
      user_id: character.user_id,
      name: character.name,
      level: character.level,
      class_id: character.class_id,
      appearance: character.appearance as Record<string, any>,
      map_id: character.map_id,
      position: character.position as { x: number; y: number },
      stats: character.stats as Record<string, any>,
      created_at: character.created_at,
    };
  }
}
