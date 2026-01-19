-- CreateTable
CREATE TABLE "character_classes" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "base_hp" INTEGER NOT NULL,
    "base_mp" INTEGER NOT NULL,
    "base_str" INTEGER NOT NULL,
    "base_agi" INTEGER NOT NULL,
    "base_int" INTEGER NOT NULL,
    "hp_growth" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "mp_growth" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "str_growth" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "agi_growth" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "int_growth" DOUBLE PRECISION NOT NULL DEFAULT 0,

    CONSTRAINT "character_classes_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "characters" ADD CONSTRAINT "characters_class_id_fkey" FOREIGN KEY ("class_id") REFERENCES "character_classes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
