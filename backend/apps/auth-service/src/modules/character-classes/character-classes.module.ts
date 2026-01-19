import { Module } from '@nestjs/common';
import { CharacterClassesController } from './character-classes.controller';
import { CharacterClassesService } from './character-classes.service';

@Module({
  controllers: [CharacterClassesController],
  providers: [CharacterClassesService],
  exports: [CharacterClassesService],
})
export class CharacterClassesModule {}
