import { IsNumber, IsObject, IsOptional } from 'class-validator';

export class UpdateCharacterStateDto {
  @IsNumber()
  @IsOptional()
  map_id?: number;

  @IsObject()
  @IsOptional()
  position?: { x: number; y: number };

  @IsObject()
  @IsOptional()
  stats?: { hp: number; mp: number };
}
