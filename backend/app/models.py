"""SQLAlchemy models for the Smart POS backend."""
from __future__ import annotations

from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import relationship

from .database import Base


class Product(Base):
    """A sellable product in the catalog."""

    __tablename__ = "products"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    price = Column(Float, nullable=False)
    stock = Column(Integer, nullable=False, default=0)
    description = Column(Text, nullable=True)
    category = Column(String(100), nullable=True)
    image_url = Column(String(512), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class Receipt(Base):
    """A finalized sale with the computed totals."""

    __tablename__ = "receipts"

    id = Column(Integer, primary_key=True, index=True)
    items_json = Column(Text, nullable=False)
    subtotal = Column(Float, nullable=False)
    tax = Column(Float, nullable=False)
    discount = Column(Float, nullable=False, default=0.0)
    total = Column(Float, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    invoices = relationship("Invoice", back_populates="receipt")


class Invoice(Base):
    """Invoice submission payloads and responses."""

    __tablename__ = "invoices"

    id = Column(Integer, primary_key=True, index=True)
    receipt_id = Column(Integer, ForeignKey("receipts.id"), nullable=False)
    payload_json = Column(Text, nullable=False)
    authority_response_json = Column(Text, nullable=True)
    status = Column(String(32), nullable=False, default="pending")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    receipt = relationship("Receipt", back_populates="invoices")
    tax_response = relationship(
        "TaxAuthorityResponse",
        back_populates="invoice",
        cascade="all, delete-orphan",
        uselist=False,
    )


class TaxAuthorityResponse(Base):
    """Individual responses returned by the tax authority."""

    __tablename__ = "tax_authority_responses"

    id = Column(Integer, primary_key=True, index=True)
    invoice_id = Column(Integer, ForeignKey("invoices.id"), nullable=False, unique=True)
    response_json = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    invoice = relationship("Invoice", back_populates="tax_response")
