# Smart POS Technical Report

## General Breakdown

### Purpose and User Goals
Mpepo Kitchen’s Smart POS empowers small merchants to run mobile-first checkout, invoicing, and reporting without heavy infrastructure. The Flutter client packages catalog browsing, carting, and analytics so staff can complete a sale, file invoices, and review KPIs from the same tablet-friendly interface, while the FastAPI backend enforces fiscal math and persistence. 【F:README.md†L1-L26】【F:mobile/lib/app.dart†L21-L175】

### Architecture Overview
The solution follows a hub-and-spoke architecture:

- **Flutter mobile app** – `SmartPosApp` composes providers for authentication, catalog, cart, invoicing, and reporting, exposing them through a bottom navigation shell (`Products`, `Cart`, `Invoices`, `Reports`). This keeps each domain loosely coupled while sharing an `ApiService` instance for network access. 【F:mobile/lib/app.dart†L21-L175】
- **FastAPI backend** – `app/main.py` registers routers for products, checkout, invoices, and reports, creates the SQLAlchemy schema on startup, and enables CORS so the mobile client or tooling can call it locally or through a tunnel. 【F:backend/app/main.py†L1-L38】
- **SQLite data tier** – `database.py` defines a `SessionLocal` factory and metadata bound to a configurable `DATABASE_URL`. The default SQLite file supports offline experimentation while allowing a future switch to Postgres via environment variables. 【F:backend/app/database.py†L1-L44】
- **Postman mock server** – The Postman collection includes a mock tax authority endpoint, and `postman/mock/README.md` documents wiring its generated URL into `MOCK_TAX_API_URL`, allowing deterministic tax responses during development. 【F:postman/SmartPOS.postman_collection.json†L1-L116】【F:postman/mock/README.md†L1-L14】

The diagram below captures runtime relationships:

```text
Flutter UI  ──providers──▶ Domain State (cart, catalog, invoices, reports)
    │                               │
    └── ApiService HTTP client ◀────┘
            │
        FastAPI routers (products, checkout, invoices, reports)
            │
        SQLAlchemy models & SQLite persistence
            │
  Postman mock API (tax authority sandbox)
```

### Mobile-to-Backend Communication
`ApiService` centralizes HTTP calls with typed deserializers for products, receipts, invoices, and reports. Each feature repository (products, invoices, reports) depends on this service, keeping widgets decoupled from request plumbing. The mobile entry point constructs shared instances of `ApiService`, `QueueService`, and `ConnectivityService`, then passes them into `SmartPosApp`, guaranteeing every screen uses the same transport configuration. 【F:mobile/lib/services/api_service.dart†L22-L136】【F:mobile/lib/data/repositories/product_repository.dart†L1-L22】【F:mobile/lib/data/repositories/invoice_repository.dart†L1-L12】【F:mobile/lib/data/repositories/report_repository.dart†L1-L8】【F:mobile/lib/main.dart†L8-L21】

### Backend Data Storage and APIs
The backend exposes CRUD operations through routers that delegate to a shared CRUD layer:

- `Product`, `Receipt`, `Invoice`, and `TaxAuthorityResponse` SQLAlchemy models normalize catalog inventory, cart checkouts, invoice payloads, and authority replies. 【F:backend/app/models.py†L10-L72】
- `crud.py` handles product CRUD, receipt creation, invoice persistence (including associated authority response records), and report aggregation (sales history and popular products). 【F:backend/app/crud.py†L15-L300】
- Each router maps HTTP verbs to these helpers: products for CRUD, checkout for receipts and tax calculations, invoices for submission/listing, and reports for summarized analytics. 【F:backend/app/routers/products.py†L1-L57】【F:backend/app/routers/checkout.py†L1-L66】【F:backend/app/routers/invoices.py†L1-L100】【F:backend/app/routers/reports.py†L1-L29】

This layering keeps controllers thin while centralizing data logic for reuse across endpoints and future job workers.

### Invoice Submission Flow
The end-to-end invoice process spans mobile and backend components:

