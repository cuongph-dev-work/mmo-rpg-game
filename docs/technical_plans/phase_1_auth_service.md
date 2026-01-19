# Phase 1: Authentication & Character Service

## 1. Mục tiêu
Xây dựng Service đầu tiên trong hệ thống Microservices, chịu trách nhiệm:
1.  **Authentication:** Đăng ký, Đăng nhập, Bảo mật (JWT).
2.  **Character Management:** Tạo nhân vật, Chọn nhân vật, Chỉnh sửa ngoại hình level thấp.

## 2. Database Design (PostgreSQL)

Chúng ta sẽ có 2 bảng chính: `users` và `characters`. Quan hệ 1-N (1 User có nhiều Characters).

### 2.1. Table `users`
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PK, Generated | User ID duy nhất toàn hệ thống |
| `username` | Varchar | Unique, Not Null | Tên đăng nhập |
| `email` | Varchar | Unique | Email (optional MVP) |
| `password_hash` | Varchar | Not Null | Mật khẩu đã hash (bcrypt) |
| `created_at` | Timestamp | Default Now | |

### 2.2. Table `characters`
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PK, Generated | Character ID (CID) |
| `user_id` | UUID | FK -> `users.id` | Sở hữu bởi User nào |
| `name` | Varchar | Unique, Not Null | Tên nhân vật (In-game) |
| `level` | Integer | Default 1 | Level nhân vật |
| `class_id` | Varchar | Not Null | Class (Warrior, Mage...) |
| `appearance` | JSONB | Default {} | Customization (Hair, Color...) |
| `map_id` | Integer | Default 1 | Map hiện tại đang đứng |
| `position` | JSONB | Default {x,y} | Tọa độ trên Map |
| `stats` | JSONB | Default {...} | HP, MP, STR, AGI... |

## 3. API Specification (RESTful)

### 3.1. Auth Group (`/auth`)
*   `POST /auth/register`: Đăng ký tài khoản mới.
    *   Body: `{ username, password, email }`
*   `POST /auth/login`: Đăng nhập.
    *   Body: `{ username, password }`
    *   Response: `{ access_token, user_id }`
    *   Logic: Trả về JWT Token chứa `sub=user_id`.

### 3.2. Character Group (`/characters`)
*Requires: Bearer Token (JWT)*

*   `GET /characters`: Lấy danh sách nhân vật của User hiện tại.
    *   Logic: `SELECT * FROM characters WHERE user_id = current_user.id`
*   `POST /characters`: Tạo nhân vật mới.
    *   Body: `{ name, class_id, appearance }`
    *   Logic: Validate tên (không trùng), validate số lượng char (max 4 per user).
*   `PATCH /characters/:id`: Update thông tin (chỉ dùng cho config ngoại hình ban đầu hoặc đổi tên nếu có item).
*   `DELETE /characters/:id`: Xóa nhân vật (Soft delete).
*   `POST /characters/:id/select`: Chọn nhân vật để vào game.
    *   Response: `{ character_details, map_connect_info }`
    *   Logic:
        *   Đây là bước "Join World".
        *   Trả về thông tin đầy đủ để Client load scene.
        *   (Optional Phase 2) Gọi sang World Directory để lấy IP Gateway phù hợp.

## 4. Tech Stack Check-list
- **Framework:** NestJS.
- **ORM:** Prisma (Recommended) hoặc TypeORM.
- **Validation:** `class-validator`, `class-transformer`.
- **Security:** `passport`, `passport-jwt`, `bcrypt`.
- **Docs:** Swagger (`@nestjs/swagger`).

## 5. Các bước triển khai (Implementation Steps)

### Step 1: Project Skeleton
- [ ] Initialize NestJS App (`backend-auth`).
- [ ] Setup Docker Compose (Postgres).
- [ ] Setup Prisma Schema.

### Step 2: Auth Module
- [ ] Implement `UsersService` (Create, Find).
- [ ] Implement `AuthService` (Hash Pass, Sign JWT).
- [ ] Implement `AuthController` (Login, Register).
- [ ] Setup JWT Strategy & Guards.

### Step 3: Character Module
- [ ] Create `CharactersService` (CRUD).
- [ ] Implement `CharactersController`.
- [ ] Validate logic (Duplicate Name, Max Chars).

### Step 4: Testing & Integration
- [ ] Viết Unit Test cho Service.
- [ ] Test API bằng Swagger/Postman.
