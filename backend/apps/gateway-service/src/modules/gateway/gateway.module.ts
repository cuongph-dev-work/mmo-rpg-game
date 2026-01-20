import { Module } from '@nestjs/common';
import { AppGateway } from './app.gateway';
import { KickController } from './kick.controller';
import { AuthModule } from '../auth/auth.module';
import { WorldClientModule } from '../world-client/world-client.module';
import { ConfigModule } from '@nestjs/config';

@Module({
  imports: [AuthModule, WorldClientModule, ConfigModule],
  providers: [AppGateway],
  controllers: [KickController],
  exports: [AppGateway],
})
export class GatewayModule {}

