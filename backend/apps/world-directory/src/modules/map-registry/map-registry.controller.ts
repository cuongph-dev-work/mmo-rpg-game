import { Controller, Post, Get, Delete, Body, Param, HttpCode, HttpStatus, ParseIntPipe } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { MapRegistryService } from './map-registry.service';
import { RegisterMapServerDto, HeartbeatDto, MapServerInfoDto } from '@mmo-rpg/shared';

@ApiTags('map-registry')
@Controller('map-registry')
export class MapRegistryController {
  constructor(private mapRegistryService: MapRegistryService) {}

  @Post('register')
  @ApiOperation({ summary: 'Register a map server (Internal API)' })
  @ApiResponse({ status: 201, description: 'Server registered successfully' })
  async register(@Body() dto: RegisterMapServerDto): Promise<MapServerInfoDto> {
    return this.mapRegistryService.register(dto);
  }

  @Post('heartbeat')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Send heartbeat to keep server alive (Internal API)' })
  @ApiResponse({ status: 200, description: 'Heartbeat acknowledged' })
  @ApiResponse({ status: 404, description: 'Server not found, must register first' })
  async heartbeat(@Body() dto: HeartbeatDto): Promise<{ status: string }> {
    await this.mapRegistryService.heartbeat(dto);
    return { status: 'ok' };
  }

  @Get('map/:mapId')
  @ApiOperation({ summary: 'Find which server hosts a specific map (Internal API)' })
  @ApiResponse({ status: 200, description: 'Server info returned' })
  @ApiResponse({ status: 404, description: 'No server found for this map' })
  async findServerForMap(@Param('mapId', ParseIntPipe) mapId: number): Promise<MapServerInfoDto | null> {
    return this.mapRegistryService.findServerForMap(mapId);
  }

  @Get('server/:serverId')
  @ApiOperation({ summary: 'Get server info by ID (Internal API)' })
  async findServerById(@Param('serverId') serverId: string): Promise<MapServerInfoDto | null> {
    return this.mapRegistryService.findServerById(serverId);
  }

  @Get('servers')
  @ApiOperation({ summary: 'List all registered servers (Internal API)' })
  async listAllServers(): Promise<MapServerInfoDto[]> {
    return this.mapRegistryService.listAllServers();
  }

  @Delete('server/:serverId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Unregister a map server (Internal API)' })
  async unregister(@Param('serverId') serverId: string): Promise<void> {
    await this.mapRegistryService.unregister(serverId);
  }
}
