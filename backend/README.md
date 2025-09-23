# Smart POS Backend

This directory contains the FastAPI application that powers the Smart POS demo. It exposes
product management, checkout, invoice submission and reporting endpoints backed by SQLite.

## Getting started

1. Create a virtual environment and install dependencies:

   ```bash
   python -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   ```

2. Copy `.env.example` to `.env` and update values if required. The defaults point to a
   local SQLite database and a placeholder Postman mock URL.

3. (Optional) Seed the database with sample products before running the API:

   ```bash
   sqlite3 smartpos.db < seed.sql
   ```

4. Launch the API with uvicorn:

   ```bash
   uvicorn app.main:app --reload
   ```

5. Open http://127.0.0.1:8000/docs to explore the interactive Swagger UI. A static OpenAPI
   export is also available at `../openapi/smartpos-openapi.json`.

## Running tests

Unit tests live under `app/tests`. Execute them with pytest:

```bash
pytest
```

The tests spin up an isolated SQLite database file so they do not affect development data.
