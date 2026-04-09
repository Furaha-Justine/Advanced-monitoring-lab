CREATE TABLE IF NOT EXISTS users (
  id      INT AUTO_INCREMENT PRIMARY KEY,
  name    VARCHAR(100) NOT NULL,
  email   VARCHAR(150) NOT NULL UNIQUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (name, email) VALUES
  ('Alice Mugisha',  'alice@example.com'),
  ('Bob Nkurunziza', 'bob@example.com'),
  ('Carol Uwase',    'carol@example.com');