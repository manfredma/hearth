CREATE TABLE user_identity (
    id CHAR(36) NOT NULL,
    issuer VARCHAR(512) NOT NULL,
    subject VARCHAR(512) NOT NULL,
    display_name VARCHAR(160) NOT NULL,
    email VARCHAR(320) NULL,
    issuer_identity_hash BINARY(32) GENERATED ALWAYS AS (UNHEX(SHA2(issuer, 256))) STORED,
    subject_identity_hash BINARY(32) GENERATED ALWAYS AS (UNHEX(SHA2(subject, 256))) STORED,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_user_identity_issuer_subject (issuer_identity_hash, subject_identity_hash)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE application (
    id CHAR(36) NOT NULL,
    application_key VARCHAR(80) NOT NULL,
    display_name VARCHAR(160) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_application_key (application_key)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE application_redirect_uri (
    application_id CHAR(36) NOT NULL,
    redirect_uri VARCHAR(2048) NOT NULL,
    redirect_uri_hash BINARY(32) GENERATED ALWAYS AS (UNHEX(SHA2(redirect_uri, 256))) STORED,
    PRIMARY KEY (application_id, redirect_uri_hash),
    CONSTRAINT fk_application_redirect_uri_application FOREIGN KEY (application_id) REFERENCES application (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE application_access (
    user_id CHAR(36) NOT NULL,
    application_id CHAR(36) NOT NULL,
    role_key VARCHAR(160) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (user_id, application_id, role_key),
    CONSTRAINT fk_application_access_user FOREIGN KEY (user_id) REFERENCES user_identity (id),
    CONSTRAINT fk_application_access_application FOREIGN KEY (application_id) REFERENCES application (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE audit_event (
    id CHAR(36) NOT NULL,
    event_type VARCHAR(120) NOT NULL,
    actor_user_id CHAR(36) NULL,
    application_key VARCHAR(80) NULL,
    event_payload JSON NOT NULL,
    occurred_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (id),
    KEY ix_audit_event_occurred_at (occurred_at),
    CONSTRAINT fk_audit_event_actor FOREIGN KEY (actor_user_id) REFERENCES user_identity (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
