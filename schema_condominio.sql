-- ============================================================
--  Schema PostgreSQL — Sistema de Gestão de Condomínio (MVP)
-- ============================================================

-- Extensões
CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "citext";     -- e-mails case-insensitive

-- ============================================================
-- 1. USUÁRIOS (moradores)
-- ============================================================

CREATE TABLE resident (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT        NOT NULL,
    email           CITEXT      NOT NULL UNIQUE,
    cpf             CHAR(11)    NOT NULL UNIQUE,   -- documento brasileiro
    rg              VARCHAR(20),
    phone           VARCHAR(20),
    unit_address    TEXT,                          -- unidade / bloco / apto
    avatar_url      TEXT,
    password_hash   TEXT        NOT NULL,
    -- responsável legal; NULL para moradores independentes
    guardian_id     UUID        REFERENCES resident(id) ON DELETE SET NULL,
    joined_at       DATE        NOT NULL DEFAULT CURRENT_DATE,
    active          BOOLEAN     NOT NULL DEFAULT TRUE,

    CONSTRAINT chk_cpf CHECK (cpf ~ '^\d{11}$')
);

-- Carros do morador
CREATE TABLE vehicle (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    resident_id UUID        NOT NULL REFERENCES resident(id) ON DELETE CASCADE,
    plate       VARCHAR(10) NOT NULL,
    model       TEXT,
    color       TEXT
);

-- Vagas de garagem
CREATE TABLE parking_spot (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    -- NULL = vaga desocupada
    resident_id UUID        REFERENCES resident(id) ON DELETE SET NULL,
    number      VARCHAR(20) NOT NULL UNIQUE,
    type        TEXT        NOT NULL DEFAULT 'car'   -- car | motorcycle | bicycle
);

-- ============================================================
-- 2. COLABORADORES (funcionários / prestadores)
-- ============================================================

CREATE TABLE staff (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT        NOT NULL,
    email           CITEXT      UNIQUE,
    cpf             CHAR(11)    UNIQUE,
    rg              VARCHAR(20),
    phone           VARCHAR(20),
    address         TEXT,
    -- 'internal' = funcionário CLT do condomínio
    -- 'outsourced' = prestador de empresa externa
    category        TEXT        NOT NULL CHECK (category IN ('internal', 'outsourced')),
    company_name    TEXT,
    company_cnpj    CHAR(14),
    joined_at       DATE        NOT NULL DEFAULT CURRENT_DATE,
    active          BOOLEAN     NOT NULL DEFAULT TRUE
);

-- ============================================================
-- 3. FEED — tabela-pai polimórfica
-- ============================================================

-- Cada post do feed tem um registro aqui; o tipo discrimina
-- qual tabela-filha contém os detalhes.

