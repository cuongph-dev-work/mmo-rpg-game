import { Injectable } from '@nestjs/common';

@Injectable()
export class WorldDirectoryService {
  getHello(): string {
    return 'Hello World!';
  }
}
