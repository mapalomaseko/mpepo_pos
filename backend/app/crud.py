"""Database helper functions."""
from __future__ import annotations

import json
from typing import Iterable, List, Optional

from sqlalchemy import func
from sqlalchemy.orm import Session

from . import models, schemas


def list_products(db: Session) -> List[models.Product]:
    """Return all products sorted by newest first."""

    return db.query(models.Product).order_by(models.Product.created_at.desc()).all()


def get_product(db: Session, product_id: int) -> Optional[models.Product]:
    """Fetch a single product by identifier."""

    return db.query(models.Product).filter(models.Product.id == product_id).first()


def create_product(db: Session, payload: schemas.ProductCreate) -> models.Product:
    """Create a new product entry."""

    product = models.Product(**payload.dict())
    db.add(product)
    db.commit()
    db.refresh(product)
    return product


def update_product(db: Session, product: models.Product, payload: schemas.ProductUpdate) -> models.Product:
    """Apply updates to an existing product."""

    for key, value in payload.dict(exclude_unset=True).items():
        setattr(product, key, value)
    db.commit()
    db.refresh(product)
    return product


def delete_product(db: Session, product: models.Product) -> None:
    """Delete a product from the catalog."""

    db.delete(product)
    db.commit()


def create_receipt(
    db: Session,
    *,
    items: Iterable[schemas.ReceiptItem],
    subtotal: float,
    tax: float,
    discount: float,
    total: float,
) -> models.Receipt:
    """Persist a receipt and return the model instance."""

    items_json = json.dumps([item.dict() for item in items])
    receipt = models.Receipt(
        items_json=items_json,
        subtotal=subtotal,
        tax=tax,
        discount=discount,
        total=total,
    )
    db.add(receipt)
    db.commit()
    db.refresh(receipt)
    return receipt


def get_receipt(db: Session, receipt_id: int) -> Optional[models.Receipt]:
    """Fetch a receipt by id."""

    return db.query(models.Receipt).filter(models.Receipt.id == receipt_id).first()


def receipt_to_schema(receipt: models.Receipt) -> schemas.Receipt:
    """Convert a Receipt ORM object to its API representation."""

    items_payload = json.loads(receipt.items_json)
    items = [schemas.ReceiptItem(**item) for item in items_payload]
    return schemas.Receipt(
        id=receipt.id,
        items=items,
        subtotal=receipt.subtotal,
        tax=receipt.tax,
        discount=receipt.discount,
        total=receipt.total,
        created_at=receipt.created_at,
    )


def create_invoice(
    db: Session,
    *,
    receipt_id: int,
    payload: dict,
    authority_response: Optional[dict],
    status: str,
) -> models.Invoice:
    """Store invoice submission details."""

    invoice = models.Invoice(
        receipt_id=receipt_id,
        payload_json=json.dumps(payload),
        authority_response_json=json.dumps(authority_response) if authority_response else None,
        status=status,
    )
    db.add(invoice)
    db.commit()
    db.refresh(invoice)
    return invoice


def list_invoices(db: Session) -> List[models.Invoice]:
    """Return invoices ordered by most recent first."""

    return db.query(models.Invoice).order_by(models.Invoice.created_at.desc()).all()


def invoice_to_schema(invoice: models.Invoice) -> schemas.Invoice:
    """Convert ORM invoice to API schema."""

    payload = json.loads(invoice.payload_json)
    authority_response = json.loads(invoice.authority_response_json) if invoice.authority_response_json else None
    return schemas.Invoice(
        id=invoice.id,
        receipt_id=invoice.receipt_id,
        payload_json=payload,
        authority_response_json=authority_response,
        status=invoice.status,
        created_at=invoice.created_at,
    )


def daily_report(db: Session, target_date) -> schemas.DailyReport:
    """Compute aggregates for the provided date."""

    date_expr = func.date(models.Receipt.created_at)
    totals = (
        db.query(
            func.count(models.Receipt.id),
            func.coalesce(func.sum(models.Receipt.total), 0),
            func.coalesce(func.sum(models.Receipt.tax), 0),
        )
        .filter(date_expr == target_date)
        .one()
    )
    receipt_count, total_sales, total_tax = totals
    return schemas.DailyReport(
        date=target_date,
        receipt_count=receipt_count,
        total_sales=float(total_sales or 0),
        total_tax=float(total_tax or 0),
    )
