"""Tests for product CRUD endpoints."""
from fastapi.testclient import TestClient


def test_create_and_list_products(client: TestClient) -> None:
    payload = {
        "name": "Tea",
        "price": 1.5,
        "stock": 20,
        "category": "Drinks",
        "description": "Hot beverage",
        "image_url": "assets/images/tea.jpg",
    }
    response = client.post("/products/", json=payload)
    assert response.status_code == 201
    created = response.json()
    assert created["name"] == "Tea"
    assert created["category"] == "Drinks"
    assert created["description"] == "Hot beverage"
    assert created["image_url"] == "assets/images/tea.jpg"

    list_response = client.get("/products/")
    assert list_response.status_code == 200
    items = list_response.json()
    assert len(items) == 1
    assert items[0]["name"] == "Tea"
    assert items[0]["category"] == "Drinks"
