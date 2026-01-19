import { IsString, IsObject, IsOptional } from 'class-validator';

export class UpdateCharacterDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsObject()
  @IsOptional()
  appearance?: Record<string, any>;
}
