# Smart POS Mobile (Flutter)

This Flutter application is a minimal point-of-sale client for Mpepo Kitchen. It covers
product CRUD, cart checkout, invoice submission with an offline retry queue and a daily
sales report view.

## Getting started

1. Install Flutter 3.10 or newer.
2. Fetch dependencies and run the app:

   ```bash
   flutter pub get
   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
   ```

   Update the API base URL to match where the FastAPI backend runs.

3. The Android emulator uses `10.0.2.2` to access localhost. On physical devices, replace it
   with your computer's LAN IP and ensure the backend is reachable.

## Offline invoice queue

If the device is offline or the invoice submission fails, the job is stored in a local
`sqflite` database. A connectivity listener automatically retries pending jobs when the
network returns. You can also manually retry failed jobs from the **Invoices** tab.

## Tests

A lightweight widget smoke test lives under `test/`:

```bash
flutter test
```
