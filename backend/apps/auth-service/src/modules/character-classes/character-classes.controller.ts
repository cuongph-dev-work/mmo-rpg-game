import { Controller, Get } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { CharacterClassesService } from './character-classes.service';
import { CharacterClassResponseDto } from '@mmo-rpg/shared';

@ApiTags('character-classes')
@Controller('character-classes')
export class CharacterClassesController {
  constructor(private readonly characterClassesService: CharacterClassesService) {}

  @Get()
  @ApiOperation({ summary: 'Get all character classes' })
  @ApiResponse({ status: 200, type: [CharacterClassResponseDto] })
  async findAll(): Promise<CharacterClassResponseDto[]> {
    return this.characterClassesService.findAll();
  }
}
