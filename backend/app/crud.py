"""Database helper functions."""
from __future__ import annotations

import json
from collections import defaultdict
from datetime import date, datetime, timedelta
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
        authority_response_json=json.dumps(authority_response) if authority_response is not None else None,
        status=status,
    )
    db.add(invoice)
    db.flush()

    if authority_response is not None:
        if not isinstance(authority_response, (dict, list)):
            authority_payload = {"raw": authority_response}
        else:
            authority_payload = authority_response
        response_record = models.TaxAuthorityResponse(
            invoice_id=invoice.id,
            response_json=json.dumps(authority_payload),
        )
        db.add(response_record)

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
    tax_response = None
    if invoice.tax_response:
        tax_response_payload = json.loads(invoice.tax_response.response_json)
        tax_response = schemas.TaxAuthorityResponseRecord(
            id=invoice.tax_response.id,
            invoice_id=invoice.tax_response.invoice_id,
            response=tax_response_payload,
            created_at=invoice.tax_response.created_at,
        )
    return schemas.Invoice(
        id=invoice.id,
        receipt_id=invoice.receipt_id,
        payload_json=payload,
        authority_response_json=authority_response,
        status=invoice.status,
        created_at=invoice.created_at,
        tax_authority_response=tax_response,
    )


def _sales_by_day(db: Session, *, end_date: date, days: int) -> List[schemas.SalesByDay]:
    """Return total sales for each day in the provided window."""

    start_date = end_date - timedelta(days=days - 1)
    start_dt = datetime.combine(start_date, datetime.min.time())
    end_dt = datetime.combine(end_date, datetime.max.time())

    date_expr = func.date(models.Receipt.created_at)
    rows = (
        db.query(
            date_expr.label("day"),
            func.coalesce(func.sum(models.Receipt.total), 0).label("total"),
        )
        .filter(models.Receipt.created_at >= start_dt, models.Receipt.created_at <= end_dt)
        .group_by(date_expr)
        .all()
    )

    totals_by_day = {}
    for row in rows:
        day_value = row.day
        if isinstance(day_value, str):
            day_value = datetime.strptime(day_value, "%Y-%m-%d").date()
        totals_by_day[day_value] = float(row.total or 0)

    history: List[schemas.SalesByDay] = []
    for index in range(days):
        current_date = start_date + timedelta(days=index)
        total = round(totals_by_day.get(current_date, 0.0), 2)
        history.append(schemas.SalesByDay(date=current_date, total_sales=total))

    return history


def _popular_products(
    db: Session,
    *,
    start_date: date,
    end_date: date,
    limit: int,
) -> List[schemas.PopularProduct]:
    """Aggregate the most sold products within the provided range."""

    start_dt = datetime.combine(start_date, datetime.min.time())
    end_dt = datetime.combine(end_date, datetime.max.time())

    receipts = (
        db.query(models.Receipt)
        .filter(models.Receipt.created_at >= start_dt, models.Receipt.created_at <= end_dt)
        .all()
    )

    aggregates: defaultdict[int, dict] = defaultdict(
        lambda: {
            "product_id": 0,
            "name": "",
            "quantity_sold": 0,
            "total_sales": 0.0,
        }
    )

    for receipt in receipts:
        items_payload = json.loads(receipt.items_json)
        for item in items_payload:
            product_identifier = item.get("product_id")
            if product_identifier is None:
                continue
            product_id = int(product_identifier)
            quantity = int(item.get("qty") or item.get("quantity") or 0)
            line_total = float(item.get("line_total") or 0.0)
            product_name = item.get("name") or "Unknown"

            aggregate = aggregates[product_id]
            aggregate["product_id"] = product_id
            aggregate["name"] = aggregate["name"] or product_name
            aggregate["quantity_sold"] += quantity
            aggregate["total_sales"] += line_total

    # Fetch latest product names for consistency
    product_names = {
        product_id: product_name
        for product_id, product_name in db.query(models.Product.id, models.Product.name)
    }

    popular = sorted(
        (
            schemas.PopularProduct(
                product_id=data["product_id"],
                name=product_names.get(data["product_id"], data["name"]),
                quantity_sold=int(data["quantity_sold"]),
                total_sales=round(float(data["total_sales"]), 2),
            )
            for data in aggregates.values()
            if data["quantity_sold"] > 0
        ),
        key=lambda product: (product.quantity_sold, product.total_sales),
        reverse=True,
    )

    return popular[:limit]


def daily_report(db: Session, target_date: date) -> schemas.DailyReport:
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
    history_days = 7
    popular_window_days = 30
    sales_history = _sales_by_day(db, end_date=target_date, days=history_days)
    popular_products = _popular_products(
        db,
        start_date=target_date - timedelta(days=popular_window_days - 1),
        end_date=target_date,
        limit=5,
    )

    return schemas.DailyReport(
        date=target_date,
        receipt_count=receipt_count,
        total_sales=float(total_sales or 0),
        total_tax=float(total_tax or 0),
        sales_by_day=sales_history,
        popular_products=popular_products,
    )
