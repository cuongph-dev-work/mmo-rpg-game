import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { GatewayModule } from './modules/gateway';
import { AuthModule } from './modules/auth/auth.module';
import { WorldClientModule } from './modules/world-client/world-client.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['apps/gateway-service/.env', '.env'],
    }),
    AuthModule,
    WorldClientModule,
    GatewayModule,
  ],
})
export class AppModule {}
