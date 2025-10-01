# Mpepo Kitchen Smart POS

This guide explains how the Smart POS project is structured across the Flutter mobile
application and the FastAPI backend. It is organized around the delivery milestones that
shaped the system and points to the files and functions that implement each capability.

## Segment A – Core Point of Sale Experience

### Develop the mobile POS core features (catalog, cart, and pricing)
* **Product listing:** `ProductsPage.build` renders the menu, tabs, and product grid while
  binding to `ProductsProvider.loadProducts` to refresh inventory from the backend. The
  cart summary banner is driven by `_showCartSummary` so that sales associates can preview
  totals without leaving the page. 【F:mobile/lib/features/products/products_page.dart†L14-L118】【F:mobile/lib/features/products/products_provider.dart†L18-L86】
* **Cart management and pricing logic:** `CartProvider` maintains `CartItem` rows, exposes
  `add`, `updateQuantity`, and `clear`, and keeps derived totals through `subtotal`, `tax`,
  `discount`, and `total`, which centralizes the 16% tax rate and discount percent logic for
  every checkout. 【F:mobile/lib/features/cart/cart_provider.dart†L6-L66】

### Implement receipt generation on the mobile app
* **Checkout workflow:** The cart view calls `_performCheckout` to send
  `cart.toCheckoutPayload()` via `ApiService.checkout`, shows a success confirmation, and
  navigates to `CheckoutPage` with the resulting `Receipt`. That screen enumerates line
  items and totals so the cashier can verify the sale. 【F:mobile/lib/features/cart/cart_page.dart†L102-L205】【F:mobile/lib/services/api_service.dart†L56-L102】【F:mobile/lib/features/checkout/checkout_page.dart†L10-L70】
* **Backend receipt totals:** The FastAPI `create_receipt` endpoint recomputes line totals,
  applies tax/discount rounding, reduces stock, and persists the receipt before returning
  the canonical payload to the client. This keeps fiscal math authoritative on the server. 【F:backend/app/routers/checkout.py†L1-L62】

### Build the offline transaction queue and retry mechanism
* **Local queue:** `QueueService` stores failed invoice submissions in SQLite, exposes a
  broadcast `jobsStream`, and retries pending jobs with exponential failure tracking so
  jobs transition to `failed` after five attempts. 【F:mobile/lib/services/queue_service.dart†L1-L113】
* **Connectivity-aware draining:** `ConnectivityService.initialize` watches connectivity
  changes and periodically invokes `QueueService.processQueue`, calling back into
  `ApiService.submitInvoice` whenever a network is available to keep the ledger synced. 【F:mobile/lib/services/connectivity_service.dart†L1-L41】
* **Operator controls:** `InvoicesProvider` subscribes to `jobsStream`, exposes retry
  actions, and updates UI state so staff can manually requeue failed transmissions. 【F:mobile/lib/features/invoices/invoices_provider.dart†L8-L58】

### Contribute to the Python backend with product CRUD endpoints
* `backend/app/routers/products.py` implements `create_product`, `list_products`,
  `get_product`, `update_product`, and `delete_product`, each delegating to the shared CRUD
  helpers to ensure consistent validation and error responses. 【F:backend/app/routers/products.py†L13-L43】
* The persistence logic in `backend/app/crud.py` reads/writes `models.Product` instances so
  product updates, deletes, and inventory adjustments stay in sync with receipts. 【F:backend/app/crud.py†L1-L54】【F:backend/app/models.py†L1-L24】

### Write API documentation for the product module
* The generated OpenAPI document includes full request/response schemas for
  `/products/` and `/products/{product_id}`, capturing CRUD semantics for API consumers and
  SDK generation. 【F:openapi/smartpos-openapi.json†L32-L88】

## Segment B – E-Invoicing & Tax Authority Integration

### Design the Invoice JSON schema for tax submissions
* `schemas.InvoicePayload` models the tax submission contract, wrapping receipt metadata,
  totals, and line items, while `json_encoders` ensures timestamps are emitted as ISO 8601
  strings required by the authority. 【F:backend/app/schemas.py†L86-L111】

### Implement the tax authority integration
* `submit_invoice` builds the payload from `receipt_to_schema`, calls the tax authority
  endpoint with timeout handling, normalizes JSON/non-JSON responses, and persists the
  resulting status. This concentrates retry semantics and failure messaging in one place. 【F:backend/app/routers/invoices.py†L1-L94】
