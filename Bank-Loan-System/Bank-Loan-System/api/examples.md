# API — Примеры запросов и ответов

Согласовано с `openapi.yaml`. Базовый URL: `https://api.novabank.example/v1`

---

## 1. POST /register — Регистрация клиента

**Request**
```json
POST /register
Content-Type: application/json

{
  "email": "ivan.petrov@example.com",
  "phone": "+79161234567",
  "full_name": "Петров Иван Сергеевич",
  "birth_date": "1990-05-14",
  "password": "SecurePass123"
}
```

**Response `201 Created`**
```json
{
  "id": 101,
  "email": "ivan.petrov@example.com",
  "phone": "+79161234567",
  "full_name": "Петров Иван Сергеевич",
  "status": "pending_verification",
  "created_at": "2026-07-07T10:15:00Z"
}
```

**Response `409 Conflict`**
```json
{
  "error_code": "EMAIL_ALREADY_EXISTS",
  "message": "Email уже используется",
  "timestamp": "2026-07-07T10:15:00Z"
}
```

---

## 2. POST /login — Аутентификация

**Request**
```json
POST /login
Content-Type: application/json

{
  "email": "ivan.petrov@example.com",
  "password": "SecurePass123"
}
```

**Response `200 OK`**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMDEiLCJyb2xlIjoiY2xpZW50In0.signature",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

**Response `401 Unauthorized`**
```json
{
  "error_code": "INVALID_CREDENTIALS",
  "message": "Неверный email или пароль",
  "timestamp": "2026-07-07T10:16:00Z"
}
```

---

## 3. POST /loan-application — Подача заявки на кредит

**Request**
```json
POST /loan-application
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
Content-Type: application/json

{
  "requested_amount": 500000,
  "term_months": 24,
  "purpose": "На ремонт"
}
```

**Response `201 Created` — направлено на ручную проверку**
```json
{
  "id": 101,
  "user_id": 55,
  "requested_amount": 500000,
  "term_months": 24,
  "purpose": "На ремонт",
  "status": "MANUAL_REVIEW",
  "created_at": "2026-07-07T10:20:00Z",
  "decision_date": null,
  "scoring": {
    "score": 650,
    "decision": "MANUAL_REVIEW",
    "model_version": "v1.0"
  }
}
```

**Response `403 Forbidden` — активная просрочка**
```json
{
  "error_code": "ACTIVE_OVERDUE_EXISTS",
  "message": "Невозможно подать заявку при наличии просроченной задолженности",
  "timestamp": "2026-07-07T10:20:00Z"
}
```

---

## 4. GET /loan-application/{id} — Статус заявки

**Request**
```
GET /loan-application/101
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
```

**Response `200 OK` — заявка одобрена автоматически**
```json
{
  "id": 101,
  "user_id": 55,
  "requested_amount": 500000,
  "term_months": 24,
  "purpose": "На ремонт",
  "status": "APPROVED",
  "created_at": "2026-07-07T10:20:00Z",
  "decision_date": "2026-07-07T10:20:04Z",
  "scoring": {
    "score": 742,
    "decision": "APPROVE",
    "model_version": "v1.0"
  }
}
```

---

## 5. POST /documents — Загрузка документа

**Request**
```
POST /documents
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
Content-Type: multipart/form-data; boundary=----WebKitFormBoundary

------WebKitFormBoundary
Content-Disposition: form-data; name="application_id"

101
------WebKitFormBoundary
Content-Disposition: form-data; name="doc_type"

income_certificate
------WebKitFormBoundary
Content-Disposition: form-data; name="file"; filename="income.pdf"
Content-Type: application/pdf

<binary data>
------WebKitFormBoundary--
```

**Response `201 Created`**
```json
{
  "id": 501,
  "application_id": 101,
  "doc_type": "income_certificate",
  "file_url": "/storage/docs/income_101.pdf",
  "uploaded_at": "2026-07-07T10:22:00Z",
  "verified": false
}
```

---

## 6. GET /loan/{id} — Информация о кредите

**Request**
```
GET /loan/42
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
```

**Response `200 OK`**
```json
{
  "id": 42,
  "application_id": 101,
  "principal_amount": 500000,
  "interest_rate": 18.9,
  "term_months": 24,
  "monthly_payment": 24875.32,
  "status": "ACTIVE",
  "issue_date": "2026-07-08",
  "contract_number": "NB-2026-00042"
}
```

---

## 7. GET /payments — График платежей / история оплат

**Request**
```
GET /payments?loan_id=42&status=PLANNED
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
```

**Response `200 OK`**
```json
[
  {
    "id": 9001,
    "loan_id": 42,
    "due_date": "2026-08-08",
    "amount": 24875.32,
    "paid_date": null,
    "paid_amount": null,
    "status": "PLANNED"
  },
  {
    "id": 9002,
    "loan_id": 42,
    "due_date": "2026-09-08",
    "amount": 24875.32,
    "paid_date": null,
    "paid_amount": null,
    "status": "PLANNED"
  }
]
```

---

## Общий формат ошибки

Все ошибки возвращаются в едином формате:

```json
{
  "error_code": "VALIDATION_ERROR",
  "message": "Человекочитаемое описание ошибки на русском",
  "timestamp": "2026-07-07T10:20:00Z"
}
```

| error_code | HTTP статус | Описание |
|---|---|---|
| VALIDATION_ERROR | 400 | Некорректные входные данные |
| EMAIL_ALREADY_EXISTS | 409 | Email уже зарегистрирован |
| INVALID_CREDENTIALS | 401 | Неверный логин/пароль |
| ACCOUNT_LOCKED | 423 | Аккаунт заблокирован после превышения попыток входа |
| ACTIVE_OVERDUE_EXISTS | 403 | Запрет подачи заявки при активной просрочке |
| NOT_FOUND | 404 | Ресурс не найден |
| UNAUTHORIZED | 401 | Отсутствует/невалиден токен доступа |
