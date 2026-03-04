ALTER TABLE "sellers"
  ADD COLUMN "user_id" UUID;

CREATE UNIQUE INDEX "sellers_user_id_key" ON "sellers"("user_id");

ALTER TABLE "sellers"
  ADD CONSTRAINT "sellers_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
