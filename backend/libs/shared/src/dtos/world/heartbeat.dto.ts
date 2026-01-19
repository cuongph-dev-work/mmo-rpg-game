import { IsString, IsNotEmpty, IsNumber, IsOptional } from 'class-validator';

export class HeartbeatDto {
  @IsString()
  @IsNotEmpty()
  id: string;

  @IsNumber()
  @IsOptional()
  current_players?: number;

  @IsNumber()
  @IsOptional()
  load?: number;
}
