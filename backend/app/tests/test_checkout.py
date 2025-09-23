"""Tests for checkout calculations."""
from fastapi.testclient import TestClient


def test_checkout_creates_receipt_with_totals(client: TestClient) -> None:
    product_payload = {"name": "Ugali", "price": 10.0, "stock": 10}
    create_resp = client.post("/products/", json=product_payload)
    assert create_resp.status_code == 201
    product_id = create_resp.json()["id"]

    checkout_payload = {
        "items": [{"product_id": product_id, "qty": 2}],
        "discount_percent": 10,
    }
    receipt_resp = client.post("/checkout/", json=checkout_payload)
    assert receipt_resp.status_code == 201
    receipt = receipt_resp.json()

    assert receipt["subtotal"] == 20.0
    assert receipt["tax"] == 3.2
    assert receipt["discount"] == 2.0
    assert receipt["total"] == 21.2
    assert receipt["items"][0]["line_total"] == 20.0
