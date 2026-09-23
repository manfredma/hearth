CREATE TABLE identity_credential (
    user_id CHAR(36) NOT NULL,
    login VARCHAR(160) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    failed_attempts INT NOT NULL DEFAULT 0,
    locked_until TIMESTAMP(6) NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (user_id),
    UNIQUE KEY uk_identity_credential_login (login),
    CONSTRAINT fk_identity_credential_user FOREIGN KEY (user_id) REFERENCES user_identity (id),
    CONSTRAINT ck_identity_credential_failed_attempts CHECK (failed_attempts >= 0)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
