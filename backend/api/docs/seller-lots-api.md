# Seller Inventory Lots API

Base path: `/v1`

All endpoints below require `Authorization: Bearer <accessToken>`.

## Endpoints

### 1) List lots by product

- `GET /v1/seller/products/:productId/lots`
- Response: `{ productId, total, items[] }`

### 2) Create lot

- `POST /v1/seller/products/:productId/lots`
- Body:
  - `quantityAvailable` (required, number, must be `> 0`)
  - `lotCode` (optional, string)
  - `harvestedAt` (optional, date string)
  - `packedAt` (optional, date string)
  - `expiresAt` (optional, date string)
  - `recommendedConsumeBefore` (optional, date string)
  - `storageCondition` (optional, string)
  - `status` (optional, `ACTIVE | HOLD | EXHAUSTED`, default `ACTIVE`)

### 3) Update lot

- `PATCH /v1/seller/lots/:lotId`
- Body: partial fields from create payload.
- Validation:
  - `quantityAvailable` if present must be `>= 0`
  - `status` if present must be `ACTIVE | HOLD | EXHAUSTED`

## Notes

- Seller can only access lots of products they own.
- Date fields accept ISO date strings; empty values are treated as `null` on update.
- When seller creates a new product, system auto-creates one default lot:
  - `status = ACTIVE`
  - `quantityAvailable = 100`
  - seller can edit this lot immediately from seller product management UI.
