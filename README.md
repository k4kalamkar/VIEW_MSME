# VIEW_MSME

Oracle SQL View for MSME Vendor Outstanding, Payment Tracking, Interest Calculation, and Compliance Monitoring.

---

## Features

- MSME Supplier Classification
- Vendor Outstanding Ageing
- Payment Allocation Tracking
- Top 5 Payment References
- MSME Due Date Calculation
- Interest Calculation
- Advance Payment Tracking
- Fully Paid / Partial / Unpaid Status
- Allocation Bucket Analysis
- GRN Due Days Mapping
- Unallocated Amount Calculation

---

## Database Compatibility

- Oracle 11g
- Oracle 12c
- Oracle 19c

---

## Main Tables Used

| Table/View | Purpose |
|---|---|
| `view_bills_ageing` | Base bill ageing data |
| `payment_allocation_transactions` | Payment allocation details |
| `account_master` | MSME supplier master |
| `account_transations` | Bank & instrument details |
| `view_purchase_engine` | GRN & order due days |
| `VIEW_SUPPLIER_TYPE` | Supplier type mapping |

---

# MSME Classification

| Code | MSME Type |
|---|---|
| 0 | Declaration as Not MSME |
| 1 | Medium Enterprise |
| 2 | Small Enterprise |
| 3 | Micro Enterprise |

---

# Important Calculations

## MSME Allowed Days

```sql
LEAST(NVL(order_duedays, 15), 45)
```

- Default Due Days = 15
- Maximum Allowed = 45

---

## MSME Due Date

```sql
vrdate + LEAST(NVL(order_duedays, 15), 45)
```

---

## MSME Delay Days

```sql
CASE
    WHEN SYSDATE > due_date
    THEN TRUNC(SYSDATE) - TRUNC(due_date)
    ELSE 0
END
```

---

## Interest Calculation

```sql
ROUND(
    ((NVL(due_amt,0) * NVL(intrate,0)) / 100 / 365) *
    (SYSDATE - (partybilldate + 46))
)
```

---

# Payment Status Logic

| Condition | Status |
|---|---|
| No Allocation | UNPAID |
| Partial Allocation | PARTIALLY PAID |
| Exact Allocation | FULLY PAID |
| Excess Allocation | OVER PAID |

---

# Allocation Buckets

## 0–45 Days Allocation

Tracks payments completed within MSME compliance period.

Columns:
- `count_0_45`
- `dr_alloc_amt_0_45`

---

## Above 45 Days Allocation

Tracks delayed payments beyond MSME allowed period.

Columns:
- `count_45_above`
- `dr_alloc_amt_45_above`

---

# Top 5 Payment Tracking

```sql
dr_vrno1
dr_vrno2
dr_vrno3
dr_vrno4
dr_vrno5

dr_vrdate1
dr_vrdate2
dr_vrdate3
dr_vrdate4
dr_vrdate5

dr_alloc_amt_1
dr_alloc_amt_2
dr_alloc_amt_3
dr_alloc_amt_4
dr_alloc_amt_5
```

Useful for:
- Vendor Reconciliation
- Audit Reporting
- Payment History Tracking

---

# Key Output Columns

| Column | Description |
|---|---|
| `vrno` | Voucher Number |
| `vrdate` | Voucher Date |
| `partybillno` | Vendor Bill Number |
| `partybilldate` | Vendor Bill Date |
| `acc_code` | Supplier Code |
| `acc_name` | Supplier Name |
| `msme_reg_type` | MSME Category |
| `due_amt` | Outstanding Amount |
| `payment_status` | Payment Status |
| `msme_due_date` | MSME Due Date |
| `msme_diff_days` | Overdue Days |
| `int_amt` | Interest Amount |
| `unallocated_amt` | Unallocated Amount |
| `balance` | Current Balance |

---

# Business Use Cases

- MSME Compliance Reporting
- Vendor Payment Monitoring
- Delayed Payment Analysis
- Interest Liability Calculation
- Audit & Reconciliation
- ERP Dashboard Reporting
- Outstanding Ageing Analysis

---

# Performance Optimizations

- Modular CTE Design
- Aggregation Before Joins
- Analytic Functions
- Reduced Scalar Subqueries
- Pre-Aggregated Allocation Summary
- Optimized LEFT JOIN Usage

---

# Example Queries

## Unpaid Vendors

```sql
SELECT *
FROM VIEW_MSME
WHERE payment_status = 'UNPAID';
```

---

## Delayed MSME Payments

```sql
SELECT *
FROM VIEW_MSME
WHERE msme_diff_days > 45
ORDER BY msme_diff_days DESC;
```

---

## Fully Paid Vendors

```sql
SELECT *
FROM VIEW_MSME
WHERE payment_status = 'FULLY PAID';
```

---

## Partial Payments

```sql
SELECT *
FROM VIEW_MSME
WHERE payment_status = 'PARTIALLY PAID';
```

---

# Author

**Prashant Kalamkar**

Oracle SQL Developer | ERP Reporting | MSME Compliance Reporting

---

# License

This project is intended for internal ERP and reporting usage.
