SET DEFINE OFF
WHENEVER SQLERROR CONTINUE

CREATE OR REPLACE PACKAGE otc_pkg_approve AS
  PROCEDURE approve(p_order_id IN NUMBER);
END otc_pkg_approve;
/

CREATE OR REPLACE PACKAGE BODY otc_pkg_approve AS
  PROCEDURE approve(p_order_id IN NUMBER) IS
  BEGIN
    UPDATE otc_orders
       SET status = 'APPROVED',
           updated_at = SYSDATE
     WHERE id = p_order_id;
    COMMIT;
  END approve;
END otc_pkg_approve;
/

PROMPT OTC approval package ensured.