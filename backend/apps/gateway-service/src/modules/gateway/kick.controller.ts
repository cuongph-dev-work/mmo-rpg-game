import { Controller, Post, Param, HttpCode, HttpStatus, Logger } from '@nestjs/common';
import { AppGateway } from './app.gateway';

@Controller('kick')
export class KickController {
  private readonly logger = new Logger(KickController.name);

  constructor(private readonly appGateway: AppGateway) {}

  @Post(':userId')
  @HttpCode(HttpStatus.OK)
  async kickUser(@Param('userId') userId: string): Promise<{ status: string }> {
    this.logger.log(`Received kick request for user ${userId}`);
    
    const kicked = this.appGateway.kickUser(userId);
    
    if (kicked) {
      this.logger.log(`Successfully kicked user ${userId}`);
      return { status: 'kicked' };
    } else {
      this.logger.log(`User ${userId} not found or already disconnected`);
      return { status: 'not_found' };
    }
  }
}
