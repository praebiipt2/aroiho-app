-- CreateEnum
CREATE TYPE "ShippingMethod" AS ENUM ('AUTO', 'GROUND', 'AIR');

-- CreateEnum
CREATE TYPE "TransportMode" AS ENUM ('TRUCK', 'FLIGHT');

-- CreateEnum
CREATE TYPE "ShipmentStatus" AS ENUM ('PLANNED', 'PICKED_UP', 'IN_TRANSIT', 'OUT_FOR_DELIVERY', 'DELIVERED', 'FAILED');

-- AlterTable
ALTER TABLE "orders" ADD COLUMN     "shipping_method" "ShippingMethod" NOT NULL DEFAULT 'AUTO';

-- CreateTable
CREATE TABLE "shipments" (
    "id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "status" "ShipmentStatus" NOT NULL DEFAULT 'PLANNED',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "shipments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "shipment_legs" (
    "id" UUID NOT NULL,
    "shipment_id" UUID NOT NULL,
    "seq" INTEGER NOT NULL,
    "mode" "TransportMode" NOT NULL,
    "from_name" VARCHAR(120),
    "to_name" VARCHAR(120),
    "flight_no" VARCHAR(20),
    "depart_at" TIMESTAMPTZ(6),
    "arrive_at" TIMESTAMPTZ(6),
    "status" "ShipmentStatus" NOT NULL DEFAULT 'PLANNED',
    "meta" JSONB,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "shipment_legs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "shipments_order_id_key" ON "shipments"("order_id");

-- CreateIndex
CREATE INDEX "shipment_legs_shipment_id_seq_idx" ON "shipment_legs"("shipment_id", "seq");

-- CreateIndex
CREATE UNIQUE INDEX "shipment_legs_shipment_id_seq_key" ON "shipment_legs"("shipment_id", "seq");

-- AddForeignKey
ALTER TABLE "shipments" ADD CONSTRAINT "shipments_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "shipment_legs" ADD CONSTRAINT "shipment_legs_shipment_id_fkey" FOREIGN KEY ("shipment_id") REFERENCES "shipments"("id") ON DELETE CASCADE ON UPDATE CASCADE;
