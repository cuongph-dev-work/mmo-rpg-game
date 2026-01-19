import { Controller, Get, Post, Patch, Delete, Body, Param, UseGuards, Request, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { CharactersService } from './characters.service';
import { CreateCharacterDto, UpdateCharacterDto } from '@mmo-rpg/shared';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('characters')
@Controller('characters')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class CharactersController {
  constructor(private charactersService: CharactersService) {}

  @Get()
  @ApiOperation({ summary: 'Get all characters for current user' })
  @ApiResponse({ status: 200, description: 'Returns user characters' })
  async getCharacters(@Request() req) {
    return this.charactersService.findAllByUser(req.user.userId);
  }

  @Post()
  @ApiOperation({ summary: 'Create a new character' })
  @ApiResponse({ status: 201, description: 'Character created successfully' })
  @ApiResponse({ status: 400, description: 'Max characters reached' })
  @ApiResponse({ status: 409, description: 'Character name already taken' })
  async createCharacter(@Request() req, @Body() dto: CreateCharacterDto) {
    return this.charactersService.create(req.user.userId, dto);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update character' })
  @ApiResponse({ status: 200, description: 'Character updated successfully' })
  @ApiResponse({ status: 403, description: 'You do not own this character' })
  @ApiResponse({ status: 404, description: 'Character not found' })
  async updateCharacter(@Request() req, @Param('id') id: string, @Body() dto: UpdateCharacterDto) {
    return this.charactersService.update(id, req.user.userId, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete character' })
  @ApiResponse({ status: 204, description: 'Character deleted successfully' })
  @ApiResponse({ status: 403, description: 'You do not own this character' })
  @ApiResponse({ status: 404, description: 'Character not found' })
  async deleteCharacter(@Request() req, @Param('id') id: string) {
    await this.charactersService.delete(id, req.user.userId);
  }

  @Post(':id/select')
  @ApiOperation({ summary: 'Select character to enter game world' })
  @ApiResponse({ status: 200, description: 'Character selected, returns connection info' })
  @ApiResponse({ status: 403, description: 'You do not own this character' })
  @ApiResponse({ status: 404, description: 'Character not found' })
  async selectCharacter(@Request() req, @Param('id') id: string) {
    return this.charactersService.select(id, req.user.userId);
  }
}
