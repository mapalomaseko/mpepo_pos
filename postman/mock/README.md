# Mock tax authority

Create a Postman mock server with a single `POST /invoice` endpoint returning:

```json
{
  "status": "ACCEPTED",
  "reference": "TA-INV-12345",
  "received_at": "{{timestamp}}"
}
```

Update `MOCK_TAX_API_URL` in `.env` (backend) and the `mockUrl` variable in the Postman
collection to point to the generated mock server URL.
