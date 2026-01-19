# MMO RPG Backend - Phase 1 Implementation

## Overview
Phase 1 implements the Authentication and Character Management service using NestJS, PostgreSQL, and Prisma.

## Quick Start

### 1. Start PostgreSQL with Docker
```bash
cd backend
docker-compose up -d
```

### 2. Install Dependencies
```bash
npm install
```

### 3. Run Database Migrations
```bash
cd apps/auth-service
npx prisma migrate dev --name init
```

### 4. Start the Auth Service
```bash
# From backend/apps/auth-service
npm run start:dev

# Or from backend root
npm run start:dev --workspace=apps/auth-service
```

The service will be available at:
- **API:** http://localhost:3000
- **Swagger UI:** http://localhost:3000/api

## API Endpoints

### Auth Endpoints
- `POST /auth/register` - Register a new user
  - Body: `{ "username": "testuser", "password": "password123", "email": "test@example.com" }`

- `POST /auth/login` - Login and get JWT token
  - Body: `{ "username": "testuser", "password": "password123" }`
  - Response: `{ "access_token": "...", "user_id": "..." }`

### Character Endpoints (Requires JWT Bearer Token)
- `GET /characters` - List user's characters
- `POST /characters` - Create a new character
  - Body: `{ "name": "Warrior1", "class_id": "warrior", "appearance": {} }`
  
- `PATCH /characters/:id` - Update character
  - Body: `{ "name": "NewName", "appearance": {} }`

- `DELETE /characters/:id` - Delete character

- `POST /characters/:id/select` - Select character to enter game world
  - Returns character details and map connection info

## Database Schema

### Users Table
- `id` (UUID) - Primary key
- `username` (String) - Unique username
- `email` (String, optional) - Email address
- `password_hash` (String) - Bcrypt hashed password
- `created_at` (DateTime) - Creation timestamp

### Characters Table
- `id` (UUID) - Primary key
- `user_id` (UUID) - Foreign key to users
- `name` (String) - Unique character name
- `level` (Integer) - Character level (default: 1)
- `class_id` (String) - Character class (warrior, mage, etc.)
- `appearance` (JSON) - Character appearance customization
- `map_id` (Integer) - Current map ID (default: 1)
- `position` (JSON) - Position on map `{x, y}`
- `stats` (JSON) - Character stats `{hp, mp, str, agi, int}`
- `created_at` (DateTime) - Creation timestamp

## Business Rules
- Maximum 4 characters per user
- Character names must be unique across all users
- Passwords are hashed using bcrypt
- JWT tokens expire after 24 hours
- All character endpoints require authentication

## Development Commands

```bash
# Generate Prisma Client
npx prisma generate

# Create a new migration
npx prisma migrate dev --name migration_name

# Open Prisma Studio (Database GUI)
npx prisma studio

# Run tests
npm test

# Build for production
npm run build
```

## Environment Variables
Configure in `apps/auth-service/.env`:
```
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/mmo_rpg_auth?schema=public"
JWT_SECRET="your-super-secret-jwt-key-change-this-in-production"
JWT_EXPIRATION="24h"
PORT=3000
```

## Project Structure
```
backend/
├── apps/
│   └── auth-service/          # Auth & Character Service
│       ├── src/
│       │   ├── modules/
│       │   │   ├── auth/       # Authentication
│       │   │   ├── users/      # User management
│       │   │   └── characters/ # Character CRUD
│       │   ├── database/       # Prisma setup
│       │   ├── app.module.ts
│       │   └── main.ts
│       └── prisma/
│           └── schema.prisma
└── libs/
    └── shared/                # Shared DTOs & Constants
        └── src/
            ├── dtos/
            └── constants/
```

## Next Steps - Phase 2
- Implement Gateway service for WebSocket connections
- Implement World Directory for service discovery
- Add Redis for session management
- Integrate gateway URL in character select response
