# jinjer API Reference

Extracted from https://doc.api.jinjer.biz/index.html (Redoc SPA) on 2026-04-30.
Source: HR platform "jinjer" (ジンジャー) by jinjer Co., Ltd.

## Base URL

```
https://api.jinjer.biz
```

## Authentication

### Token Issuance (prefer v2)

```
GET /v2/token
Headers:
  X-API-KEY: {api_key}        (required)
  X-SECRET-KEY: {secret_key}  (required)

Response 200:
  { "results": "success", "data": { "access_token": "ApplicationJWT" } }
```

- v2 supports all API key/secret pairs; v1 only supports the default pair.
- Token validity: 4 hours, no concurrent issue limit.
- Use as: `Authorization: Bearer {access_token}`

### Rate Limits

| Category | Limit |
|---|---|
| GET requests | 100/min, 1500/hour per company (200 status only) |
| Punch-clock registration | 1/sec, 60/min, 3600/hour per company |
| Other POST/PATCH/DELETE | 1 per 6sec, 10/min, 150/hour per company |
| Concurrency | 1 request at a time — wait for response before next |

## Pagination

- Default: 100 items per page.
- Use `page` query parameter for subsequent pages.
- Total count in response header `X-Item-Counts`.

## Key Endpoints for HR Organization & Employee Data

### Employees (従業員)

```
GET    /v1/employees              — List/search employees
POST   /v1/employees              — Create employee
PATCH  /v1/employees              — Update employee
```

**GET query parameters:**

| Param | Type | Description |
|---|---|---|
| page | integer | Page number |
| employee-ids | string | Comma-separated employee IDs (max 100) |
| has-since-changed-at | yyyy-MM-dd | Records created/updated after date |
| employee-last-name | string | Workplace last name |
| employee-first-name | string | Workplace first name |
| joined-on-period-start-date | yyyy-MM-dd | Joined after |
| joined-on-period-end-date | yyyy-MM-dd | Joined before |
| retirement-period-start-date | yyyy-MM-dd | Retired after |
| retirement-period-end-date | yyyy-MM-dd | Retired before |
| enrollment-classification-id | string | 0=active, 1=retired, 2=leave |
| employment-classification-id | string | Employment type ID |

**Response structure (key fields):**

```json
{
  "id": "JIN0001",
  "company": {
    "last_name": "神社",
    "first_name": "一郎",
    "last_name_phonetic": "ジンジャ",
    "first_name_phonetic": "イチロウ",
    "joined_on": "2024-04-13",
    "email": "jinjer_customer@jinjer.co.jp",
    "enrollment_classification": {"id": "", "name": ""},
    "employment_classification": {"id": "", "name": ""},
    "retirement_date": "",
    ...
  },
  "personal": {
    "last_name": "神社",
    "first_name": "一郎",
    "last_name_phonetic": "ジンジャ",
    "first_name_phonetic": "イチロウ",
    "email": "jinjer_customer@jinjer.co.jp",
    ...
  },
  "affiliations": {
    "date_of_issue": "2024-04-13",
    "change_classification": {"id": "", "name": ""},
    "department": {"id": "", "name": ""},
    "employee_post": {"id": "", "name": ""},
    "work_location": {"id": "", "name": ""},
    "job_classification": {"id": "", "name": ""},
    "duty_classification": {"id": "", "name": ""},
    "employee_grade": {"id": "", "name": "", "grade_level": {"name": ""}},
    "boss": {"employee_id": "", "last_name": "", "first_name": ""},
    ...
  }
}
```

> **Note:** GET /v1/employees returns only the **current** affiliations per
> employee. For full transfer history, use /v1/employees/affiliations.

### Employee Affiliations / Primary Assignments (従業員 主務)

```
GET    /v1/employees/affiliations    — List affiliations (transfer history)
POST   /v1/employees/affiliations    — Create affiliation
PATCH  /v1/employees/affiliations    — Update affiliation
DELETE /v1/employees/affiliations    — Delete affiliation
```

**GET query parameters:**

