"""Pydantic schemas for request and response bodies."""
from __future__ import annotations

from datetime import datetime, date
from typing import List, Optional

from pydantic import BaseModel, Field, validator


class ProductBase(BaseModel):
    name: str = Field(..., description="Product name")
    price: float = Field(..., gt=0, description="Unit price")
    stock: int = Field(..., ge=0, description="Inventory count")


class ProductCreate(ProductBase):
    """Payload for creating a new product."""


class ProductUpdate(BaseModel):
    name: Optional[str]
    price: Optional[float] = Field(None, gt=0)
    stock: Optional[int] = Field(None, ge=0)


class Product(ProductBase):
    id: int
    created_at: datetime

    class Config:
        orm_mode = True


class CheckoutItem(BaseModel):
    product_id: int
    qty: int = Field(..., gt=0, description="Quantity being purchased")


class CheckoutRequest(BaseModel):
    """Cart payload for creating a receipt."""

    items: List[CheckoutItem]
    discount_percent: Optional[float] = Field(0, ge=0, le=100)

    @validator("items")
    def validate_items(cls, value: List[CheckoutItem]):  # noqa: D417 - simple validator
        if not value:
            raise ValueError("Cart must contain at least one item")
        return value


class ReceiptItem(BaseModel):
    product_id: int
    name: str
    qty: int
    unit_price: float
    line_total: float


class Receipt(BaseModel):
    id: int
    items: List[ReceiptItem]
    subtotal: float
    tax: float
    discount: float
    total: float
    created_at: datetime

    class Config:
        orm_mode = True


class InvoicePayload(BaseModel):
    receipt_id: int
    merchant: str
    items: List[ReceiptItem]
    totals: dict
    timestamp: datetime


class AuthorityResponse(BaseModel):
    status: str
    reference: Optional[str] = None
    received_at: Optional[str] = None


class Invoice(BaseModel):
    id: int
    receipt_id: int
    payload_json: dict
    authority_response_json: Optional[dict]
    status: str
    created_at: datetime

    class Config:
        orm_mode = True


class InvoiceList(BaseModel):
    invoices: List[Invoice]


class DailyReport(BaseModel):
    date: date
    receipt_count: int
    total_sales: float
    total_tax: float
