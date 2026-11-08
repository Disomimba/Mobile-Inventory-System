CREATE TABLE private.password_recovery_challenges (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  profile_id bigint NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  channel text NOT NULL CHECK (channel = 'sms'),
  code_hash bytea NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  attempts integer NOT NULL DEFAULT 0,
  verified_at timestamptz,
  reset_token_hash bytea,
  reset_expires_at timestamptz,
  consumed_at timestamptz
);

CREATE INDEX password_recovery_profile_created_idx
  ON private.password_recovery_challenges (profile_id, created_at DESC);

REVOKE ALL ON private.password_recovery_challenges FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON private.password_recovery_challenges TO service_role, postgres;