1. Cashier reviews the receipt on `CheckoutPage` and taps **Submit Invoice**, which calls `InvoiceRepository.submitInvoice`. Failures enqueue the request locally for retry. 【F:mobile/lib/features/checkout/checkout_page.dart†L9-L77】
2. `ApiService.submitInvoice` issues `POST /invoices/submit/{receipt_id}` to FastAPI. 【F:mobile/lib/services/api_service.dart†L107-L111】
3. `submit_invoice` loads the receipt, transforms it with `InvoicePayload` (ensuring ISO 8601 timestamps), then POSTs to the configured tax authority (defaulting to the Postman mock). It stores the submission payload, normalized response, and derived status (`accepted`, `pending`, etc.) for auditing. 【F:backend/app/routers/invoices.py†L25-L91】【F:backend/app/schemas.py†L91-L135】
4. `InvoicesProvider` refreshes from `/invoices/` to surface the new record. The detail bottom sheet decodes the stored payload and authority response so operators see line items, totals, and confirmation codes without leaving the app. 【F:mobile/lib/features/invoices/invoices_provider.dart†L9-L46】【F:mobile/lib/features/invoices/invoices_page.dart†L10-L276】
5. Should the authority be unreachable, `QueueService.enqueueInvoice` persists the request in local SQLite for later processing, and `ConnectivityService` replays the queue when connectivity resumes. 【F:mobile/lib/features/checkout/checkout_page.dart†L59-L76】【F:mobile/lib/services/queue_service.dart†L20-L133】【F:mobile/lib/services/connectivity_service.dart†L8-L44】

The following sequence illustrates the happy path:

```text
CheckoutPage ▶ InvoiceRepository ▶ ApiService ──▶ FastAPI /invoices/submit
    │                                            │
    │                                            ├─▶ Tax mock (Postman) response
    │                                            └─▶ crud.create_invoice ➜ SQLite
    ▼
InvoicesProvider.reload ◀──── ApiService.getInvoices ◀──── FastAPI /invoices/
```

### Offline Queue Mechanism
To safeguard tax compliance when the device drops offline, the mobile app ships a first-class offline queue:

- `QueueService` owns an on-device SQLite table (`queue_jobs`) with payload, attempt count, and status. `processQueue` retries pending jobs sequentially, marking entries `failed` after five attempts so staff can intervene. 【F:mobile/lib/services/queue_service.dart†L11-L133】
- `ConnectivityService` initializes the queue, subscribes to network changes, and triggers periodic drains (every five minutes). When connectivity is available, it replays jobs through `ApiService.submitInvoice` and resets any previously failed attempts. 【F:mobile/lib/services/connectivity_service.dart†L8-L44】
- `InvoicesProvider` listens to the queue stream to populate the “Offline queue” list in the UI and exposes a retry button that resets a job’s status before reprocessing it immediately. 【F:mobile/lib/features/invoices/invoices_provider.dart†L9-L52】【F:mobile/lib/features/invoices/invoices_page.dart†L31-L72】

This design ensures every attempted invoice either succeeds automatically once the network is back or appears in an actionable queue so nothing is lost.

### API Documentation and Testing Tooling
API consumers benefit from two complementary documentation channels:

- **OpenAPI/Swagger** – `smartpos-openapi.json` enumerates schemas, parameters, and response codes for every route, enabling code generation and providing a ground truth for SDKs or third-party integrations. 【F:openapi/smartpos-openapi.json†L1-L200】
- **Postman collection & mock** – `postman/SmartPOS.postman_collection.json` bundles ready-to-run requests for product CRUD, checkout, invoice submission, reporting, and the mock tax authority. QA engineers can fork the collection, swap the environment variables, and replay full user journeys. The companion mock README guides creation of a sandbox endpoint for tax testing. 【F:postman/SmartPOS.postman_collection.json†L1-L116】【F:postman/mock/README.md†L1-L14】

Combined with the backend README (covering setup, seeding, and Swagger UI access), the platform ships with a documentation toolchain that streamlines onboarding. 【F:backend/README.md†L1-L41】

## Section A – Mobile POS Foundations

### Product Listing and Catalog Strategy
The catalog blends static seed items with backend-sourced inventory. `ProductsProvider` starts with `kStaticProducts`, then merges live records so the POS always has a menu even before syncing. Tabs on `ProductsPage` filter categories (`All`, `Appetizers`, `Main Courses`, `Extras & Drinks`) while the floating cart summary slides up as soon as a shopper adds items. 【F:mobile/lib/data/static_catalog.dart†L3-L127】【F:mobile/lib/features/products/products_provider.dart†L7-L256】【F:mobile/lib/features/products/products_page.dart†L17-L260】

Key decisions:

- Static IDs are negative, allowing overrides to map remote updates back onto predefined menu slots (useful for bootstrapping new environments). 【F:mobile/lib/data/static_catalog.dart†L3-L127】【F:mobile/lib/features/products/products_provider.dart†L46-L173】
- Editing a product launches a modal with reusable `AppTextField` widgets and category dropdown to keep data entry fast for staff. The dialog persists via `ProductsProvider.createProduct` or `.saveProduct`, which sync with the backend repository. 【F:mobile/lib/features/products/products_page.dart†L262-L320】【F:mobile/lib/features/products/products_provider.dart†L91-L196】

