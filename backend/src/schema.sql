CREATE TABLE IF NOT EXISTS schema_migrations (version integer PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now());

CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY,
  email varchar(254) NOT NULL UNIQUE,
  display_name varchar(80) NOT NULL,
  password_hash text,
  google_sub text UNIQUE,
  email_verified boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS sessions (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  refresh_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sessions_user_idx ON sessions(user_id);
INSERT INTO schema_migrations(version) VALUES (1) ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS product_sync_heads (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  cursor integer NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS user_products (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  id varchar(100) NOT NULL,
  version integer NOT NULL,
  cursor integer NOT NULL,
  deleted boolean NOT NULL DEFAULT false,
  data jsonb,
  PRIMARY KEY (user_id,id)
);
CREATE INDEX IF NOT EXISTS user_products_changes_idx ON user_products(user_id,cursor);
CREATE TABLE IF NOT EXISTS product_mutations (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  mutation_id varchar(100) NOT NULL,
  request_hash varchar(64) NOT NULL,
  result jsonb NOT NULL,
  PRIMARY KEY (user_id,mutation_id)
);
INSERT INTO schema_migrations(version) VALUES (2) ON CONFLICT DO NOTHING;
