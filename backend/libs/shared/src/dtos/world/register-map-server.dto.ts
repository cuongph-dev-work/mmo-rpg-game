import { IsString, IsNotEmpty, IsNumber, IsArray, IsOptional } from 'class-validator';

export class RegisterMapServerDto {
  @IsString()
  @IsNotEmpty()
  id: string;

  @IsString()
  @IsNotEmpty()
  name: string;

  @IsString()
  @IsNotEmpty()
  ip: string;

  @IsNumber()
  port: number;

  @IsArray()
  @IsOptional()
  supported_maps?: number[];

  @IsNumber()
  @IsOptional()
  max_players?: number;
}
