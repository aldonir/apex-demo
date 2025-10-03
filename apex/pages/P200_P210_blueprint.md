# Blueprint de Páginas APEX — APP_ID 100
Contexto: Oracle APEX 23.x + ORDS 24.x + Oracle DB 21c XE
Pacote central: pkg_otc (submit, approve, simulate_invoice_total)
Autorização mínima: usuários com role OTC_USER

Nomenclatura padrão de componentes
- Página: P{page} — ex.: P200, P210
- Regiões: R{page}_{NOME}
- Itens de página: P{page}_{NOME}
- Botões: BTN{page}_{NOME}
- Processos (Process): PRC{page}_{NOME}
- Processos Ajax Callback: AJAX{page}_{NOME}
- Validações: VLD{page}_{NOME}
- Ações Dinâmicas: DA{page}_{NOME}
- Classes CSS opcionais: css-{page}-{componente}
- Comentários de auditoria: “AUD: ...” no atributo Comment de cada componente crítico

Autorização/ACL
- Authorization Scheme (Application-level): AUTH_OTC_USER
  - Tipo: PL/SQL Function Returning Boolean
  - Lógica: retornar TRUE para usuários que possuam a role “OTC_USER”
    - Ex.: chamada a função corporativa pkg_security.has_role('OTC_USER') ou grupo APEX equivalente
  - Aplicado em: P200 e P210 (página), regiões de DML, botões sensíveis (APPROVE/SUBMIT) e processos servidor

Observabilidade/Auditoria
- Todos os Processos servidor e Ajax devem logar com apex_debug.message (fallback implícito para dbms_output quando debug on)
  - Prefixo padrão: [OTC][P{page}][proc] msg…

Export/DevOps
- Nome de export do app: app_100_otc.sql
- Anotar change log no Comment de páginas/processos. Executar export após alterações: apex/export .sql (CI/CD)


## P200 — Orders (Lista)
Objetivo
- Listar pedidos com filtros principais e ações de visualização e aprovação
- Aprovação em massa (multi-seleção) ou unitária

Tipo de Report
- Escolha: Classic Report (justificativa)
  - Justificativa: necessidade de checkbox para seleção múltipla, controle total dos filtros por itens de página, ação de aprovação via Ajax com apex_application.g_f01. IR não possui seleção nativa sem customizações; IG seria excessivo para mera listagem.

Regiões
1) R200_FILTERS — “Filtros”
   - Posição: Corpo (Above Content)
   - Itens:
     - P200_STATUS (Select List)
       - Lov: Static: DRAFT;SUBMITTED;APPROVED;CANCELED;ALL (valor ALL para ignorar filtro)
       - Default: ALL
     - P200_CUSTOMER_ID (Select List)
       - Lov: Query para clientes ativos (id, nome)
     - P200_DATE_FROM (Date Picker)
     - P200_DATE_TO (Date Picker)
   - Botão interno: BTN200_SEARCH (Submit de página com Request=SEARCH)
   - DA: DA200_AUTO_REFRESH_ON_FILTER
     - Evento: Change em P200_STATUS, P200_CUSTOMER_ID, P200_DATE_FROM, P200_DATE_TO
     - Ação: Refresh em R200_ORDERS

2) R200_ORDERS — “Orders”
   - Tipo: Classic Report
   - Query (com bind variables):
     - Campos: order_id, order_date, customer_name, status, total_amount
     - Filtro por itens:
       - status: se :P200_STATUS != 'ALL', aplicar where status = :P200_STATUS
       - customer_id: se not null, where customer_id = :P200_CUSTOMER_ID
       - date_from/to: where order_date between :P200_DATE_FROM and :P200_DATE_TO (incluir NVL para extremos)
   - Colunas:
     - Seleção: Checkbox apex_item.checkbox2 (p_idx=>1, p_value=>order_id, p_attributes=>'class="sel-order"')
     - order_id (link VIEW para P210)
     - order_date (format mask DD/MM/YYYY)
     - customer_name
     - status (Badge tematizado)
     - total_amount (Number format L999G999D00)
   - Link VIEW (coluna order_id):
     - Target: Page 210
     - Setar itens: P210_ORDER_ID = #ORDER_ID#
     - Request: VIEW
     - Security: Checksum (Session State Protection) habilitado

