import { IsString, IsNotEmpty } from 'class-validator';

export class UserSessionDto {
  @IsString()
  @IsNotEmpty()
  userId: string;

  @IsString()
  @IsNotEmpty()
  gatewayId: string;

  timestamp?: Date;
}
