SET DEFINE OFF
WHENEVER SQLERROR CONTINUE

BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TABLE otc_leads_emails (
      id           NUMBER        NOT NULL,
      email        VARCHAR2(320) NOT NULL,
      source       VARCHAR2(100),
      created_at   DATE          DEFAULT SYSDATE NOT NULL,
      CONSTRAINT pk_otc_leads_emails PRIMARY KEY (id),
      CONSTRAINT uq_otc_leads_emails UNIQUE (email)
    )
  ]';
EXCEPTION WHEN OTHERS THEN IF SQLCODE = -955 THEN NULL; ELSE RAISE; END IF; END;
/

BEGIN
  EXECUTE IMMEDIATE 'CREATE SEQUENCE otc_seq_leads_emails START WITH 1 INCREMENT BY 1 NOCACHE';
EXCEPTION WHEN OTHERS THEN IF SQLCODE = -955 THEN NULL; ELSE RAISE; END IF; END;
/

CREATE OR REPLACE TRIGGER otc_bi_leads_emails
BEFORE INSERT ON otc_leads_emails
FOR EACH ROW
BEGIN
  IF :NEW.id IS NULL THEN
    SELECT otc_seq_leads_emails.NEXTVAL INTO :NEW.id FROM dual;
  END IF;
  IF :NEW.created_at IS NULL THEN
    :NEW.created_at := SYSDATE;
  END IF;
END;
/

PROMPT OTC leads table ensured.