Botões de Página
- BTN200_APPROVE — “Approve”
  - Posição: Region R200_ORDERS (ou Toolbar Above)
  - Icone: fa-check
  - Autorização: AUTH_OTC_USER
  - Server-side Condition: existe pelo menos 1 checkbox selecionado? (pode ser apenas no Ajax)
- BTN200_RESET — “Reset Filtros”
  - Ação: Reset Page (Clear Cache: P200)

Ações Dinâmicas
- DA200_APPROVE_CLICK
  - Evento: Click em BTN200_APPROVE
  - Ações:
    1) JavaScript Action: coletar valores dos checkboxes (classe .sel-order) e validar não vazio; exibir apex.message para vazio.
    2) APEX Server Process (Ajax Callback): AJAX200_APPROVE
       - Enviar parâmetros: f01 (ordens selecionadas), p_request='APPROVE'
       - Espera JSON com {status:"success|error", details:[...]} 
    3) Notify
       - Sucesso: “Pedidos aprovados com sucesso.”
       - Erro: mensagem vinda do JSON
    4) Refresh R200_ORDERS

Processos (Ajax Callback)
- AJAX200_APPROVE
  - Tipo: PL/SQL (Ajax Callback)
  - Autorização: AUTH_OTC_USER
  - Lógica:
    - Iterar apex_application.g_f01
    - Para cada order_id:
      - apex_debug.message('[OTC][P200][AJAX_APPROVE] order_id=%s', order_id)
      - Chamar pkg_otc.approve(p_order_id => order_id)
      - Coletar sucessos/erros por item
    - Retornar JSON agregando resultados, HTTP 200 sempre que a chamada Ajax executa; erros de autorização retornam 403
  - Mensagens amigáveis e agregadas (N aprovadas, M com erro)

Validações
- VLD200_DATE_RANGE: se ambos preenchidos, P200_DATE_FROM <= P200_DATE_TO
- VLD200_ROLE_AT_APPROVE: validação no Ajax (re-check) — negar se sem AUTH_OTC_USER

Segurança
- Authorization Scheme na página e nas regiões: AUTH_OTC_USER
- SSP Checksums nos links para P210
- CSRF: usar Request/Checksum padrão do APEX; Ajax Callback protegido por autorização e sessão

Acessibilidade/UX
- Hint nos filtros
- Badge por status (classes: a-Status-badge)
- Padrões de i18n prontos (mensagens curtas)

Comentários/Auditoria
- Comment em R200_ORDERS: “AUD: Lista pedidos; aprovações via AJAX200_APPROVE com apex_debug.”
- Comment em AJAX200_APPROVE: “AUD: Chama pkg_otc.approve; log por ordem; retorna JSON.”


## P210 — Order (Form + Linhas)
Objetivo
- Manter dados do pedido e suas linhas; submeter e aprovar com regras de negócio
- Recalcular total ao alterar linhas (simulate_invoice_total)

Regiões
1) R210_ORDER_FORM — “Order”
   - Tipo: Form (table-based ou manual)
   - Origem: tabela OTC_ORDERS (ou view editável)
   - Itens:
     - P210_ORDER_ID (Hidden, Primary Key)
     - P210_STATUS (Display Only ou Select controlado)
     - P210_CUSTOMER_ID (Select List; obrigatório)
     - P210_ORDER_DATE (Date Picker; obrigatório)
     - P210_TOTAL (Display Only; calculado)
   - Botões:
     - BTN210_SAVE — “Save” (Submit)
     - BTN210_SUBMIT — “Submit” (envio p/ aprovação) — visível quando status IN ('DRAFT')
     - BTN210_APPROVE — “Approve” — visível quando status IN ('SUBMITTED')
     - BTN210_CANCEL — “Cancel” (Navigate to P200)
   - Condições por status:
     - Em DRAFT: itens editáveis; IG com DML ON
     - Em SUBMITTED/APPROVED/CANCELED: itens read-only; IG DML OFF

