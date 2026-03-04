# Seller Promotion Flow

## Endpoints

- `GET /v1/seller/dashboard?days=7|14|30`
  - Returns recommendations and promotion plan catalog.
- `POST /v1/seller/promotions/start`
  - Starts promotion campaign for a seller-owned product.
- `GET /v1/seller/promotions?status=ACTIVE`
  - Lists seller campaigns (latest first).

## Start Campaign Payload

```json
{
  "productId": "<uuid>",
  "planCode": "BOOST_LITE",
  "days": 7,
  "note": "Started from dashboard recommendation"
}
```

## Pricing Rule (Current Implementation)

- `estimatedCost = pricePerDay * days`
- Valid plans:
  - `BOOST_LITE` (49 THB/day, min 3 days)
  - `BOOST_PLUS` (99 THB/day, min 7 days)
  - `BOOST_MAX` (199 THB/day, min 7 days)
- Valid duration: up to 30 days.

## Billing Note

- When seller confirms **Start Promotion**, campaign is created with:
  - `status = ACTIVE`
  - `billingStatus = PENDING`
- UI message clearly states platform billing starts after explicit confirmation.

## Next Step to Go Live

- Add payment capture endpoint and webhook to transition:
  - `billingStatus: PENDING -> PAID`
- Add campaign serving logic in ranking/search feed.
