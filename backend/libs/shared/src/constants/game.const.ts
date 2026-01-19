export const GAME_CONSTANTS = {
  MAX_CHARACTERS_PER_USER: 4,
  DEFAULT_MAP_ID: 1,
  DEFAULT_POSITION: { x: 0, y: 0 },
  DEFAULT_LEVEL: 1,
  DEFAULT_STATS: {
    hp: 100,
    mp: 50,
    str: 10,
    agi: 10,
    int: 10,
  },
} as const;
