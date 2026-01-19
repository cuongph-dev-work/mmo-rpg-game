import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { ConfigModule } from '@nestjs/config';
import { WorldClientService } from './world-client.service';

@Module({
  imports: [HttpModule, ConfigModule],
  providers: [WorldClientService],
  exports: [WorldClientService],
})
export class WorldClientModule {}