### Cart Management and Pricing Logic
`CartProvider` centralizes cart state, exposing `add`, `updateQuantity`, `remove`, and `clear`. It calculates `subtotal`, `tax` (at a fixed 16%), `discount`, and `total`, ensuring every screen uses consistent pricing math. The tax rate lives in one spot, simplifying compliance changes. 【F:mobile/lib/features/cart/cart_provider.dart†L5-L80】

`CartPage` layers a modern summary panel: after the line-item list and discount field, `_buildTotals` highlights “Total (estimate)” with supporting copy, reinforcing the hierarchy the stakeholder requested. Checkout triggers `_performCheckout`, which dispatches to the backend, shows a success modal, navigates to `CheckoutPage`, clears the cart, and refreshes reports. 【F:mobile/lib/features/cart/cart_page.dart†L33-L220】

### Receipt Generation in the Mobile App
When checkout succeeds, the app routes to `CheckoutPage`, which lists receipt items and totals for a final verification step. Receipts use typed models so rendering formats (currency, quantities) stay consistent. `CheckoutPage` also anchors the invoice submission action, bridging core POS flow and compliance tasks. 【F:mobile/lib/features/checkout/checkout_page.dart†L9-L77】【F:mobile/lib/data/models/receipt.dart†L1-L68】

On the backend, `create_receipt` recalculates line totals, applies the 16% tax, handles discounts, decrements stock, and persists the final receipt. The response is rehydrated through `receipt_to_schema`, guaranteeing the client uses authoritative server totals. 【F:backend/app/routers/checkout.py†L1-L66】【F:backend/app/crud.py†L54-L99】

### Offline Transaction Queue and Retry Mechanism
The POS must continue issuing invoices regardless of connectivity. After an `_submitInvoice` failure, `QueueService.enqueueInvoice` captures the receipt ID locally. `ConnectivityService` drains this queue on any connectivity change or every five minutes. The invoices screen surfaces pending jobs, enabling manual retries via `InvoicesProvider.retryJob`, which resets the attempt counter and reprocesses the job immediately through the repository. 【F:mobile/lib/features/checkout/checkout_page.dart†L59-L76】【F:mobile/lib/services/queue_service.dart†L20-L133】【F:mobile/lib/services/connectivity_service.dart†L17-L44】【F:mobile/lib/features/invoices/invoices_provider.dart†L20-L46】【F:mobile/lib/features/invoices/invoices_page.dart†L54-L72】

### Backend Contribution: Product CRUD Endpoints
Segment A’s backend responsibility delivered full catalog endpoints. `products.py` exposes create, list, retrieve, update, and delete functions, each delegating to `crud` helpers that operate on `models.Product`. This symmetry between routers and CRUD functions avoids duplicated validation while aligning with the OpenAPI spec. 【F:backend/app/routers/products.py†L1-L57】【F:backend/app/crud.py†L15-L52】【F:backend/app/models.py†L10-L24】

### Product Module Documentation (OpenAPI/Swagger)
The OpenAPI document defines product schemas and parameters, ensuring downstream tools understand payloads. Each method on `/products/` and `/products/{product_id}` references `Product`, `ProductCreate`, and `ProductUpdate` schemas generated from the FastAPI signatures. Maintaining this spec allows developers to auto-generate SDKs and ensures the docs always match server reality. 【F:openapi/smartpos-openapi.json†L32-L131】

## Section B – E-Invoicing and Tax Authority Integration

### Invoice JSON Schema for Tax Submissions
`InvoicePayload` mirrors the tax authority contract—receipt ID, merchant, items, totals, and timestamp—and registers a custom JSON encoder so datetime values serialize as ISO strings. This guarantees compatibility with most fiscal APIs, which reject arbitrary formats. The schema keeps items typed (`ReceiptItem`) to reuse server-side validation. 【F:backend/app/schemas.py†L91-L111】【F:backend/app/crud.py†L85-L118】

### Tax Authority API Client, Retries, and Error Handling
`submit_invoice` orchestrates integration: it rebuilds the payload from persisted receipts, calls the mock authority with a timeout, normalizes JSON or plain-text responses, and persists both request and response for auditing. Status derivation (`accepted`, `pending`, etc.) drives UI badges. On the client, `CheckoutPage._submitInvoice` wraps repository calls in try/catch—successes toast confirmation, while failures drop the job into the offline queue. This dual-layer handling ensures invoices eventually reach the authority with full traceability. 【F:backend/app/routers/invoices.py†L25-L91】【F:mobile/lib/features/checkout/checkout_page.dart†L59-L76】【F:mobile/lib/services/api_service.dart†L107-L111】【F:mobile/lib/services/queue_service.dart†L57-L133】

