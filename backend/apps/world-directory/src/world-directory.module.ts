import { Module } from '@nestjs/common';
import { ConfigModule} from '@nestjs/config';
import { RedisModule } from './modules/redis/redis.module';
import { MapRegistryModule } from './modules/map-registry/map-registry.module';
import { SessionModule } from './modules/session/session.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),
    RedisModule,
    MapRegistryModule,
    SessionModule,
  ],
})
export class WorldDirectoryModule {}
