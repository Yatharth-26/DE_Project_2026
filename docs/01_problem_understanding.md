# Problem Understanding

| Problem | Business need | Stakeholder | Classification | Related queries |
|---|---|---|---|---|
| P1 | Customers need fast text search and category browsing, including products in sub-categories. | Customer, category manager | Customer-facing / real-time | R01, R02, R14 |
| P2 | Product pages must quickly display rating summaries, related products, and product details. | Customer | Customer-facing / real-time | R03, R11, R24 |
| P3 | Customers should be able to open their order history and an order’s details without delay. | Customer | Customer-facing / real-time | R04, R23 |
| P4 | Sellers need quick access to recent sales, low-stock products, and price/stock updates. Seller-level performance reports also need to complete reliably. | Seller | Customer-facing / real-time for seller operations; reporting / analytics for performance reports | R06, R07, R15, W02, W03 |
| P5 | Logistics staff must identify delayed shipments and process packed orders quickly. | Logistics team | Customer-facing / real-time operational workload | R05, R21, W05 |
| P6 | Administrators need a correct list of saved addresses that were never used in an order. | Admin, customer support | Reporting / analytics | R13 |
| P7 | Marketing needs to identify abandoned carts, while background cart loading and clean-up jobs must finish efficiently. | Marketing team | Reporting / analytics and batch processing | R10, W04, W06 |
| P8 | Trust and safety needs to detect suspicious “verified purchase” reviews and analyse review text for battery-related feedback. | Trust & safety team | Reporting / analytics | R16, R17 |
| P9 | Finance and category teams need reliable reports for returns, sales, customer spending, average order value, and category performance as data grows. | Finance, category manager, Prime team | Reporting / analytics | R08, R09, R12, R18, R19, R20, R22, W01 |

## Assumptions

- All monetary values are in Indian rupees (INR).
- Timestamps in the data represent India Standard Time.
- A product belongs to one seller and one category.
- Digital products may be ordered without a delivery address.
- `orders.total_amount` is the stored total at checkout time, while `order_items` stores the individual purchased lines.
- Historical orders and order items must remain valid even if a product is later made inactive or runs out of stock.
- A customer can save multiple addresses, but only one address should be marked as the default address at a time.