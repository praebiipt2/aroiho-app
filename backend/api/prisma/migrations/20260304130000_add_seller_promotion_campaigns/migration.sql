CREATE TABLE IF NOT EXISTS "seller_promotion_campaigns" (
  "id" UUID NOT NULL,
  "seller_id" UUID NOT NULL,
  "product_id" UUID NOT NULL,
  "plan_code" VARCHAR(40) NOT NULL,
  "plan_name" VARCHAR(80) NOT NULL,
  "price_per_day" DECIMAL(12,2) NOT NULL,
  "duration_days" INTEGER NOT NULL,
  "estimated_cost" DECIMAL(12,2) NOT NULL,
  "status" VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  "billing_status" VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  "note" VARCHAR(255),
  "starts_at" TIMESTAMPTZ(6) NOT NULL,
  "ends_at" TIMESTAMPTZ(6) NOT NULL,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "seller_promotion_campaigns_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "seller_promotion_campaigns_seller_id_status_idx"
  ON "seller_promotion_campaigns"("seller_id", "status");

CREATE INDEX IF NOT EXISTS "seller_promotion_campaigns_product_id_status_idx"
  ON "seller_promotion_campaigns"("product_id", "status");

CREATE INDEX IF NOT EXISTS "seller_promotion_campaigns_ends_at_idx"
  ON "seller_promotion_campaigns"("ends_at");

DO $$ BEGIN
  ALTER TABLE "seller_promotion_campaigns"
  ADD CONSTRAINT "seller_promotion_campaigns_seller_id_fkey"
  FOREIGN KEY ("seller_id") REFERENCES "sellers"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  ALTER TABLE "seller_promotion_campaigns"
  ADD CONSTRAINT "seller_promotion_campaigns_product_id_fkey"
  FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;
