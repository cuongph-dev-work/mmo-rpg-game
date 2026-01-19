export class SelectCharacterResponseDto {
  character: {
    id: string;
    name: string;
    level: number;
    class_id: string;
    map_id: number;
    position: { x: number; y: number };
    stats: Record<string, any>;
  };
  map_connect_info: {
    map_id: number;
    // Will be populated in Phase 2 with Gateway info
    gateway_url?: string;
  };
}
