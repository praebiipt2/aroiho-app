-- CreateEnum
CREATE TYPE "TrackingEventType" AS ENUM ('ORDER_CREATED', 'PAYMENT_PENDING', 'PAYMENT_CONFIRMED', 'PREPARING', 'PACKED', 'PICKED_UP', 'IN_TRANSIT', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED', 'REFUND_REQUESTED', 'REFUNDED', 'NOTE');

-- CreateTable
CREATE TABLE "tracking_events" (
    "id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "type" "TrackingEventType" NOT NULL,
    "message" VARCHAR(255),
    "meta" JSONB,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "tracking_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "tracking_events_order_id_created_at_idx" ON "tracking_events"("order_id", "created_at");

-- AddForeignKey
ALTER TABLE "tracking_events" ADD CONSTRAINT "tracking_events_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;
