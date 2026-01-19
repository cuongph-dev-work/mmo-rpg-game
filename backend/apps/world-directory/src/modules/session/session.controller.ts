import { Controller, Post, Delete, Get, Body, Param, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { SessionService } from './session.service';
import { UserSessionDto } from '@mmo-rpg/shared';

@ApiTags('session')
@Controller('session')
export class SessionController {
  constructor(private sessionService: SessionService) {}

  @Post('online')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Mark user as online on a gateway (Internal API)' })
  @ApiResponse({ status: 200, description: 'User marked as online' })
  async setUserOnline(@Body() dto: UserSessionDto): Promise<{ status: string }> {
    await this.sessionService.setUserOnline(dto.userId, dto.gatewayId);
    return { status: 'ok' };
  }

  @Delete(':userId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Mark user as offline (Internal API)' })
  async setUserOffline(@Param('userId') userId: string): Promise<void> {
    await this.sessionService.setUserOffline(userId);
  }

  @Get(':userId')
  @ApiOperation({ summary: 'Get user session info (Internal API)' })
  @ApiResponse({ status: 200, description: 'Session info returned' })
  @ApiResponse({ status: 404, description: 'User not online' })
  async getUserSession(@Param('userId') userId: string): Promise<UserSessionDto | null> {
    return this.sessionService.getUserSession(userId);
  }

  @Get(':userId/status')
  @ApiOperation({ summary: 'Check if user is online (Internal API)' })
  async isUserOnline(@Param('userId') userId: string): Promise<{ online: boolean }> {
    const online = await this.sessionService.isUserOnline(userId);
    return { online };
  }

  @Post(':userId/extend')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Extend user session TTL (Internal API)' })
  async extendSession(@Param('userId') userId: string): Promise<{ status: string }> {
    await this.sessionService.extendSession(userId);
    return { status: 'ok' };
  }

  @Get('stats/count')
  @ApiOperation({ summary: 'Get online user count (Internal API)' })
  async getOnlineUserCount(): Promise<{ count: number }> {
    const count = await this.sessionService.getOnlineUserCount();
    return { count };
  }
}
