# OSC Data Files

**Source:** https://wwe1.osc.state.ny.us/localgov/findata/financial-data-for-local-governments.cfm

**Download Date:** 2026-01-26

## Download Instructions

1. Go to the OSC Financial Data page (link above)
2. Select: **Revenue, Expenditure and Balance Sheet Data**
3. Select: **Single Class of Government for All Years**
4. Select: **City**
5. Click Download

**Note:** Download is a folder (not ZIP) containing one CSV per year.

## File Structure

```
city_all_years/
├── 1995_City.csv
├── 1996_City.csv
├── ...
├── 2024_City.csv
├── 2025_City.csv  (partial - current year)
└── 2026_City.csv  (empty - future year)
```

## CSV Columns

| Column | Example | Description |
|--------|---------|-------------|
| `CALENDAR_YEAR` | 2023 | Fiscal year |
| `MUNICIPAL_CODE` | 010201000000 | 12-digit OSC entity code |
| `ENTITY_NAME` | City of Albany | Official name |
| `CLASS_DESCRIPTION` | City | Government type |
| `COUNTY` | Albany | County location |
| `PERIOD_START` | 2023-01-01 | Fiscal period start |
| `PERIOD_END` | 2023-12-31 | Fiscal period end |
| `ACCOUNT_CODE` | A31201 | OSC account code (no dots) |
| `ACCOUNT_CODE_NARRATIVE` | Police | Account description |
| `ACCOUNT_CODE_SECTION` | EXPENDITURE | REVENUE, EXPENDITURE, or BALANCE_SHEET |
| `LEVEL_1_CATEGORY` | Public Safety | High-level category |
| `LEVEL_2_CATEGORY` | Police | Sub-category |
| `OBJECT_OF_EXPENDITURE` | Personal Services | Object class (expenditures only) |
| `AMOUNT` | 37566026 | Dollar amount |
| `SNAPSHOT_DATE` | 2025-12-31 | Data snapshot date |

## Account Code Format

Codes are 5+ characters without dots (differs from PLAN.md assumption):

```
A31201
│ │  │
│ │  └── Object: 1=Personal Services, 2=Equipment, 4=Contractual, 8=Benefits
│ │
│ └───── Function: 3120=Police, 3410=Fire, 8160=Sanitation
│
└────── Fund: A=General
```

## Key Account Codes

| Code | Description |
|------|-------------|
| A1001 | Real Property Taxes |
| A31201-8 | Police (PS/Equip/Contract/Benefits) |
| A34101-8 | Fire Protection |
| A81601-8 | Refuse and Garbage (Sanitation) |

## NYC Data

**Important:** NYC is **never** in OSC data. NYC has its own elected Comptroller and is explicitly excluded from the OSC AFR system.

For ALL NYC financial data:
- **Source:** https://checkbooknyc.com/ (launched July 2010)
- **data_source:** `nyc_checkbook`
- Pre-2010 data may require NYC Comptroller archives or CAFR reports

## Data Notes

- Amounts may include decimals (e.g., `3619538.81`)
- Fiscal years vary by city (calendar year vs July-June)
- 2023 file has ~20,000 rows covering all 62 cities
- 2025/2026 files have incomplete data (current/future years)