2) R210_ORDER_LINES — “Order Lines”
   - Tipo: Interactive Grid (IG)
   - Fonte: OTC_ORDER_LINES (colunas: line_id PK, order_id, product_id, qty, unit_price, line_total)
   - Ações IG:
     - Insert/Update/Delete permitidos apenas se status DRAFT
     - Cálculo de line_total: client-side dinâmico ou server-side On Save
   - Validações IG:
     - qty > 0, unit_price >= 0, product_id obrigatório
     - FK order_id = P210_ORDER_ID
   - Eventos para recalcular o total:
     - On Change de colunas qty, unit_price, product_id; On Row Added/Deleted

Processos
- PRC210_FETCH_ROW — “Load Order”
  - Ponto: Before Header
  - Tipo: Automatic Row Fetch (OTC_ORDERS)
  - Key Item: P210_ORDER_ID
  - Comentário: “AUD: Carrega ordem para edição/visualização.”

- PRC210_PROCESS_ROW — “Process Order”
  - Ponto: After Submit (When BUTTON pressed in BTN210_SAVE)
  - Tipo: Automatic Row Processing (DML)
  - Proteções:
    - Autorização: AUTH_OTC_USER
    - Condição: status atual permite edição? (DRAFT)
  - Sucesso: “Registro salvo.”

- PRC210_SUBMIT — “Submit Order”
  - Ponto: After Submit (When BUTTON pressed in BTN210_SUBMIT)
  - Tipo: PL/SQL
  - Lógica:
    - apex_debug.message('[OTC][P210][SUBMIT] order_id=%s', :P210_ORDER_ID)
    - Chamar pkg_otc.submit(p_order_id => :P210_ORDER_ID)
    - Atualizar :P210_STATUS conforme retorno
  - Sucesso: “Pedido submetido.”

- PRC210_APPROVE — “Approve Order”
  - Ponto: After Submit (When BUTTON pressed in BTN210_APPROVE)
  - Tipo: PL/SQL
  - Lógica:
    - apex_debug.message('[OTC][P210][APPROVE] order_id=%s', :P210_ORDER_ID)
    - Chamar pkg_otc.approve(p_order_id => :P210_ORDER_ID)
    - Atualizar :P210_STATUS
  - Autorização: AUTH_OTC_USER
  - Sucesso: “Pedido aprovado.”

- PRC210_IG_DML — “Process Order Lines”
  - Ponto: After Submit (BTN210_SAVE)
  - Tipo: Interactive Grid Automatic Row Processing (DML)
  - Condição: status = DRAFT
  - Comentário: “AUD: DML linhas; validações server-side.”

Validações
- VLD210_REQUIRED_CUSTOMER: P210_CUSTOMER_ID obrigatório
- VLD210_REQUIRED_DATE: P210_ORDER_DATE obrigatório
- VLD210_STATUS_TRANSITIONS:
  - SUBMIT permitido apenas se status atual = DRAFT e IG não possui erros; pelo menos 1 linha
  - APPROVE permitido apenas se status atual = SUBMITTED
- VLD210_LINES_CONSISTENCY:
  - Verificar se soma de line_total > 0
  - Verificar duplicidade de product_id se regra exigir
- VLD210_EDITABILITY_GUARD:
  - Impedir DML em ORDER/LINES quando status != DRAFT

