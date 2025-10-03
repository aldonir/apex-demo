SET DEFINE OFF
BEGIN
  ords.define_template(
    p_module_name => 'otc_api',
    p_pattern     => 'site/lead'
  );
  ords.define_handler(
    p_module_name => 'otc_api',
    p_pattern     => 'site/lead',
    p_method      => 'POST',
    p_source_type => ORDS.source_type_plsql,
    p_source      => q'[declare
                          v_email   varchar2(320) := :email;
                          v_source  varchar2(100) := nvl(:source, 'web');
                        begin
                          insert into otc_leads_emails(id, email, source, created_at)
                          values (otc_seq_leads_emails.nextval, v_email, v_source, sysdate);
                          owa_util.mime_header('application/json', FALSE);
                          htp.p('{"ok":true}');
                          owa_util.http_header_close;
                        exception when dup_val_on_index then
                          owa_util.mime_header('application/json', FALSE);
                          htp.p('{"ok":true,"dup":true}');
                          owa_util.http_header_close;
                        end;]',
    p_comments    => 'Capture lead email'
  );

  COMMIT;
END;
/