* The mobile `InvoiceRepository.submitInvoice` delegates to `ApiService.submitInvoice`, and
  `_submitInvoice` in `CheckoutPage` queues retries through `QueueService` to maintain
  continuity even when the upstream is unavailable. 【F:mobile/lib/data/repositories/invoice_repository.dart†L1-L9】【F:mobile/lib/services/api_service.dart†L104-L131】【F:mobile/lib/features/checkout/checkout_page.dart†L52-L92】

### Set up a sandbox/mock server for testing
* The Postman mock guide outlines creating a `POST /invoice` mock that returns deterministic
  authority responses. Backend environment variables (`MOCK_TAX_API_URL`) point to this URL
  to decouple testing from live tax systems. 【F:postman/mock/README.md†L1-L12】【F:backend/app/routers/invoices.py†L15-L21】

### Extend the mobile app to surface invoice status and responses
* `InvoicesPage` renders submitted invoices, opens a modal via `_showReceiptDetails`, and
  formats authority response JSON so operators can see acceptance codes on-device. 【F:mobile/lib/features/invoices/invoices_page.dart†L13-L250】
* `InvoicesProvider.loadInvoices` hydrates that view by calling the backend and subscribing
  to queue updates so UI state reflects both sent and pending submissions. 【F:mobile/lib/features/invoices/invoices_provider.dart†L16-L56】

### Persist authority responses in the backend
* `crud.create_invoice` stores both the submission payload and any authority response, while
  `TaxAuthorityResponse` captures normalized replies so audits retain the original message.
  `invoice_to_schema` rehydrates these records for API clients. 【F:backend/app/crud.py†L93-L167】【F:backend/app/models.py†L26-L68】

## Segment C – Platform & Reporting

### Build the FastAPI backend with authentication guardrails and schema
* `app/main.py` wires the FastAPI application, enables CORS, registers routers, and creates
  tables on startup. Authentication for the demo is handled client-side by the simple
  `AuthProvider`, which gates access to the mobile shell until the admin credentials are
  supplied. 【F:backend/app/main.py†L1-L34】【F:mobile/lib/app.dart†L1-L122】【F:mobile/lib/features/auth/auth_provider.dart†L1-L23】
* Database configuration lives in `database.py`, exposing `get_db` and SQLAlchemy metadata
  so each router can transact against the same schema. 【F:backend/app/database.py†L1-L39】

### Implement reporting endpoints and connect them to the app
* `routers.reports.daily_report` validates dates and returns aggregated totals built by
  `crud.daily_report`, which computes receipt counts, sums, history, and popular products
  from persisted receipts. 【F:backend/app/routers/reports.py†L1-L28】【F:backend/app/crud.py†L205-L279】
* `ReportsProvider.loadReport` calls `ReportRepository.fetchDailyReport` (wrapping
  `ApiService.getDailyReport`) and normalizes the response into chart-friendly models that
  `ReportsPage` displays via summary cards, line charts, and bar charts. 【F:mobile/lib/features/reports/reports_provider.dart†L17-L72】【F:mobile/lib/data/repositories/report_repository.dart†L1-L8】【F:mobile/lib/features/reports/reports_page.dart†L1-L120】

### Create a SQL schema with seed data for testing
* `seed.sql` defines the `products` table and populates sample menu items spanning starters
  through drinks. This script ensures demos and automated tests start from predictable
  inventory levels. 【F:backend/seed.sql†L1-L66】

### Extend the mobile app to consume reporting APIs and display summaries
* `SmartPosApp` bootstraps providers for products, cart, invoices, and reports, ensuring the
  reporting tab is hydrated after login. The `NavigationBar` exposes the Reports view so
  managers can review KPIs from the same shell. 【F:mobile/lib/app.dart†L17-L146】
* `ReportsPage` composes the fetched data into visualizations (trend lines and popular
  product bars) while handling empty/loading states to keep the dashboard informative. 【F:mobile/lib/features/reports/reports_page.dart†L9-L160】

### Document backend endpoints and maintain the Postman collection
* The Postman collection enumerates product CRUD, checkout, invoice submission, reporting,
  and mock authority calls so QA can exercise the full API surface with shared examples. 【F:postman/SmartPOS.postman_collection.json†L1-L78】
* Backend developer docs in `backend/README.md` describe environment setup, testing, and how
  to access Swagger/OpenAPI to keep contributors aligned. 【F:backend/README.md†L1-L37】

---

Refer to the `mobile/` and `backend/` subdirectories for platform-specific setup details.