CREATE TABLE post (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    resident_id UUID        NOT NULL REFERENCES resident(id) ON DELETE CASCADE,
    type        TEXT        NOT NULL CHECK (type IN ('ticket','suggestion','trade','poll','notice')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    visible     BOOLEAN     NOT NULL DEFAULT TRUE
);

-- ── 3a. Chamado (Ticket) ─────────────────────────────────────

CREATE TABLE ticket (
    id          UUID PRIMARY KEY REFERENCES post(id) ON DELETE CASCADE,
    title       TEXT NOT NULL,
    description TEXT,
    status      TEXT NOT NULL DEFAULT 'open'
                    CHECK (status IN ('open','in_progress','resolved','cancelled'))
);

CREATE TABLE category (
    id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE
);

-- Relacionamento N:N entre ticket e category
CREATE TABLE ticket_category (
    ticket_id   UUID NOT NULL REFERENCES ticket(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES category(id) ON DELETE CASCADE,
    PRIMARY KEY (ticket_id, category_id)
);

-- ── 3b. Sugestão ─────────────────────────────────────────────

CREATE TABLE suggestion (
    id          UUID PRIMARY KEY REFERENCES post(id) ON DELETE CASCADE,
    title       TEXT NOT NULL,
    description TEXT
);

-- ── 3c. Troca / Venda / Doação / Serviço ─────────────────────

CREATE TABLE trade (
    id          UUID PRIMARY KEY REFERENCES post(id) ON DELETE CASCADE,
    title       TEXT NOT NULL,
    description TEXT,
    -- tipo da oferta: sale | trade | service | donation
    trade_type  TEXT NOT NULL CHECK (trade_type IN ('sale','trade','service','donation')),
    -- o que está sendo ofertado: produto ou serviço
    item_type   TEXT NOT NULL CHECK (item_type IN ('product','service'))
);

-- ── 3d. Votação (Poll) ───────────────────────────────────────

CREATE TABLE poll (
    id          UUID    PRIMARY KEY REFERENCES post(id) ON DELETE CASCADE,
    title       TEXT    NOT NULL,
    description TEXT,
    closed      BOOLEAN NOT NULL DEFAULT FALSE,
    -- se preenchido, um job pode encerrar automaticamente após o prazo
    closes_at   TIMESTAMPTZ
);

CREATE TABLE poll_option (
    id          UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id     UUID    NOT NULL REFERENCES poll(id) ON DELETE CASCADE,
    text        TEXT    NOT NULL,
    -- contador desnormalizado; atualizado via trigger
    vote_count  INTEGER NOT NULL DEFAULT 0
);

-- Votos individuais (garante 1 voto por morador por enquete)
CREATE TABLE poll_vote (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    option_id   UUID        NOT NULL REFERENCES poll_option(id) ON DELETE CASCADE,
    resident_id UUID        NOT NULL REFERENCES resident(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (resident_id, option_id)   -- 1 voto por opção
    -- unicidade por enquete reforçada via trigger fn_check_single_vote
);

-- ── 3e. Aviso (Notice) ───────────────────────────────────────

CREATE TABLE notice (
    id          UUID PRIMARY KEY REFERENCES post(id) ON DELETE CASCADE,
    title       TEXT NOT NULL,
    description TEXT,
    importance  TEXT NOT NULL DEFAULT 'medium'
                    CHECK (importance IN ('high','medium','low'))
);

-- ── 3f. Interações comuns: Comentário e Curtida ──────────────

CREATE TABLE comment (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id     UUID        NOT NULL REFERENCES post(id) ON DELETE CASCADE,
    resident_id UUID        NOT NULL REFERENCES resident(id) ON DELETE CASCADE,
    content     TEXT        NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE like_ (
    -- "like" é palavra reservada em SQL; sufixo _ evita conflito
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id     UUID        NOT NULL REFERENCES post(id) ON DELETE CASCADE,
    resident_id UUID        NOT NULL REFERENCES resident(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (post_id, resident_id)    -- 1 curtida por morador por post
);

-- ============================================================
-- 4. TIMELINE DE SERVIÇO
-- ============================================================

CREATE TABLE service_timeline (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    -- ticket_id é opcional: timeline pode existir sem chamado de origem
    ticket_id   UUID        REFERENCES ticket(id) ON DELETE SET NULL,
    title       TEXT        NOT NULL,
    description TEXT,
    created_by  UUID        NOT NULL REFERENCES resident(id),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    public      BOOLEAN     NOT NULL DEFAULT TRUE
);

CREATE TABLE timeline_step (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    timeline_id UUID        NOT NULL REFERENCES service_timeline(id) ON DELETE CASCADE,
    title       TEXT        NOT NULL,
    description TEXT,
    order_index SMALLINT    NOT NULL,
    status      TEXT        NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','in_progress','done')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (timeline_id, order_index)
);

-- Colaboradores atribuídos a cada etapa
CREATE TABLE step_staff (
    step_id     UUID NOT NULL REFERENCES timeline_step(id) ON DELETE CASCADE,
    staff_id    UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
    PRIMARY KEY (step_id, staff_id)
);

-- Fotos e documentos anexados a cada etapa
CREATE TABLE step_attachment (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    step_id     UUID        NOT NULL REFERENCES timeline_step(id) ON DELETE CASCADE,
    url         TEXT        NOT NULL,
    type        TEXT        NOT NULL DEFAULT 'image' CHECK (type IN ('image','document')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 5. RESERVA DE ESPAÇOS
-- ============================================================

CREATE TABLE amenity (
    -- espaço coletivo do condomínio (piscina, salão, etc.)
    id              UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT    NOT NULL UNIQUE,
    max_capacity    INTEGER NOT NULL CHECK (max_capacity > 0),
    description     TEXT,
    active          BOOLEAN NOT NULL DEFAULT TRUE
);

-- Horário padrão de funcionamento (day_of_week: 0=dom … 6=sáb)
CREATE TABLE amenity_schedule (
    id           UUID     PRIMARY KEY DEFAULT gen_random_uuid(),
    amenity_id   UUID     NOT NULL REFERENCES amenity(id) ON DELETE CASCADE,
    day_of_week  SMALLINT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
    opens_at     TIME,
    closes_at    TIME,
    closed       BOOLEAN  NOT NULL DEFAULT FALSE,

    UNIQUE (amenity_id, day_of_week)
);

-- Exceções de horário em datas específicas (feriados, manutenção, etc.)
CREATE TABLE amenity_exception (
    id          UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
    amenity_id  UUID    NOT NULL REFERENCES amenity(id) ON DELETE CASCADE,
    date        DATE    NOT NULL,
    opens_at    TIME,
    closes_at   TIME,
    closed      BOOLEAN NOT NULL DEFAULT FALSE,
    reason      TEXT,

    UNIQUE (amenity_id, date)
);

-- Reservas feitas pelos moradores
CREATE TABLE booking (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    amenity_id      UUID        NOT NULL REFERENCES amenity(id),
    resident_id     UUID        NOT NULL REFERENCES resident(id),
    date            DATE        NOT NULL,
    start_time      TIME        NOT NULL,
    end_time        TIME        NOT NULL,
    guest_count     INTEGER     CHECK (guest_count > 0),
    status          TEXT        NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending','confirmed','cancelled')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_booking_times CHECK (end_time > start_time)
);

-- ============================================================
-- 6. PORTARIA — Visitantes e Entregas
-- ============================================================

-- Visitantes esperados ou já chegados ao condomínio.
-- O morador pode pré-autorizar um visitante pelo app; o porteiro
-- vê a lista de "pending" em seu painel e registra entrada/saída.

CREATE TABLE visitor (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    -- morador que autorizou a visita
    resident_id     UUID        NOT NULL REFERENCES resident(id) ON DELETE CASCADE,
    name            TEXT        NOT NULL,
    document        TEXT,                       -- RG, CPF ou passaporte
    photo_url       TEXT,
    -- data/hora esperada de chegada (pré-autorização pelo morador)
    expected_at     TIMESTAMPTZ,
    -- registrado pelo porteiro no momento real de chegada/saída
    arrived_at      TIMESTAMPTZ,
    left_at         TIMESTAMPTZ,
    -- pending   = autorizado, aguardando chegada
    -- arrived   = está no condomínio agora
    -- left      = já saiu
    -- cancelled = autorização cancelada pelo morador
    status          TEXT        NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending','arrived','left','cancelled')),
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices úteis para o painel do porteiro (visitantes pendentes/presentes)
CREATE INDEX idx_visitor_resident ON visitor(resident_id);
CREATE INDEX idx_visitor_pending  ON visitor(status, expected_at)
    WHERE status IN ('pending','arrived');

-- Entregas recebidas na portaria.
-- O porteiro registra o pacote; o morador recebe notificação automática
-- (via trigger) e confirma a retirada pelo app.

CREATE TABLE delivery (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    -- destinatário
    resident_id     UUID        NOT NULL REFERENCES resident(id) ON DELETE CASCADE,
    sender          TEXT,                       -- remetente / transportadora
    description     TEXT,                       -- descrição livre (ex: "caixa Shopee")
    tracking_code   TEXT,
    photo_url       TEXT,                       -- foto do pacote tirada pelo porteiro
    received_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    picked_up_at    TIMESTAMPTZ,
    -- pending    = aguardando retirada
    -- picked_up  = retirado pelo morador
    status          TEXT        NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending','picked_up')),
    notes           TEXT
);

CREATE INDEX idx_delivery_resident ON delivery(resident_id);
CREATE INDEX idx_delivery_pending  ON delivery(status, received_at)
    WHERE status = 'pending';

-- ============================================================
-- 7. NOTIFICAÇÕES
-- ============================================================

-- Tabela central de notificações dos moradores.
-- Cada linha representa um evento que aparece no inbox/sino do app.
-- Populada via triggers (entregas, visitantes) e lógica da aplicação.

CREATE TABLE notification (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    -- destinatário da notificação
    resident_id     UUID        NOT NULL REFERENCES resident(id) ON DELETE CASCADE,
    -- tipo do evento — usado pelo front para escolher ícone e rota
    type            TEXT        NOT NULL CHECK (type IN (
                        'comment',          -- alguém comentou no seu post
                        'like',             -- alguém curtiu seu post
                        'ticket_update',    -- status do seu chamado mudou
                        'timeline_update',  -- etapa de timeline atualizada
                        'poll_closed',      -- votação que você participou encerrou
                        'booking_update',   -- sua reserva foi confirmada/cancelada
                        'visitor_arrived',  -- seu visitante chegou
                        'delivery',         -- nova encomenda na portaria
                        'notice',           -- novo aviso do administrador
                        'general'           -- uso livre / administrativo
                    )),
    title           TEXT        NOT NULL,
    body            TEXT,
    -- referência polimórfica: id do objeto relacionado
    reference_id    UUID,
    -- nome da tabela referenciada — permite o front montar a rota de navegação
    reference_table TEXT,
    read            BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notification_resident ON notification(resident_id);
-- índice parcial para busca rápida de não-lidas (painel do sino)
CREATE INDEX idx_notification_unread   ON notification(resident_id, created_at DESC)
    WHERE read = FALSE;

-- ============================================================
-- 8. TRIGGERS
-- ============================================================

-- 8a. Garantir 1 voto por morador por enquete (não apenas por opção)
CREATE OR REPLACE FUNCTION fn_check_single_vote()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM poll_vote pv
        JOIN poll_option po ON po.id = pv.option_id
        WHERE po.poll_id = (SELECT poll_id FROM poll_option WHERE id = NEW.option_id)
          AND pv.resident_id = NEW.resident_id
    ) THEN
        RAISE EXCEPTION 'Resident has already voted in this poll.';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_single_vote
BEFORE INSERT ON poll_vote
FOR EACH ROW EXECUTE FUNCTION fn_check_single_vote();

-- 8b. Manter contador de votos sincronizado na poll_option
CREATE OR REPLACE FUNCTION fn_update_vote_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE poll_option SET vote_count = vote_count + 1 WHERE id = NEW.option_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE poll_option SET vote_count = GREATEST(vote_count - 1, 0) WHERE id = OLD.option_id;
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_vote_count
AFTER INSERT OR DELETE ON poll_vote
FOR EACH ROW EXECUTE FUNCTION fn_update_vote_count();

-- 8c. Notificar morador automaticamente quando uma nova entrega for registrada
CREATE OR REPLACE FUNCTION fn_notify_delivery()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO notification (resident_id, type, title, body, reference_id, reference_table)
    VALUES (
        NEW.resident_id,
        'delivery',
        'New package at the gatehouse',
        COALESCE('From: ' || NEW.sender, 'A package is waiting for you at the gatehouse.'),
        NEW.id,
        'delivery'
    );
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_delivery
AFTER INSERT ON delivery
FOR EACH ROW EXECUTE FUNCTION fn_notify_delivery();

-- 8d. Notificar morador quando seu visitante tiver a chegada registrada
CREATE OR REPLACE FUNCTION fn_notify_visitor_arrived()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status = 'arrived' AND OLD.status <> 'arrived' THEN
        INSERT INTO notification (resident_id, type, title, body, reference_id, reference_table)
        VALUES (
            NEW.resident_id,
            'visitor_arrived',
            'Your visitor has arrived',
            NEW.name || ' is at the gatehouse.',
            NEW.id,
            'visitor'
        );
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_visitor_arrived
AFTER UPDATE ON visitor
FOR EACH ROW EXECUTE FUNCTION fn_notify_visitor_arrived();

-- ============================================================
-- 9. ÍNDICES
-- ============================================================

-- Feed / interações
CREATE INDEX idx_post_resident      ON post(resident_id);
CREATE INDEX idx_post_type_date     ON post(type, created_at DESC);
CREATE INDEX idx_comment_post       ON comment(post_id);
CREATE INDEX idx_like_post          ON like_(post_id);

-- Reservas
CREATE INDEX idx_booking_amenity_date ON booking(amenity_id, date);
CREATE INDEX idx_booking_resident     ON booking(resident_id);

-- Timeline
CREATE INDEX idx_step_timeline ON timeline_step(timeline_id, order_index);

-- ============================================================
-- 10. DADOS INICIAIS (seed)
-- ============================================================

INSERT INTO category (id, name) VALUES
    (gen_random_uuid(), 'Maintenance'),
    (gen_random_uuid(), 'Security'),
    (gen_random_uuid(), 'Cleaning'),
    (gen_random_uuid(), 'Infrastructure'),
    (gen_random_uuid(), 'Financial'),
    (gen_random_uuid(), 'Other');

INSERT INTO amenity (id, name, max_capacity, description) VALUES
    (gen_random_uuid(), 'Swimming Pool',  50, 'Adult and children pool'),
    (gen_random_uuid(), 'Party Hall',     80, 'Main hall with kitchen'),
    (gen_random_uuid(), 'BBQ Area',       30, 'Covered barbecue grills'),
    (gen_random_uuid(), 'Gym',            20, 'Weight and cardio equipment'),
    (gen_random_uuid(), 'Sports Court',   40, 'Football, volleyball and basketball');

-- ============================================================
-- SUGESTÕES PARA VERSÕES FUTURAS
-- ============================================================
--
--  1. DOCUMENTOS DO CONDOMÍNIO
--     Atas de assembleias, regulamento interno, etc.
--     CREATE TABLE document (
--         id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
--         title       TEXT NOT NULL,
--         url         TEXT NOT NULL,
--         category    TEXT,
--         created_by  UUID REFERENCES resident(id),
--         created_at  TIMESTAMPTZ DEFAULT NOW(),
--         public      BOOLEAN DEFAULT TRUE
--     );
--
--  2. VOTAÇÃO COM ENCERRAMENTO AUTOMÁTICO
--     A coluna closes_at já existe em poll.
--     Basta criar um job (pg_cron, BullMQ, etc.) que sete
--     closed = TRUE quando NOW() >= closes_at.
--
--  3. FINANCEIRO
--     Controle de taxas condominiais, inadimplência, fundo de reserva.
--     CREATE TABLE charge (
--         id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
--         resident_id  UUID NOT NULL REFERENCES resident(id),
--         reference    DATE NOT NULL,          -- competência (mês/ano)
--         amount       NUMERIC(10,2) NOT NULL,
--         due_date     DATE NOT NULL,
--         paid_at      DATE,
--         status       TEXT DEFAULT 'pending'  -- pending | paid | overdue
--     );
--
--  4. SOFT DELETE UNIVERSAL
--     Adicionar deleted_at TIMESTAMPTZ nas tabelas principais
--     e usar Views/RLS para filtrar registros ativos.
--
--  5. ROW-LEVEL SECURITY (RLS)
--     Habilitar RLS no PostgreSQL para que moradores só acessem
--     seus próprios dados sensíveis (cpf, rg, password_hash, etc.).
--
--  6. AUDITORIA
--     CREATE TABLE audit_log (
--         id           BIGSERIAL PRIMARY KEY,
--         table_name   TEXT,
--         operation    TEXT,       -- INSERT | UPDATE | DELETE
--         resident_id  UUID,
--         old_data     JSONB,
--         new_data     JSONB,
--         occurred_at  TIMESTAMPTZ DEFAULT NOW()
--     );
--
--  7. ENQUETES ANÔNIMAS
--     Adicionar coluna anonymous BOOLEAN em poll;
--     quando TRUE, omitir resident_id em poll_vote
--     e bloquear consulta individual via RLS/View.
--
--  8. PUSH NOTIFICATIONS
--     Tabela para armazenar tokens FCM/APNs por dispositivo.
--     Disparar push ao inserir em notification via worker/webhook.
--     CREATE TABLE push_token (
--         id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
--         resident_id  UUID NOT NULL REFERENCES resident(id) ON DELETE CASCADE,
--         token        TEXT NOT NULL UNIQUE,
--         platform     TEXT CHECK (platform IN ('ios','android','web')),
--         created_at   TIMESTAMPTZ DEFAULT NOW()
--     );
