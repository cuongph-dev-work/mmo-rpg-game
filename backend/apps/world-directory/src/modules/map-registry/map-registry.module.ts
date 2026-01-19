import { Module } from '@nestjs/common';
import { MapRegistryService } from './map-registry.service';
import { MapRegistryController } from './map-registry.controller';
import { RedisModule } from '../redis/redis.module';

@Module({
  imports: [RedisModule],
  providers: [MapRegistryService],
  controllers: [MapRegistryController],
  exports: [MapRegistryService],
})
export class MapRegistryModule {}
