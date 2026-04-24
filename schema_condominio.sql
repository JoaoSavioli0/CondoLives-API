-- ============================================================
--  Schema PostgreSQL — Sistema de Gestão de Condomínio (MVP)
--  + Row-Level Security por condomínio
-- ============================================================

-- Extensões
CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "citext";     -- e-mails case-insensitive

-- ============================================================
-- 0. CONDOMÍNIO — tabela-âncora para RLS
-- ============================================================

-- Cada instância/tenant do sistema é um condomínio.
-- O id do condomínio ativo é armazenado em uma variável de
-- configuração de sessão (app.current_condominium_id) que deve
-- ser definida pela aplicação logo após abrir a conexão:
--
--   SET app.current_condominium_id = '<uuid-do-condominio>';
--
-- Todos os objetos abaixo filtram automaticamente por esse valor.

CREATE TABLE condominium (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT        NOT NULL,
    cnpj        CHAR(14)    UNIQUE,
    address     TEXT,
    active      BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Função auxiliar reutilizada por todas as políticas RLS
-- Retorna o UUID da sessão corrente com cast seguro.
CREATE OR REPLACE FUNCTION current_condominium_id()
RETURNS UUID LANGUAGE sql STABLE AS $$
    SELECT current_setting('app.current_condominium_id', true)::UUID
$$;

-- ============================================================
-- 1. USUÁRIOS (moradores)
-- ============================================================

CREATE TABLE resident (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    -- ► coluna de tenant
    condominium_id  UUID        NOT NULL REFERENCES condominium(id) ON DELETE CASCADE,
    name            TEXT        NOT NULL,
    email           CITEXT      NOT NULL,
    cpf             CHAR(11)    NOT NULL,
    rg              VARCHAR(20),
    phone           VARCHAR(20),
    unit_address    TEXT,
    avatar_url      TEXT,
    password_hash   TEXT        NOT NULL,
    guardian_id     UUID        REFERENCES resident(id) ON DELETE SET NULL,
    joined_at       DATE        NOT NULL DEFAULT CURRENT_DATE,
    active          BOOLEAN     NOT NULL DEFAULT TRUE,

    -- e-mail e CPF únicos dentro do condomínio
    UNIQUE (condominium_id, email),
    UNIQUE (condominium_id, cpf),
    CONSTRAINT chk_cpf CHECK (cpf ~ '^\d{11}$')
);

ALTER TABLE resident ENABLE ROW LEVEL SECURITY;

CREATE POLICY resident_isolation ON resident
    USING (condominium_id = current_condominium_id());

-- Carros do morador
CREATE TABLE vehicle (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    condominium_id  UUID        NOT NULL REFERENCES condominium(id) ON DELETE CASCADE,
    resident_id     UUID        NOT NULL REFERENCES resident(id) ON DELETE CASCADE,
    plate           VARCHAR(10) NOT NULL,
    model           TEXT,
    color           TEXT
);

ALTER TABLE vehicle ENABLE ROW LEVEL SECURITY;

CREATE POLICY vehicle_isolation ON vehicle
    USING (condominium_id = current_condominium_id());

-- Vagas de garagem
CREATE TABLE parking_spot (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    condominium_id  UUID        NOT NULL REFERENCES condominium(id) ON DELETE CASCADE,
    resident_id     UUID        REFERENCES resident(id) ON DELETE SET NULL,
    number          VARCHAR(20) NOT NULL,
    type            TEXT        NOT NULL DEFAULT 'car',

    -- número da vaga único por condomínio
    UNIQUE (condominium_id, number)
);

ALTER TABLE parking_spot ENABLE ROW LEVEL SECURITY;

CREATE POLICY parking_spot_isolation ON parking_spot
    USING (condominium_id = current_condominium_id());

-- ============================================================
-- 2. COLABORADORES (funcionários / prestadores)
-- ============================================================

CREATE TABLE staff (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    condominium_id  UUID        NOT NULL REFERENCES condominium(id) ON DELETE CASCADE,
    name            TEXT        NOT NULL,
    email           CITEXT,
    cpf             CHAR(11),
    rg              VARCHAR(20),
    phone           VARCHAR(20),
    address         TEXT,
    category        TEXT        NOT NULL CHECK (category IN ('internal', 'outsourced')),
    company_name    TEXT,
    company_cnpj    CHAR(14),
    joined_at       DATE        NOT NULL DEFAULT CURRENT_DATE,
    active          BOOLEAN     NOT NULL DEFAULT TRUE,

    UNIQUE (condominium_id, email),
    UNIQUE (condominium_id, cpf)
);

ALTER TABLE staff ENABLE ROW LEVEL SECURITY;

CREATE POLICY staff_isolation ON staff
    USING (condominium_id = current_condominium_id());

-- ============================================================
-- 3. FEED — tabela-pai polimórfica
-- ============================================================

-- post é a raiz do feed; todas as tabelas-filha herdam o
-- isolamento por condomínio por meio do JOIN com post.

CREATE TABLE post (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    condominium_id  UUID        NOT NULL REFERENCES condominium(id) ON DELETE CASCADE,
    resident_id     UUID        NOT NULL REFERENCES resident(id) ON DELETE CASCADE,
    type            TEXT        NOT NULL CHECK (type IN ('ticket','suggestion','trade','poll','notice')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    visible         BOOLEAN     NOT NULL DEFAULT TRUE
);

ALTER TABLE post ENABLE ROW LEVEL SECURITY;

CREATE POLICY post_isolation ON post
    USING (condominium_id = current_condominium_id());

-- ── 3a. Chamado (Ticket) ─────────────────────────────────────
-- Herda o tenant de post; sem coluna extra necessária.

CREATE TABLE ticket (
    id          UUID PRIMARY KEY REFERENCES post(id) ON DELETE CASCADE,
    title       TEXT NOT NULL,
    description TEXT,
    location    TEXT,
    status      TEXT NOT NULL DEFAULT 'open'
                    CHECK (status IN ('open','in_progress','resolved','cancelled'))
);

ALTER TABLE ticket ENABLE ROW LEVEL SECURITY;

-- Política via JOIN com post (que já tem o filtro de condomínio)
CREATE POLICY ticket_isolation ON ticket
    USING (EXISTS (
        SELECT 1 FROM post
        WHERE post.id = ticket.id
          AND post.condominium_id = current_condominium_id()
    ));

CREATE TABLE category (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    condominium_id  UUID        NOT NULL REFERENCES condominium(id) ON DELETE CASCADE,
    name            TEXT        NOT NULL,

    UNIQUE (condominium_id, name)
);

ALTER TABLE category ENABLE ROW LEVEL SECURITY;

CREATE POLICY category_isolation ON category
    USING (condominium_id = current_condominium_id());

-- Relacionamento N:N entre ticket e category
-- Herda isolamento por meio dos joins com ticket e category
CREATE TABLE ticket_category (
    ticket_id   UUID NOT NULL REFERENCES ticket(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES category(id) ON DELETE CASCADE,
    PRIMARY KEY (ticket_id, category_id)
);

ALTER TABLE ticket_category ENABLE ROW LEVEL SECURITY;

CREATE POLICY ticket_category_isolation ON ticket_category
    USING (EXISTS (
        SELECT 1 FROM category
        WHERE category.id = ticket_category.category_id
          AND category.condominium_id = current_condominium_id()
    ));

-- ── 3b. Sugestão ─────────────────────────────────────────────

CREATE TABLE suggestion (
    id          UUID PRIMARY KEY REFERENCES post(id) ON DELETE CASCADE,
    title       TEXT NOT NULL,
    description TEXT
);

ALTER TABLE suggestion ENABLE ROW LEVEL SECURITY;

CREATE POLICY suggestion_isolation ON suggestion
    USING (EXISTS (
        SELECT 1 FROM post
        WHERE post.id = suggestion.id
          AND post.condominium_id = current_condominium_id()
    ));

-- ── 3c. Troca / Venda / Doação / Serviço ─────────────────────

CREATE TABLE trade (
    id          UUID PRIMARY KEY REFERENCES post(id) ON DELETE CASCADE,
    title       TEXT NOT NULL,
    description TEXT,
    trade_type  TEXT NOT NULL CHECK (trade_type IN ('sale','trade','service','donation')),
    item_type   TEXT NOT NULL CHECK (item_type IN ('product','service')),
    status      TEXT NOT NULL DEFAULT 'open'
                    CHECK (status IN ('open','in_progress','resolved','cancelled'))
);

ALTER TABLE trade ENABLE ROW LEVEL SECURITY;

CREATE POLICY trade_isolation ON trade
    USING (EXISTS (
        SELECT 1 FROM post
        WHERE post.id = trade.id
          AND post.condominium_id = current_condominium_id()
    ));

-- ── 3d. Votação (Poll) ───────────────────────────────────────

CREATE TABLE poll (
    id          UUID    PRIMARY KEY REFERENCES post(id) ON DELETE CASCADE,
    title       TEXT    NOT NULL,
    description TEXT,
    closed      BOOLEAN NOT NULL DEFAULT FALSE,
    closes_at   TIMESTAMPTZ
);

ALTER TABLE poll ENABLE ROW LEVEL SECURITY;

CREATE POLICY poll_isolation ON poll
    USING (EXISTS (
        SELECT 1 FROM post
        WHERE post.id = poll.id
          AND post.condominium_id = current_condominium_id()
    ));

CREATE TABLE poll_option (
    id          UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id     UUID    NOT NULL REFERENCES poll(id) ON DELETE CASCADE,
    text        TEXT    NOT NULL,
    vote_count  INTEGER NOT NULL DEFAULT 0
);

ALTER TABLE poll_option ENABLE ROW LEVEL SECURITY;

CREATE POLICY poll_option_isolation ON poll_option
    USING (EXISTS (
        SELECT 1 FROM post
        WHERE post.id = poll_option.poll_id
          AND post.condominium_id = current_condominium_id()
    ));

CREATE TABLE poll_vote (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    option_id   UUID        NOT NULL REFERENCES poll_option(id) ON DELETE CASCADE,
    resident_id UUID        NOT NULL REFERENCES resident(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (resident_id, option_id)
);

ALTER TABLE poll_vote ENABLE ROW LEVEL SECURITY;

CREATE POLICY poll_vote_isolation ON poll_vote
    USING (EXISTS (
        SELECT 1 FROM resident
        WHERE resident.id = poll_vote.resident_id
          AND resident.condominium_id = current_condominium_id()
    ));

-- ── 3e. Aviso (Notice) ───────────────────────────────────────

CREATE TABLE notice (
    id          UUID PRIMARY KEY REFERENCES post(id) ON DELETE CASCADE,
    title       TEXT NOT NULL,
    description TEXT,
    importance  TEXT NOT NULL DEFAULT 'medium'
                    CHECK (importance IN ('high','medium','low'))
);

ALTER TABLE notice ENABLE ROW LEVEL SECURITY;

CREATE POLICY notice_isolation ON notice
    USING (EXISTS (
        SELECT 1 FROM post
        WHERE post.id = notice.id
          AND post.condominium_id = current_condominium_id()
    ));

-- ── 3f. Interações comuns: Comentário e Curtida ──────────────

CREATE TABLE comment (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id     UUID        NOT NULL REFERENCES post(id) ON DELETE CASCADE,
    resident_id UUID        NOT NULL REFERENCES resident(id) ON DELETE CASCADE,
    content     TEXT        NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE comment ENABLE ROW LEVEL SECURITY;

CREATE POLICY comment_isolation ON comment
    USING (EXISTS (
        SELECT 1 FROM post
        WHERE post.id = comment.post_id
          AND post.condominium_id = current_condominium_id()
    ));

CREATE TABLE like_ (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id     UUID        NOT NULL REFERENCES post(id) ON DELETE CASCADE,
    resident_id UUID        NOT NULL REFERENCES resident(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (post_id, resident_id)
);

ALTER TABLE like_ ENABLE ROW LEVEL SECURITY;

CREATE POLICY like_isolation ON like_
    USING (EXISTS (
        SELECT 1 FROM post
        WHERE post.id = like_.post_id
          AND post.condominium_id = current_condominium_id()
    ));

-- ============================================================
-- 4. TIMELINE DE SERVIÇO
-- ============================================================

CREATE TABLE service_timeline (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    condominium_id  UUID        NOT NULL REFERENCES condominium(id) ON DELETE CASCADE,
    ticket_id       UUID        REFERENCES ticket(id) ON DELETE SET NULL,
    title           TEXT        NOT NULL,
    description     TEXT,
    created_by      UUID        NOT NULL REFERENCES resident(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    public          BOOLEAN     NOT NULL DEFAULT TRUE
);

ALTER TABLE service_timeline ENABLE ROW LEVEL SECURITY;

CREATE POLICY service_timeline_isolation ON service_timeline
    USING (condominium_id = current_condominium_id());

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

ALTER TABLE timeline_step ENABLE ROW LEVEL SECURITY;

CREATE POLICY timeline_step_isolation ON timeline_step
    USING (EXISTS (
        SELECT 1 FROM service_timeline
        WHERE service_timeline.id = timeline_step.timeline_id
          AND service_timeline.condominium_id = current_condominium_id()
    ));

-- Colaboradores atribuídos a cada etapa
CREATE TABLE step_staff (
    step_id     UUID NOT NULL REFERENCES timeline_step(id) ON DELETE CASCADE,
    staff_id    UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
    PRIMARY KEY (step_id, staff_id)
);

ALTER TABLE step_staff ENABLE ROW LEVEL SECURITY;

CREATE POLICY step_staff_isolation ON step_staff
    USING (EXISTS (
        SELECT 1 FROM staff
        WHERE staff.id = step_staff.staff_id
          AND staff.condominium_id = current_condominium_id()
    ));

-- Fotos e documentos anexados a cada etapa
CREATE TABLE step_attachment (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    step_id     UUID        NOT NULL REFERENCES timeline_step(id) ON DELETE CASCADE,
    url         TEXT        NOT NULL,
    type        TEXT        NOT NULL DEFAULT 'image' CHECK (type IN ('image','document')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE step_attachment ENABLE ROW LEVEL SECURITY;

CREATE POLICY step_attachment_isolation ON step_attachment
    USING (EXISTS (
        SELECT 1 FROM service_timeline st
        JOIN timeline_step ts ON ts.timeline_id = st.id
        WHERE ts.id = step_attachment.step_id
          AND st.condominium_id = current_condominium_id()
    ));

-- ============================================================
-- 5. RESERVA DE ESPAÇOS
-- ============================================================

CREATE TABLE amenity (
    id              UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
    condominium_id  UUID    NOT NULL REFERENCES condominium(id) ON DELETE CASCADE,
    name            TEXT    NOT NULL,
    max_capacity    INTEGER NOT NULL CHECK (max_capacity > 0),
    description     TEXT,
    active          BOOLEAN NOT NULL DEFAULT TRUE,

    UNIQUE (condominium_id, name)
);

ALTER TABLE amenity ENABLE ROW LEVEL SECURITY;

CREATE POLICY amenity_isolation ON amenity
    USING (condominium_id = current_condominium_id());

CREATE TABLE amenity_schedule (
    id           UUID     PRIMARY KEY DEFAULT gen_random_uuid(),
    amenity_id   UUID     NOT NULL REFERENCES amenity(id) ON DELETE CASCADE,
    day_of_week  SMALLINT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
    opens_at     TIME,
    closes_at    TIME,
    closed       BOOLEAN  NOT NULL DEFAULT FALSE,

    UNIQUE (amenity_id, day_of_week)
);

ALTER TABLE amenity_schedule ENABLE ROW LEVEL SECURITY;

CREATE POLICY amenity_schedule_isolation ON amenity_schedule
    USING (EXISTS (
        SELECT 1 FROM amenity
        WHERE amenity.id = amenity_schedule.amenity_id
          AND amenity.condominium_id = current_condominium_id()
    ));

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

ALTER TABLE amenity_exception ENABLE ROW LEVEL SECURITY;

CREATE POLICY amenity_exception_isolation ON amenity_exception
    USING (EXISTS (
        SELECT 1 FROM amenity
        WHERE amenity.id = amenity_exception.amenity_id
          AND amenity.condominium_id = current_condominium_id()
    ));

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

ALTER TABLE booking ENABLE ROW LEVEL SECURITY;

-- booking não tem condominium_id direto; usa amenity como âncora
CREATE POLICY booking_isolation ON booking
    USING (EXISTS (
        SELECT 1 FROM amenity
        WHERE amenity.id = booking.amenity_id
          AND amenity.condominium_id = current_condominium_id()
    ));

-- ============================================================
-- 6. PORTARIA — Visitantes e Entregas
-- ============================================================

CREATE TABLE visitor (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    condominium_id  UUID        NOT NULL REFERENCES condominium(id) ON DELETE CASCADE,
    resident_id     UUID        NOT NULL REFERENCES resident(id) ON DELETE CASCADE,
    name            TEXT        NOT NULL,
    document        TEXT,
    photo_url       TEXT,
    expected_at     TIMESTAMPTZ,
    arrived_at      TIMESTAMPTZ,
    left_at         TIMESTAMPTZ,
    status          TEXT        NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending','arrived','left','cancelled')),
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE visitor ENABLE ROW LEVEL SECURITY;

CREATE POLICY visitor_isolation ON visitor
    USING (condominium_id = current_condominium_id());

CREATE TABLE delivery (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    condominium_id  UUID        NOT NULL REFERENCES condominium(id) ON DELETE CASCADE,
    resident_id     UUID        NOT NULL REFERENCES resident(id) ON DELETE CASCADE,
    sender          TEXT,
    description     TEXT,
    tracking_code   TEXT,
    photo_url       TEXT,
    received_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    picked_up_at    TIMESTAMPTZ,
    status          TEXT        NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending','picked_up')),
    notes           TEXT
);

ALTER TABLE delivery ENABLE ROW LEVEL SECURITY;

CREATE POLICY delivery_isolation ON delivery
    USING (condominium_id = current_condominium_id());

-- ============================================================
-- 7. NOTIFICAÇÕES
-- ============================================================

CREATE TABLE notification (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    condominium_id  UUID        NOT NULL REFERENCES condominium(id) ON DELETE CASCADE,
    resident_id     UUID        NOT NULL REFERENCES resident(id) ON DELETE CASCADE,
    type            TEXT        NOT NULL CHECK (type IN (
                        'comment',
                        'like',
                        'ticket_update',
                        'timeline_update',
                        'poll_closed',
                        'booking_update',
                        'visitor_arrived',
                        'delivery',
                        'notice',
                        'general'
                    )),
    title           TEXT        NOT NULL,
    body            TEXT,
    reference_id    UUID,
    reference_table TEXT,
    read            BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE notification ENABLE ROW LEVEL SECURITY;

CREATE POLICY notification_isolation ON notification
    USING (condominium_id = current_condominium_id());

-- ============================================================
-- 8. ÍNDICES
-- ============================================================

-- Feed / interações
CREATE INDEX idx_post_condominium   ON post(condominium_id);
CREATE INDEX idx_post_resident      ON post(resident_id);
CREATE INDEX idx_post_type_date     ON post(type, created_at DESC);
CREATE INDEX idx_comment_post       ON comment(post_id);
CREATE INDEX idx_like_post          ON like_(post_id);

-- Reservas
CREATE INDEX idx_booking_amenity_date ON booking(amenity_id, date);
CREATE INDEX idx_booking_resident     ON booking(resident_id);

-- Timeline
CREATE INDEX idx_step_timeline ON timeline_step(timeline_id, order_index);

-- Portaria
CREATE INDEX idx_visitor_resident ON visitor(resident_id);
CREATE INDEX idx_visitor_pending  ON visitor(status, expected_at)
    WHERE status IN ('pending','arrived');

CREATE INDEX idx_delivery_resident ON delivery(resident_id);
CREATE INDEX idx_delivery_pending  ON delivery(status, received_at)
    WHERE status = 'pending';

-- Notificações
CREATE INDEX idx_notification_resident ON notification(resident_id);
CREATE INDEX idx_notification_unread   ON notification(resident_id, created_at DESC)
    WHERE read = FALSE;

-- Índices de tenant nas tabelas com coluna direta
CREATE INDEX idx_resident_condominium   ON resident(condominium_id);
CREATE INDEX idx_vehicle_condominium    ON vehicle(condominium_id);
CREATE INDEX idx_parking_condominium    ON parking_spot(condominium_id);
CREATE INDEX idx_staff_condominium      ON staff(condominium_id);
CREATE INDEX idx_amenity_condominium    ON amenity(condominium_id);
CREATE INDEX idx_visitor_condominium    ON visitor(condominium_id);
CREATE INDEX idx_delivery_condominium   ON delivery(condominium_id);
CREATE INDEX idx_notification_condo     ON notification(condominium_id);
CREATE INDEX idx_timeline_condominium   ON service_timeline(condominium_id);

-- ============================================================
-- 9. TRIGGERS
-- ============================================================

-- 9a. Garantir 1 voto por morador por enquete
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

-- 9b. Manter contador de votos sincronizado na poll_option
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

-- 9c. Notificar morador automaticamente quando uma nova entrega for registrada
CREATE OR REPLACE FUNCTION fn_notify_delivery()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO notification (condominium_id, resident_id, type, title, body, reference_id, reference_table)
    VALUES (
        NEW.condominium_id,
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

-- 9d. Notificar morador quando seu visitante tiver a chegada registrada
CREATE OR REPLACE FUNCTION fn_notify_visitor_arrived()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status = 'arrived' AND OLD.status <> 'arrived' THEN
        INSERT INTO notification (condominium_id, resident_id, type, title, body, reference_id, reference_table)
        VALUES (
            NEW.condominium_id,
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
-- 10. DADOS INICIAIS (seed)
-- ============================================================
-- Atenção: seeds agora precisam de um condominium_id existente.
-- Substitua <SEU_CONDOMINIUM_ID> pelo UUID após inserir o condomínio.
--
-- Exemplo:
--   INSERT INTO condominium (name) VALUES ('Condomínio Exemplo') RETURNING id;
--   -- copie o UUID retornado e use abaixo

-- INSERT INTO category (condominium_id, name) VALUES
--     ('<SEU_CONDOMINIUM_ID>', 'Maintenance'),
--     ('<SEU_CONDOMINIUM_ID>', 'Security'),
--     ('<SEU_CONDOMINIUM_ID>', 'Cleaning'),
--     ('<SEU_CONDOMINIUM_ID>', 'Infrastructure'),
--     ('<SEU_CONDOMINIUM_ID>', 'Financial'),
--     ('<SEU_CONDOMINIUM_ID>', 'Other');
--
-- INSERT INTO amenity (condominium_id, name, max_capacity, description) VALUES
--     ('<SEU_CONDOMINIUM_ID>', 'Swimming Pool',  50, 'Adult and children pool'),
--     ('<SEU_CONDOMINIUM_ID>', 'Party Hall',     80, 'Main hall with kitchen'),
--     ('<SEU_CONDOMINIUM_ID>', 'BBQ Area',       30, 'Covered barbecue grills'),
--     ('<SEU_CONDOMINIUM_ID>', 'Gym',            20, 'Weight and cardio equipment'),
--     ('<SEU_CONDOMINIUM_ID>', 'Sports Court',   40, 'Football, volleyball and basketball');

-- ============================================================
-- SUGESTÕES PARA VERSÕES FUTURAS
-- ============================================================
-- (mantidas iguais ao original — ver schema original)

-- ============================================================
-- RESUMO DAS MUDANÇAS DE RLS
-- ============================================================
--
--  TABELA                  COLUNA TENANT       POLÍTICA RLS
--  ─────────────────────── ─────────────────── ──────────────────────────────────────
--  condominium             (âncora, sem RLS)   —
--  resident                condominium_id      direta
--  vehicle                 condominium_id      direta
--  parking_spot            condominium_id      direta
--  staff                   condominium_id      direta
--  post                    condominium_id      direta   ← raiz do feed
--  ticket                  (via post)          JOIN com post
--  category                condominium_id      direta
--  ticket_category         (via category)      JOIN com category
--  suggestion              (via post)          JOIN com post
--  trade                   (via post)          JOIN com post
--  poll                    (via post)          JOIN com post
--  poll_option             (via post/poll)     JOIN com post
--  poll_vote               (via resident)      JOIN com resident
--  notice                  (via post)          JOIN com post
--  comment                 (via post)          JOIN com post
--  like_                   (via post)          JOIN com post
--  service_timeline        condominium_id      direta
--  timeline_step           (via service_tl.)   JOIN com service_timeline
--  step_staff              (via staff)         JOIN com staff
--  step_attachment         (via timeline_step) JOIN duplo
--  amenity                 condominium_id      direta
--  amenity_schedule        (via amenity)       JOIN com amenity
--  amenity_exception       (via amenity)       JOIN com amenity
--  booking                 (via amenity)       JOIN com amenity
--  visitor                 condominium_id      direta
--  delivery                condominium_id      direta
--  notification            condominium_id      direta
--
--  VARIÁVEL DE SESSÃO OBRIGATÓRIA (definir após cada conexão):
--    SET app.current_condominium_id = '<uuid>';
--
--  ROLES RECOMENDADOS:
--    - app_user  → acesso normal, RLS ativo
--    - app_admin → BYPASSRLS para operações administrativas cross-tenant