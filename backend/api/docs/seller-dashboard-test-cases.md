# Seller Dashboard Test Cases

## Scope

- Endpoint: `GET /v1/seller/dashboard`
- UI: `SellerDashboardScreen`
- Time window: `days=7|14|30`

## Data Setup

- Seller A owns at least 5 active products.
- Orders include mixed statuses: `CONFIRMED`, `PREPARING`, `SHIPPED`, `DELIVERED`, `CANCELLED`.
- Payments include both `PAID` and `PENDING`.
- Inventory lots include:
  - active lots with qty > 0
  - lots with qty = 0
  - lots expiring within 3 days
  - lots already expired

## Functional Cases

1. Unauthorized access
- No token
- Expected: `401`

2. Non-seller account
- Token of user without seller profile
- Expected: `403 Seller account required`

3. Empty-sales seller
- Seller with products but no paid orders
- Expected:
  - `salesToday = 0`, `sales7d = 0`
  - `bestSeller7d = null`
  - `slowMovingProducts7d` still returns active products with 0 sales

4. Paid + cancelled mix
- Include cancelled orders with paid/pending
- Expected:
  - cancelled orders excluded from sales KPIs
  - order count excludes cancelled

5. Pending payment orders
- Include pending payment orders
- Expected:
  - sales KPIs exclude pending payment rows

6. Pending shipment KPI
- Orders with status in `CONFIRMED|PREPARING|SHIPPED`
- Expected:
  - counted in `pendingShipmentOrders`

7. Low-stock products
- Some active products have total active-lot qty <= threshold
- Expected:
  - listed in `inventory.lowStockProducts`
  - sorted ascending by qty

8. Expiring lots window
- Lots expiring within 3 days and later than now
- Expected:
  - only future lots within window appear
  - expired lots not included

9. Daily trend completeness
- Last 7 days includes days with no sales
- Expected:
  - `dailyTrend7d` always returns 7 entries
  - no-sale day has `sales = 0`, `orders = 0`

10. Best seller logic
- Multiple products sold in 7 days
- Expected:
  - highest amount product is `bestSeller7d`
  - tie-breaker uses qty

11. Slow moving logic
- Some products zero sales, some low sales
- Expected:
  - zero-sales products appear first in `slowMovingProducts7d`

12. Cross-seller isolation
- Two sellers with independent orders/lots
- Expected:
  - Seller A dashboard never includes Seller B data

13. Period filter query
- Call endpoint with `days=7`, `days=14`, `days=30`, and invalid value
- Expected:
  - valid values return matching period data and trend length
  - invalid value falls back to `7`

14. Actionable recommendation payload
- Seller has slow/zero-sale products in selected period
- Expected:
  - `insights.recommendations[]` includes product + reason + suggested plan + estimated cost
  - payload includes note that billing starts only after explicit campaign activation

## UI Cases

1. Dashboard loads successfully
- KPI cards show values without overflow.

2. Trend bars render on mobile width
- Bars remain readable, labels visible.

3. Insight section behavior
- With data: shows best seller and slow moving list.
- Without data: graceful empty text.

4. Pull-to-refresh
- Updates `generatedAt` and refreshed values.

5. Large values formatting
- Currency formatting remains readable (k/M compact on chart labels).

6. Period toggle UX
- Switch between 7/14/30 chips
- Expected:
  - KPI titles and values update to selected period
  - trend chart length and labels update correctly

## Regression Checks

- `npm run build` passes.
- `flutter analyze` passes for dashboard-related files.
- Existing seller product management still works.
