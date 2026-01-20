import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { Pool } from 'pg';
import { PrismaPg } from '@prisma/adapter-pg';
import * as bcrypt from 'bcrypt';

const connectionString = `${process.env.DATABASE_URL}`;
const pool = new Pool({ connectionString });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  const username = 'testuser';
  const password = 'test123';
  const charName = 'TestWarrior';

  console.log(`🌱 Seeding database with test user: ${username}`);

  // 0. Clean up existing data (Optional: Be careful in production!)
  await prisma.character.deleteMany();
  await prisma.characterClass.deleteMany();
  console.log('🧹 Cleared existing characters and classes');

  // 1. Create User
  const hashedPassword = await bcrypt.hash(password, 10);
  
  const user = await prisma.user.upsert({
    where: { username },
    update: {
      password_hash: hashedPassword,
    },
    create: {
      username,
      password_hash: hashedPassword,
      email: 'test@example.com',
    },
  });

  console.log(`✅ User created/found: ${user.id}`);

  // 2. Create Character Class
  const warriorClass = await prisma.characterClass.upsert({
    where: { name: 'Warrior' },
    update: {},
    create: {
      name: 'Warrior',
      description: 'A strong melee fighter',
      base_hp: 100,
      base_mp: 50,
      base_str: 10,
      base_agi: 8,
      base_int: 5,
      hp_growth: 10.0,
      mp_growth: 2.0,
      str_growth: 2.5,
      agi_growth: 1.0,
      int_growth: 0.5,
    },
  });

  console.log(`✅ Class created/found: ${warriorClass.name}`);

  // 3. Create Character
  const character = await prisma.character.upsert({
    where: { name: charName },
    update: {},
    create: {
      user_id: user.id,
      name: charName,
      class_id: warriorClass.id,
      level: 10,
      map_id: 1,
      position: { x: 400, y: 300 }, // Spawn in the middle
      stats: {
        hp: 1000,
        mp: 500,
        str: 50,
        agi: 30,
        int: 20
      },
      appearance: {
        hairColor: "#ff0000",
        skinColor: "#ffffff"
      }
    },
  });

  console.log(`✅ Character created/found: ${character.name} (${character.id})`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
