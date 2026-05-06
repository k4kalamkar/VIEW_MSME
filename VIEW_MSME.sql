CREATE OR REPLACE VIEW VIEW_MSME  AS
WITH

/* ================= ACC MASTER ================= */
ACC AS (
    SELECT acc_code,
           panno,
           intrate,
           sub_ledger_flag,
           ssi_regno,
           ssi_reg_date,
           acc_sch,
           SUPPLIER_TYPE,
           DECODE(sub_ledger_flag,
                  '0','Declaration as Not a MSME',
                  '1','Medium Enterprises',
                  '2','Small Enterprises',
                  '3','Micro Enterprises') msme_reg_type
    FROM account_master
),

/* ================= ALLOCATION (FIXED) ================= */
ALLOC AS (
    SELECT
        entity_code,
        cr_vrno,
        cr_tcode,
        cr_slno,
        acc_code,

        MAX(dr_vrdate) AS max_dr_date,

        SUM(NVL(alloc_amt,0)) AS total_alloc,

        SUM(CASE WHEN dr_vrdate < cr_vrdate THEN NVL(alloc_amt,0) END) AS adv_amt,

        COUNT(DISTINCT CASE WHEN dr_vrdate - cr_vrdate BETWEEN 0 AND 45 THEN cr_vrno END) AS count_0_45,

        SUM(CASE WHEN dr_vrdate - cr_vrdate BETWEEN 0 AND 45 THEN NVL(alloc_amt,0) END) AS dr_alloc_amt_0_45,

        COUNT(DISTINCT CASE WHEN dr_vrdate - cr_vrdate > 45 THEN cr_vrno END) AS count_45_above,

        SUM(CASE WHEN dr_vrdate - cr_vrdate > 45 THEN NVL(alloc_amt,0) END) AS dr_alloc_amt_45_above,

        LISTAGG(dr_vrno, ',') WITHIN GROUP (ORDER BY dr_vrno) AS dr_vrno,

        LISTAGG(TO_CHAR(dr_vrdate,'DD-MON-YYYY'), ',')
            WITHIN GROUP (ORDER BY dr_vrdate) AS dr_vrdate

    FROM payment_allocation_transactions
    WHERE dr_tcode IN ('B','C','M')
    GROUP BY
        entity_code,
        cr_vrno,
        cr_tcode,
        cr_slno,
        acc_code
),
/*=========================*/
ALLOC_TOP5 AS (
    SELECT *
    FROM (
        SELECT
            entity_code,
            cr_vrno,
            cr_tcode,
            cr_slno,
            acc_code,
            dr_vrno,
            dr_vrdate,
            NVL(alloc_amt,0) alloc_amt,

            ROW_NUMBER() OVER (
                PARTITION BY entity_code, cr_vrno, cr_tcode, cr_slno, acc_code
                ORDER BY dr_vrdate
            ) rn

        FROM payment_allocation_transactions
        WHERE dr_tcode IN ('B','C','M')
    )
    WHERE rn <= 5
),

/*==============================================*/

ALLOC_PIVOT AS (
    SELECT
        entity_code,
        cr_vrno,
        cr_tcode,
        cr_slno,
        acc_code,

        MAX(CASE WHEN rn=1 THEN dr_vrno END) dr_vrno1,
        MAX(CASE WHEN rn=2 THEN dr_vrno END) dr_vrno2,
        MAX(CASE WHEN rn=3 THEN dr_vrno END) dr_vrno3,
        MAX(CASE WHEN rn=4 THEN dr_vrno END) dr_vrno4,
        MAX(CASE WHEN rn=5 THEN dr_vrno END) dr_vrno5,

        MAX(CASE WHEN rn=1 THEN dr_vrdate END) dr_vrdate1,
        MAX(CASE WHEN rn=2 THEN dr_vrdate END) dr_vrdate2,
        MAX(CASE WHEN rn=3 THEN dr_vrdate END) dr_vrdate3,
        MAX(CASE WHEN rn=4 THEN dr_vrdate END) dr_vrdate4,
        MAX(CASE WHEN rn=5 THEN dr_vrdate END) dr_vrdate5,

        MAX(CASE WHEN rn=1 THEN alloc_amt END) dr_alloc_amt_1,
        MAX(CASE WHEN rn=2 THEN alloc_amt END) dr_alloc_amt_2,
        MAX(CASE WHEN rn=3 THEN alloc_amt END) dr_alloc_amt_3,
        MAX(CASE WHEN rn=4 THEN alloc_amt END) dr_alloc_amt_4,
        MAX(CASE WHEN rn=5 THEN alloc_amt END) dr_alloc_amt_5

    FROM ALLOC_TOP5
    GROUP BY
        entity_code,
        cr_vrno,
        cr_tcode,
        cr_slno,
        acc_code
),
/*==============================================*/
ALLOC_SUM AS (
    SELECT
        entity_code,
        cr_vrno,
        cr_tcode,
        cr_slno,
        acc_code,
        SUM(NVL(alloc_amt,0)) total_alloc
    FROM payment_allocation_transactions
    WHERE dr_tcode IN ('B','C','M')
    GROUP BY
        entity_code,
        cr_vrno,
        cr_tcode,
        cr_slno,
        acc_code
),
/* ================= BANK ================= */
BANK AS (
    SELECT entity_code,
           tcode,
           vrno,
           slno,
           LISTAGG(bank_ref_no, ',')
               WITHIN GROUP (ORDER BY bank_ref_no) bank_ref_no
    FROM account_transations
    GROUP BY entity_code, tcode, vrno, slno
),

