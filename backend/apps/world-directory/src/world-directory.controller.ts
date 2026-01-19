import { Controller, Get } from '@nestjs/common';
import { WorldDirectoryService } from './world-directory.service';

@Controller()
export class WorldDirectoryController {
  constructor(private readonly worldDirectoryService: WorldDirectoryService) {}

  @Get()
  getHello(): string {
    return this.worldDirectoryService.getHello();
  }
}
