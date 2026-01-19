export class CharacterResponseDto {
  id: string;
  user_id: string;
  name: string;
  level: number;
  class_id: string;
  class_name: string;
  appearance: Record<string, any>;
  map_id: number;
  position: { x: number; y: number };
  stats: Record<string, any>;
  created_at: Date;
}