/* ================= INST ================= */
INST AS (
    SELECT entity_code,
           vrno,
           LISTAGG(instype, ',')
               WITHIN GROUP (ORDER BY instype) instype
    FROM (
        SELECT DISTINCT
               a.entity_code,
               a.vrno,
               x.instype
        FROM account_transations a
        JOIN account_transations x
          ON x.bank_ref_no = a.bank_ref_no
    )
    GROUP BY entity_code, vrno
),

/* ================= ORDER DUE ================= */
ORDER_DUE AS (
    SELECT entity_code,
           acc_vrno vrno,
           vrno grn_vrno,
           vrdate grn_vrdate,
           MAX(order_duedays) order_duedays
    FROM view_purchase_engine
    GROUP BY entity_code, acc_vrno, vrno, vrdate
)

SELECT
    a.entity_code, a.div_code,
    od.grn_vrdate, od.grn_vrno,
    a.tcode,
    a.vrno,  a.vrdate,

    a.cramt,
    a.partybillno, a.partybilldate,

    a.acc_code, a.acc_name,
    a.duedate,
    a.acc_sch,
     a.ACC_SCH_NAME,
    (SELECT supplier_type_name FROM VIEW_SUPPLIER_TYPE K WHERE K.supplier_type =A.SUPPLIER_TYPE) SUPPLIER_TYPE,
    ac.panno,
    ac.sub_ledger_flag msme_reg_type_code,
    ac.msme_reg_type,
    ac.msme_regno,
    ac.msme_reg_date,
    a.cr_alloc_amt,
    al.dr_vrno,
    al.dr_vrdate,
    al.max_dr_date AS max_payment_date,
    (al.max_dr_date - a.partybilldate) diff_days,
    (al.max_dr_date - a.vrdate) acc_diff_days,
    i.instype,
    od.order_duedays,

ap.dr_vrno1,
ap.dr_vrno2,
ap.dr_vrno3,
ap.dr_vrno4,
ap.dr_vrno5,

ap.dr_vrdate1,
ap.dr_vrdate2,
ap.dr_vrdate3,
ap.dr_vrdate4,
ap.dr_vrdate5,

ap.dr_alloc_amt_1,
ap.dr_alloc_amt_2,
ap.dr_alloc_amt_3,
ap.dr_alloc_amt_4,
ap.dr_alloc_amt_5,


    /* ? USE ALLOC DIRECTLY (NO SUBQUERY) */
    NVL(al.count_0_45,0) count_0_45,
    NVL(al.dr_alloc_amt_0_45,0) dr_alloc_amt_0_45,
    NVL(al.count_45_above,0) count_45_above,
    NVL(al.dr_alloc_amt_45_above,0) dr_alloc_amt_45_above,

    LEAST(NVL(od.order_duedays, 15), 45) AS msme_allowed_days,
    (a.vrdate + LEAST(NVL(od.order_duedays, 15), 45)) AS msme_due_date,

    CASE
        WHEN SYSDATE > (a.vrdate + LEAST(NVL(od.order_duedays, 15), 45))
        THEN TRUNC(SYSDATE) - TRUNC(a.vrdate + LEAST(NVL(od.order_duedays, 15), 45))
        ELSE 0
    END AS msme_diff_days,

    al.adv_amt,

    /* AGEING */
    CASE
        WHEN TRUNC(SYSDATE) - TRUNC(a.partybilldate) BETWEEN 0 AND 45
        THEN NVL(a.due_amt,0)
        ELSE 0
    END os_0_45_days,

    CASE
        WHEN TRUNC(SYSDATE) - TRUNC(a.partybilldate) > 45
        THEN NVL(a.due_amt,0)
        ELSE 0
    END os_above_45_days,

    /* INTEREST */
    ROUND(
        ((NVL(a.due_amt,0) * NVL(ac.intrate,0)) / 100 / 365) *
        (SYSDATE - (a.partybilldate + 46))
    ) int_amt,

 (a.cramt - NVL(als.total_alloc,0)) AS unallocated_amt,

CASE
    WHEN NVL(als.total_alloc,0) = 0 THEN 'UNPAID'
    WHEN NVL(als.total_alloc,0) < a.cramt THEN 'PARTIALLY PAID'
    WHEN NVL(als.total_alloc,0) = a.cramt THEN 'FULLY PAID'
    WHEN NVL(als.total_alloc,0) > a.cramt THEN 'OVER PAID'
END AS payment_status,
a.balance


FROM view_bills_ageing a
LEFT JOIN alloc_sum als
    ON als.entity_code = a.entity_code
   AND als.cr_vrno     = a.vrno
   AND als.cr_tcode    = a.tcode
   AND als.cr_slno     = a.slno
   AND als.acc_code    = a.acc_code
LEFT JOIN acc ac
    ON ac.acc_code = a.acc_code
LEFT JOIN alloc_pivot ap
    ON ap.entity_code = a.entity_code
   AND ap.cr_vrno   = a.vrno
   AND ap.cr_tcode  = a.tcode
   AND ap.cr_slno   = a.slno
   AND ap.acc_code  = a.acc_code
LEFT JOIN alloc al
    ON al.entity_code = a.entity_code
   AND al.cr_vrno = a.vrno
   AND al.cr_tcode = a.tcode
   AND al.cr_slno = a.slno
   AND al.acc_code = a.acc_code
LEFT JOIN bank b
    ON b.entity_code = a.entity_code
   AND b.tcode = a.tcode
   AND b.vrno = a.vrno
   AND b.slno = a.slno
LEFT JOIN inst i
    ON i.entity_code = a.entity_code
   AND i.vrno = a.vrno
LEFT JOIN order_due od
    ON od.entity_code = a.entity_code
   AND od.vrno = a.vrno
WHERE a.vrno NOT LIKE 'OB%'
  AND NVL(a.sub_ledger_flag,'#') <> '#'
;
