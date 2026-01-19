import { IsString, IsNotEmpty, IsObject, IsOptional } from 'class-validator';

export class CreateCharacterDto {
  @IsString()
  @IsNotEmpty()
  name: string;

  @IsString()
  @IsNotEmpty()
  class_id: string;

  @IsObject()
  @IsOptional()
  appearance?: Record<string, any>;
}
