# Mpepo Kitchen Smart POS

A minimal point of sale system demonstrating a FastAPI backend and a Flutter mobile
application. It covers product management, checkout and receipt generation, invoice
submission to a mock tax authority, daily sales reporting and an offline submission queue
for invoices on the mobile client.

## Repository structure

```
mpepo_pos/
  backend/        # FastAPI + SQLite API
  mobile/         # Flutter client app (Android focused)
  openapi/        # Static OpenAPI export
  postman/        # Postman collection and mock notes
```

## Backend (FastAPI)

See [`backend/README.md`](backend/README.md) for detailed setup instructions. In short:

1. Create a virtual environment and install dependencies (`pip install -r requirements.txt`).
2. Copy `.env.example` to `.env` and adjust values if required.
3. (Optional) seed products with `sqlite3 smartpos.db < seed.sql`.
4. Start the API with `uvicorn app.main:app --reload`.
5. Visit `http://127.0.0.1:8000/docs` for interactive documentation or use the static
   definition in [`openapi/smartpos-openapi.json`](openapi/smartpos-openapi.json).

### Backend tests

Run `pytest` from the `backend/` directory after installing dependencies. Tests cover
product CRUD, checkout totals and the daily report endpoint.

## Mobile (Flutter)

Instructions for the Flutter client live in [`mobile/README.md`](mobile/README.md). Key
steps:

1. Install Flutter 3.10+ and run `flutter pub get` from `mobile/`.
2. Launch the app with `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000`.
3. Use the bottom navigation to manage products, manage the cart, submit invoices and review
   daily sales.

The mobile client maintains an offline queue for invoice submissions. Failed jobs are saved
to local storage and retried automatically when connectivity is restored via
`connectivity_plus`. A manual retry option is also provided on the Invoices tab.

### Flutter tests

A lightweight widget smoke test is available under `mobile/test`. Execute with `flutter test`.

## Postman mock server

The `postman/` directory contains a ready-to-import collection and notes for configuring a
Postman mock server for the tax authority endpoint.