### Sandbox / Mock Server Strategy
Developers configure a Postman mock that mirrors the authority’s `POST /invoice`. The mock returns deterministic status, reference, and timestamp, allowing end-to-end tests without real tax infrastructure. Backend environment variables (`MOCK_TAX_API_URL`) and the Postman collection’s `mockUrl` variable ensure both server and tooling point to the same sandbox. 【F:postman/mock/README.md†L1-L14】【F:postman/SmartPOS.postman_collection.json†L1-L116】【F:backend/app/routers/invoices.py†L17-L21】

### Mobile Enhancements for Invoice Submission and Responses
`InvoicesPage` lists submitted invoices and opens a modal sheet showing receipt metadata, line items, totals, and prettified authority JSON. Chips and captions communicate status and invoice IDs at a glance. This on-device audit trail reassures staff that filings succeeded and exposes any warnings returned by the authority. The provider hydrates these views and surfaces queue jobs, coupling compliance with actionable UI. 【F:mobile/lib/features/invoices/invoices_page.dart†L10-L276】【F:mobile/lib/features/invoices/invoices_provider.dart†L9-L52】

### Backend Logging and Storage of Authority Responses
`crud.create_invoice` stores both the outbound payload and the authority reply in JSON columns. When a structured response arrives, it also inserts a `TaxAuthorityResponse` row linked to the invoice. `invoice_to_schema` returns nested response data so clients can render the original authority message. This approach centralizes auditing and simplifies reconciliation. 【F:backend/app/crud.py†L101-L167】【F:backend/app/models.py†L41-L72】【F:backend/app/schemas.py†L112-L135】

## Section C – Platform and Reporting Expansion

### Building the Backend Platform with Authentication Hooks
`app/main.py` composes routers and ensures database tables exist. While server-side auth is out of scope for the demo, the mobile app gates the UI through `AuthProvider`, requiring a preset admin credential before exposing POS features. This demonstrates how an identity layer could plug into the provider structure before hitting the backend. 【F:backend/app/main.py†L1-L38】【F:mobile/lib/app.dart†L21-L175】【F:mobile/lib/features/auth/auth_provider.dart†L1-L27】

`database.py`’s environment-driven configuration and context managers give contributors a consistent pattern for spawning sessions within routers or scripts. 【F:backend/app/database.py†L1-L44】

### Reporting Endpoints and Mobile Analytics Surfaces
`daily_report` validates the requested date, defaults to “today,” and delegates to `crud.daily_report`, which aggregates receipt counts, total sales, total tax, a seven-day sales history, and a thirty-day popular-products snapshot. On the mobile side, `ReportsProvider.loadReport` fetches the report, normalizes it into chart-friendly models, and `ReportsPage` renders summary cards, a line chart, horizontal popular product bars, and tabular breakdowns with resilient empty/loading states. 【F:backend/app/routers/reports.py†L16-L29】【F:backend/app/crud.py†L177-L300】【F:mobile/lib/features/reports/reports_provider.dart†L26-L82】【F:mobile/lib/features/reports/reports_page.dart†L10-L318】

### Database Schema and Seed Data for Testing
`seed.sql` defines the `products` table and inserts a balanced sample menu spanning appetizers, mains, extras, and drinks. Running this script gives developers consistent inventory for demos, analytics, and integration tests. The same assets are referenced in the mobile static catalog to keep imagery aligned between frontend and backend seeds. 【F:backend/seed.sql†L1-L115】【F:mobile/lib/data/static_catalog.dart†L3-L127】

### Consuming Reporting APIs in the Mobile Client
`ReportRepository` wraps `ApiService.getDailyReport`, while `ReportsProvider` tracks `selectedDate`, `isLoading`, parsed `salesByDay`, and `popularProducts`. The reports screen lets managers adjust the date via a date picker, refresh data, and inspect both graphical and tabular representations of performance. Integrating these providers at the app shell level ensures the report tab auto-loads after authentication. 【F:mobile/lib/data/repositories/report_repository.dart†L1-L8】【F:mobile/lib/features/reports/reports_provider.dart†L26-L82】【F:mobile/lib/features/reports/reports_page.dart†L10-L318】【F:mobile/lib/app.dart†L46-L89】

### Documentation and Postman Collection Contributions
Beyond the OpenAPI export, the backend README spells out environment setup, seeding, and Swagger access, providing a launchpad for new contributors. The Postman collection enumerates canonical requests across all modules, including the mock tax service, so QA can validate workflows without writing custom scripts. These artifacts ensure the technical implementation remains teachable and reproducible. 【F:backend/README.md†L1-L41】【F:postman/SmartPOS.postman_collection.json†L1-L116】

---

This report captures how the Smart POS system’s layers collaborate to deliver resilient point-of-sale operations, offline-safe invoicing, and actionable reporting for small merchants in a way that is ready for classroom walkthroughs and further experimentation.
