/*
  Warnings:

  - A unique constraint covering the columns `[cart_id,inventory_lot_id]` on the table `cart_items` will be added. If there are existing duplicate values, this will fail.

*/
-- CreateIndex
CREATE INDEX "cart_items_cart_id_idx" ON "cart_items"("cart_id");

-- CreateIndex
CREATE UNIQUE INDEX "cart_items_cart_id_inventory_lot_id_key" ON "cart_items"("cart_id", "inventory_lot_id");

-- CreateIndex
CREATE INDEX "carts_user_id_status_idx" ON "carts"("user_id", "status");