| Param | Type | Description |
|---|---|---|
| page | integer | Page number |
| employee-ids | string | Comma-separated employee IDs (max 100) |
| has-since-changed-at | yyyy-MM-dd | Records changed after date |
| date-of-issue-after-at | yyyy-MM-dd | Date of issue >= this date |
| date-of-issue-before-at | yyyy-MM-dd | Date of issue <= this date |
| department | string | Department ID |
| employee-post | string | Employee post ID |
| attendance-group | string | Attendance group ID |

**Response structure (affiliations is an ARRAY = full transfer history):**

```json
{
  "results": "success",
  "data": {
    "employee_id": "JIN0001",
    "affiliations": [
      {
        "id": "361493",
        "date_of_issue": "2018-02-01",
        "change_classification": {"id": "6", "name": "配属"},
        "department": {"id": "1", "name": "JinjerAPI検証株式会社"},
        "employee_post": {"id": "1", "name": "マネージャー"},
        "work_location": {"id": "1", "name": "本社"},
        "job_classification": {"id": "4", "name": "技術職"},
        "duty_classification": {"id": "1", "name": "QC"},
        "employee_grade": {"id": "826", "name": "D", "grade_level": {"name": "1等級"}},
        "boss": {"employee_id": "1", "last_name": "神社", "first_name": "太郎"},
        "roles": {
          "jinji": {"id": "1", "name": "システム管理者権限"},
          "payroll": {"id": "1", "name": "給与管理者権限"},
          ...access control roles...
        },
        "optional_classifications": [{"number": 1, "label": "", "id": "", "value": ""}],
        "attendance_group": {"id": "A01", "name": "打刻グループA01"},
        "sub_attendance_groups": [{"id": "A02", "name": "打刻グループA02"}],
        "created_at": "2020-01-01 10:00:00",
        "updated_at": "2018-01-01 10:00:00"
      }
    ]
  }
}
```

### Departments (所属グループ)

```
GET    /v1/departments           — List departments
POST   /v1/departments           — Create department
PATCH  /v1/departments           — Update department
GET    /v1/departments/{id}      — Get department detail
```

**GET /v1/departments query parameters:**

| Param | Type | Description |
|---|---|---|
| page | integer | Page number |
| status | string | `active` for active-only |
| has-since-changed-at | yyyy-MM-dd | Changed after date |
| id | string | Department ID |
| parent-department-id | string | Parent department ID |
| manager-employee-id | string | Manager employee ID |

**Detail response structure:**

```json
{
  "id": "1",
  "name": "第一営業部",
  "phonetic": "ダイイチエイギョウブ",
  "abbreviation": "一営",
  "date_of_establishment": "2024-04-13",
  "date_of_abolition": "2024-04-13",
  "parent_department_id": "1",
  "hierarchy": {"id": "1"},
  "manager_employee_id": "JIN0002",
  "accounting_department_id": "1",
  "display_order": 2,
  ...
}
```

> `parent_department_id` builds the org tree. `hierarchy.id` links to the
> hierarchy master for the level name.

### Hierarchy Master (階層マスタ)

```
GET /v1/master/hierarchies   — List all hierarchy levels (no params)
```

Returns array of hierarchy definitions. Each department's `hierarchy.id`
references a level here (e.g., "第一階層: 全社", "第二階層: 部", "第三階層: 課").

## Data Integration Strategy

For resolving org structure + employee assignments + transfer history:

1. **GET /v1/master/hierarchies** — Get hierarchy level definitions.
2. **GET /v1/departments** (paginate + status=active) — Build org tree via
   `parent_department_id`, tag each department with `hierarchy.id` → level name.
3. **GET /v1/employees** (paginate + filters) — Get current employee info
   (name, email, enrollment status).
4. **GET /v1/employees/affiliations** (paginate, optionally filter by
   employee-ids or date range) — Get full transfer history as an array per
   employee, sorted by `date_of_issue`.

**Key relationships:**

```
affiliations[].department.id → departments[].id → departments[].hierarchy.id → hierarchies[].id
affiliations[].department.id → departments[].id → departments[].parent_department_id → parent department
employees[].id = affiliations[].employee_id
```