Ações Dinâmicas
- DA210_RECALC_TOTAL
  - Evento: IG R210_ORDER_LINES — Change em qty, unit_price, product_id; Row Added; Row Deleted
  - Ação: APEX Server Process (Ajax Callback) — AJAX210_SIMULATE_TOTAL
    - Parâmetros: JSON das linhas atuais (usar apex_ig API get data) ou rely no server para ler staging IG (preferível: enviar linhas impactadas)
    - Server calcula pkg_otc.simulate_invoice_total(p_order_id => :P210_ORDER_ID) e retorna total
  - Ação 2: Set Value em P210_TOTAL com retorno
  - UX: spinner leve; throttling (delay 300ms) para evitar excesso de chamadas

Processos (Ajax Callback)
- AJAX210_SIMULATE_TOTAL
  - Autorização: AUTH_OTC_USER
  - Lógica:
    - apex_debug.message('[OTC][P210][AJAX_SIM_TOTAL] order_id=%s', :P210_ORDER_ID)
    - total := pkg_otc.simulate_invoice_total(p_order_id => :P210_ORDER_ID)
    - Retornar JSON { total: nnn.nn }
  - Erros: retornar mensagem amigável

Mensagens ao Usuário
- Save: “Registro salvo.”
- Submit: “Pedido submetido para aprovação.”
- Approve: “Pedido aprovado com sucesso.”
- Erros comuns: “Não é permitido editar/aprovar neste status.”, “Inclua ao menos uma linha.”

Navegação
- BTN210_CANCEL: redireciona para P200, preservando filtros (Clear Cache: P210 apenas)
- View de linha (P200 → P210): voltar com breadcrumb ou botão Back para P200

Segurança
- Página P210: Authorization AUTH_OTC_USER
- DML apenas com status DRAFT; re-checagem em server processes
- Proteção SSP e Checksum em links
- IG: desabilitar Download de dados sensíveis se necessário

Comentários/Auditoria
- Comment em PRC210_SUBMIT/APPROVE: “AUD: chama pkg_otc.submit/approve; apex_debug com order_id.”
- Comment em AJAX210_SIMULATE_TOTAL: “AUD: simula total; origem IG change.”


## Considerações Técnicas
- Session State
  - Proteger itens chave (P210_ORDER_ID) com Session State Protection: Checksum Required - Session Level
- Performance
  - Índices por status, customer_id, order_date
  - Paginação padrão 50 linhas em P200
- Internacionalização
  - Mensagens em Text Messages com chaves OTC.P200.APPROVE.SUCCESS etc.


## Checklist de Testes Manuais

P200 — Orders
- Acesso
  - Usuário com role OTC_USER acessa P200
  - Usuário sem role é bloqueado (Authorization Scheme)
- Filtros
  - Filtrar por STATUS, CUSTOMER, DATE_FROM/TO
  - Reset limpa filtros
- Aprovação
  - Selecionar 1+ pedidos com status SUBMITTED e clicar Approve → sucesso
  - Tentar aprovar DRAFT/APPROVED → mensagem de erro coerente
  - Ver logging em apex_debug (Session debug on)
- Navegação
  - Clicar VIEW em order_id abre P210 correto, com checksum válido

P210 — Order
- Load
  - P210_ORDER_ID carrega dados; breadcrumb/back funciona
- DML
  - Em DRAFT: editar campos e linhas; salvar com sucesso
  - Em SUBMITTED: campos/IG read-only
- Submit
  - Em DRAFT com 1+ linha válida → SUBMIT muda status para SUBMITTED
  - Sem linhas → validação impede
- Approve
  - Em SUBMITTED → APPROVE muda status para APPROVED
  - Em DRAFT/APPROVED → bloqueio esperado
- Recalcular Total
  - Alterar qty/unit_price/linha → P210_TOTAL atualiza via AJAX210_SIMULATE_TOTAL
- Segurança
  - Ações bloqueadas sem role
  - Links com checksum inválido são rejeitados

Notas finais
- Exportar alterações do App: apex/export app_100_otc.sql
- Documentar no repositório: mudanças em P200/P210, nomes de componentes e regras de status
