SET DEFINE OFF
WHENEVER SQLERROR CONTINUE
PROMPT Ensure OTC core table otc_orders and seed data

-- Create table otc_orders if not exists
declare v_exists number; begin
  select count(*) into v_exists from user_tables where table_name = 'OTC_ORDERS';
  if v_exists = 0 then
    execute immediate q'[
      create table otc_orders (
        id           number generated always as identity primary key,
        customer_id  number,
        order_date   date   default trunc(sysdate) not null,
        status       varchar2(20) default 'NEW' not null,
        total_amount number(14,2),
        created_at   timestamp(6) default systimestamp not null,
        updated_at   timestamp(6)
      )
    ]';
  end if;
end;
/

-- Update trigger to maintain updated_at
create or replace trigger trg_otc_orders_bu
before update on otc_orders
for each row
begin
  :new.updated_at := systimestamp;
end;
/

-- Seed minimal data for smoke tests (idempotent)
declare v_cnt number; begin
  select count(*) into v_cnt from otc_orders;
  if v_cnt = 0 then
    insert into otc_orders(customer_id, status, total_amount)
    values (1001, 'NEW', 10.00);
  end if;
end;
/

commit;
PROMPT otc_orders ensured.