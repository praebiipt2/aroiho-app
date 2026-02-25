ALTER TABLE "orders"
  ADD COLUMN "hidden_at" TIMESTAMPTZ(6),
  ADD COLUMN "deleted_at" TIMESTAMPTZ(6),
  ADD COLUMN "purge_after" TIMESTAMPTZ(6);

CREATE INDEX "orders_user_id_hidden_at_idx" ON "orders"("user_id", "hidden_at");
CREATE INDEX "orders_user_id_deleted_at_idx" ON "orders"("user_id", "deleted_at");
CREATE INDEX "orders_purge_after_idx" ON "orders"("purge_after");
