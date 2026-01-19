export class MapServerInfoDto {
  id: string;
  name: string;
  ip: string;
  port: number;
  supported_maps?: number[];
  max_players?: number;
  current_players?: number;
  load?: number;
  last_heartbeat?: Date;
}
