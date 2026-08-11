# RuStore Android Premium (Flutter)

Robokassa (Web / Windows) **не менялся**. Android RuStore — отдельный in-app flow.

## Разница с Robokassa

| | Robokassa | RuStore |
|--|-----------|---------|
| Где платит | Browser / SDK → URL / params | Внутри приложения (Pay SDK) |
| Backend create | `POST .../premium/checkout/` → `checkout_url` / `sdk` | **Нет** checkout URL |
| Подтверждение | ResultURL callback | `POST .../rustore/verify/` + RuStore Public API |
| Premium | Только после проверки backend | Только после проверки backend |

## Flutter flow

1. `GET /api/v1/mobile/premium/tariffs/` — взять `rustore_product_id` (`otter_month` / `otter_year`).
2. Pay SDK: купить `productId`, при старте передать **`appUserId = backend user id`** (строка).
3. После успеха SDK:

```http
POST /api/v1/mobile/premium/rustore/verify/
Authorization: Bearer <access>
Content-Type: application/json

{
  "productId": "otter_month",
  "purchaseId": "3aa0c7bd-964e-4562-b218-fe365adb4ae3",
  "orderId": "optional",
  "packageName": "com.company.otter"
}
```

4. Успех → смотреть `subscription.is_premium` (или `GET .../premium/subscription/`).
5. **Не** включать premium локально по ответу SDK.

## Ответы verify

```json
{
  "code": "SUBSCRIPTION_CREATED",
  "provider": "rustore",
  "subscription": { "is_premium": true, "provider": "rustore", "...": "..." },
  "payment": { "status": "paid", "provider": "rustore", "...": "..." }
}
```

| code | HTTP | Значение |
|------|------|----------|
| `SUBSCRIPTION_CREATED` | 200 | Новая активация |
| `SUBSCRIPTION_RESTORED` | 200 | Та же покупка / restore |
| `ACTIVE_SUBSCRIPTION_EXISTS` | 409 | Уже есть активный premium (в т.ч. Robokassa) |
| `INVALID_PRODUCT` | 400 | Неизвестный productId |
| `PURCHASE_NOT_FOUND` | 400 | RuStore не нашёл покупку |
| `VERIFICATION_FAILED` | 400/503 | Невалидно / API ошибка |
| `SUBSCRIPTION_EXPIRED` | 400 | Срок в RuStore уже истёк |

## Другие endpoint’ы

- `GET /api/v1/mobile/premium/subscription/` — статус (`provider`, `is_premium`, …)
- `POST /api/v1/mobile/premium/rustore/restore/` — body опционален; можно повторно прислать `purchaseId`
- `POST /api/v1/mobile/premium/cancel/` — выключить auto-renew (premium до `premium_until`)

## Env (сервер)

```
RUSTORE_KEY_ID=
RUSTORE_PRIVATE_KEY=
RUSTORE_PACKAGE_NAME=com.your.app
RUSTORE_APP_ID=
RUSTORE_IS_SANDBOX=1
```

В Admin → Тарифы: поле **RuStore productId** должно совпадать с Console (`otter_month`, `otter_year`).

## Важно для Flutter

- Premium только из backend status.
- `purchaseId` (UUID), не Google `purchaseToken`.
- Private key RuStore **только на backend**.
