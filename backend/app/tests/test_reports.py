"""Tests for reporting endpoints."""
from fastapi.testclient import TestClient


def test_daily_report_returns_totals(client: TestClient) -> None:
    # Create a product and perform checkout to generate a receipt.
    product_payload = {"name": "Samosa", "price": 4.0, "stock": 5}
    product_resp = client.post("/products/", json=product_payload)
    assert product_resp.status_code == 201
    product_id = product_resp.json()["id"]

    checkout_payload = {"items": [{"product_id": product_id, "qty": 1}]}
    receipt_resp = client.post("/checkout/", json=checkout_payload)
    assert receipt_resp.status_code == 201
    receipt = receipt_resp.json()

    report_date = receipt["created_at"][0:10]
    report_resp = client.get(f"/reports/daily?date={report_date}")
    assert report_resp.status_code == 200
    report = report_resp.json()

    assert report["receipt_count"] >= 1
    assert report["total_sales"] >= receipt["total"]
    assert report["date"] == report_date
