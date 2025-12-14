# API Documentation

This project provides a RESTful API for managing products, materials, and transactions.

## Base URL

All API endpoints are prefixed with `/api`.

## Endpoints

### 1. Products

**Endpoint:** `GET /products`

**Description:** Retrieves a list of all products, including their associated materials.

**Response:**

```json
[
  {
    "id": 1,
    "name": "Kopi Susu",
    "price": 15000,
    "created_at": "2023-10-27T10:00:00.000000Z",
    "updated_at": "2023-10-27T10:00:00.000000Z",
    "materials": [
       {
         "id": 1,
         "name": "Kopi",
         "stock": 100,
         "pivot": {
            "product_id": 1,
            "material_id": 1,
            "quantity_needed": 10
         }
       }
    ]
  }
]
```

### 2. Materials

**Endpoint:** `GET /materials`

**Description:** Retrieves a list of all available raw materials and their current stock levels.

**Response:**

```json
[
  {
    "id": 1,
    "name": "Kopi",
    "stock": 100,
    "created_at": "2023-10-27T10:00:00.000000Z",
    "updated_at": "2023-10-27T10:00:00.000000Z"
  }
]
```

### 3. Transactions

**Endpoint:** `POST /transactions`

**Description:** Creates a new sales transaction. This endpoint handles stock deduction for the materials used in the purchased products.

**Request Body:**

```json
{
  "customer_name": "John Doe",
  "transaction_date": "2023-10-27",
  "items": [
    {
      "product_id": 1,
      "quantity": 2
    }
  ]
}
```

**Parameters:**

- `customer_name` (string, required): Name of the customer.
- `transaction_date` (date, required): Date of the transaction (Format: YYYY-MM-DD).
- `items` (array, required): List of items purchased.
    - `product_id` (integer, required): ID of the product.
    - `quantity` (integer, required): Quantity purchased (must be >= 1).

**Success Response (201 Created):**

```json
{
  "message": "Transaction success",
  "data": {
    "customer_name": "John Doe",
    "transaction_date": "2023-10-27",
    "total_amount": 30000,
    "updated_at": "2023-10-27T10:05:00.000000Z",
    "created_at": "2023-10-27T10:05:00.000000Z",
    "id": 1
  }
}
```

**Error Response (422 Unprocessable Content):**

If validation fails (missing fields, invalid product ID, insufficient stock check logic is not yet in API but validation exists):

```json
{
    "message": "The given data was invalid.",
    "errors": {
        "items.0.product_id": [
            "The selected items.0.product_id is invalid."
        ]
    }
}
```

**Error Response (500 Internal Server Error):**

If an exception occurs during transaction processing.

```json
{
  "message": "Error message details"
}
```
