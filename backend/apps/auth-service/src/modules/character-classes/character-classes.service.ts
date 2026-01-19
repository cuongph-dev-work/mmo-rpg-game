import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { CharacterClassResponseDto } from '@mmo-rpg/shared';

@Injectable()
export class CharacterClassesService {
  constructor(private prisma: PrismaService) {}

  async findAll(): Promise<CharacterClassResponseDto[]> {
    const classes = await this.prisma.characterClass.findMany({
      orderBy: { name: 'asc' },
    });

    return classes.map(c => ({
      id: c.id,
      name: c.name,
      description: c.description || '',
      base_hp: c.base_hp,
      base_mp: c.base_mp,
      base_str: c.base_str,
      base_agi: c.base_agi,
      base_int: c.base_int,
    }));
  }
}
