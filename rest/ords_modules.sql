SET DEFINE OFF
BEGIN
  ORDS.DEFINE_MODULE(
    p_module_name    => 'otc_api',
    p_base_path      => 'api/otc/',
    p_items_per_page => 50,
    p_status         => 'PUBLISHED',
    p_comments       => 'OTC API module'
  );

  -- Health endpoint
  ORDS.DEFINE_TEMPLATE(
    p_module_name => 'otc_api',
    p_pattern     => 'health'
  );
  ORDS.DEFINE_HANDLER(
    p_module_name => 'otc_api',
    p_pattern     => 'health',
    p_method      => 'GET',
    p_source_type => ORDS.source_type_plsql,
    p_source      => q'[begin
                          owa_util.mime_header(''application/json'', FALSE);
                          htp.p('{"status":"ok"}');
                          owa_util.http_header_close;
                        end;]',
    p_comments    => 'Health check endpoint'
  );

  -- Orders list
  ORDS.DEFINE_TEMPLATE(
    p_module_name => 'otc_api',
    p_pattern     => 'orders'
  );
  ORDS.DEFINE_HANDLER(
    p_module_name    => 'otc_api',
    p_pattern        => 'orders',
    p_method         => 'GET',
    p_source_type    => ORDS.source_type_collection_feed,
    p_source         => q'[select id, status, created_at, updated_at from otc_orders order by id desc]',
    p_items_per_page => 50,
    p_comments       => 'List orders'
  );

  -- Approve order
  ORDS.DEFINE_TEMPLATE(
    p_module_name => 'otc_api',
    p_pattern     => 'orders/:id/approve'
  );
  ORDS.DEFINE_HANDLER(
    p_module_name => 'otc_api',
    p_pattern     => 'orders/:id/approve',
    p_method      => 'POST',
    p_source_type => ORDS.source_type_plsql,
    p_source      => q'[begin
                          otc_pkg_approve.approve(:id);
                          owa_util.mime_header(''application/json'', FALSE);
                          htp.p('{"approved":true}');
                          owa_util.http_header_close;
                        end;]',
    p_comments    => 'Approve order'
  );

  COMMIT;
END;
/
