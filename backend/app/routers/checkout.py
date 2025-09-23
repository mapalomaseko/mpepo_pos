"""Checkout endpoint for creating receipts."""
from __future__ import annotations

import os
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from .. import crud, schemas
from ..deps import get_db

router = APIRouter()

TAX_RATE = float(os.getenv("TAX_RATE", "0.16"))


@router.post("/", response_model=schemas.Receipt, status_code=status.HTTP_201_CREATED)
def create_receipt(payload: schemas.CheckoutRequest, db: Session = Depends(get_db)):
    """Create a receipt from cart items and compute totals."""

    computed_items: List[schemas.ReceiptItem] = []
    subtotal = 0.0

    for item in payload.items:
        product = crud.get_product(db, item.product_id)
        if not product:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Product {item.product_id} not found")
        if product.stock < item.qty:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Insufficient stock for {product.name}",
            )

        line_total = round(product.price * item.qty, 2)
        subtotal += line_total

        # Reduce inventory so stock levels stay accurate.
        product.stock -= item.qty

        computed_items.append(
            schemas.ReceiptItem(
                product_id=product.id,
                name=product.name,
                qty=item.qty,
                unit_price=product.price,
                line_total=line_total,
            )
        )

    subtotal = round(subtotal, 2)
    tax = round(subtotal * TAX_RATE, 2)
    discount_percent = payload.discount_percent or 0
    discount = round(subtotal * (discount_percent / 100), 2)
    total = round(subtotal + tax - discount, 2)

    receipt = crud.create_receipt(
        db,
        items=computed_items,
        subtotal=subtotal,
        tax=tax,
        discount=discount,
        total=total,
    )

    return crud.receipt_to_schema(receipt)
