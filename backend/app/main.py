"""Entrypoint for the Smart POS API."""
from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .database import Base, engine
from .routers import checkout, invoices, products, reports

app = FastAPI(title="Smart POS API", version="0.1.0")


@app.on_event("startup")
def startup_event() -> None:
    """Ensure database tables exist before serving requests."""

    Base.metadata.create_all(bind=engine)


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(products.router, prefix="/products", tags=["products"])
app.include_router(checkout.router, prefix="/checkout", tags=["checkout"])
app.include_router(invoices.router, prefix="/invoices", tags=["invoices"])
app.include_router(reports.router, prefix="/reports", tags=["reports"])


@app.get("/", tags=["health"])
def health_check():
    """Simple health endpoint for uptime monitoring."""

    return {"status": "ok"}
