"""Invoice submission endpoints."""
from __future__ import annotations

import os
from datetime import datetime
import json

import requests
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from .. import crud, schemas
from ..deps import get_db

router = APIRouter()

MOCK_TAX_API_URL = os.getenv("MOCK_TAX_API_URL", "https://a9e698ab-6015-4a67-9cbf-2909dc357749.mock.pstmn.io/invoice")
MERCHANT_NAME = os.getenv("MERCHANT_NAME", "Mpepo Kitchen")

print("DEBUG: MOCK_TAX_API_URL -->", MOCK_TAX_API_URL)
print("DEBUG: MERCHANT_NAME -->", MERCHANT_NAME)



@router.post("/submit/{receipt_id}", response_model=schemas.Invoice, status_code=status.HTTP_201_CREATED)
def submit_invoice(receipt_id: int, db: Session = Depends(get_db)):
    """
    Submit a receipt as an invoice to the mock tax authority.
    """

    # Fetch receipt from DB
    receipt = crud.get_receipt(db, receipt_id)
    if not receipt:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Receipt not found")

    # Convert DB object to schema
    receipt_schema = crud.receipt_to_schema(receipt)

    # Build the payload with timestamp as ISO string
    invoice_payload = schemas.InvoicePayload(
        receipt_id=receipt_schema.id,
        merchant=MERCHANT_NAME,
        items=receipt_schema.items,
        totals={
            "subtotal": receipt_schema.subtotal,
            "tax": receipt_schema.tax,
            "discount": receipt_schema.discount,
            "total": receipt_schema.total,
        },
        timestamp=datetime.utcnow()   # keep as datetime for now
    )

    # Dump to JSON with a custom default=str to convert datetime automatically
    payload_str = invoice_payload.model_dump_json() if hasattr(invoice_payload, "model_dump_json") else json.dumps(
        invoice_payload.dict(), default=str
    )

    # Convert back to dict for requests.post
    payload = json.loads(payload_str)

    try:
        response = requests.post(MOCK_TAX_API_URL, json=payload, timeout=10)
        response.raise_for_status()

        try:
            authority_response = response.json()
        except ValueError:
            authority_response = {"raw": response.text}

    except requests.RequestException as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Failed to submit invoice: {exc}"
        ) from exc

    status_value = (
        str(authority_response.get("status", "pending")).lower()
        if isinstance(authority_response, dict)
        else "pending"
    )

    # Save invoice in DB
    invoice = crud.create_invoice(
        db,
        receipt_id=receipt_schema.id,
        payload=payload,
        authority_response=authority_response if isinstance(authority_response, dict) else None,
        status=status_value,
    )

    return crud.invoice_to_schema(invoice)


@router.get("/", response_model=schemas.InvoiceList)
def list_invoices(db: Session = Depends(get_db)):
    """
    Return previously submitted invoices.
    """
    invoices = crud.list_invoices(db)
    return schemas.InvoiceList(invoices=[crud.invoice_to_schema(inv) for inv in invoices])
