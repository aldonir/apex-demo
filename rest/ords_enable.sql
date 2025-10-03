SET DEFINE OFF
BEGIN
  ORDS.enable_schema(
    p_enabled             => TRUE,
    p_schema              => 'OTC_APP',
    p_url_mapping_pattern => 'otc',
    p_auto_rest_auth      => FALSE
  );
END;
/
PROMPT ORDS schema enabled for OTC_APP.