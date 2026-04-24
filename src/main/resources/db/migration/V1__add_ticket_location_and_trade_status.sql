ALTER TABLE ticket
    ADD COLUMN location TEXT;

ALTER TABLE trade
    ADD COLUMN status TEXT NOT NULL DEFAULT 'open'
        CHECK (status IN ('open','in_progress','resolved','cancelled'));
