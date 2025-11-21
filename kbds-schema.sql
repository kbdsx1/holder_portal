-- KBDS Holder Portal Database Schema
-- PostgreSQL Database Schema for Knuckle Bunny Death Squad Holder Portal

-- Enable UUID extension if needed
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- SEQUENCES
-- ============================================

CREATE SEQUENCE IF NOT EXISTS public.claim_transactions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE SEQUENCE IF NOT EXISTS public.nft_metadata_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE SEQUENCE IF NOT EXISTS public.roles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE SEQUENCE IF NOT EXISTS public.user_wallets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- ============================================
-- TABLES
-- ============================================

-- Claim Accounts
CREATE TABLE IF NOT EXISTS public.claim_accounts (
    discord_id character varying(255) NOT NULL,
    unclaimed_amount bigint DEFAULT 0,
    total_claimed bigint DEFAULT 0,
    last_claim_time timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    discord_name text,
    CONSTRAINT new_claim_accounts_pkey PRIMARY KEY (discord_id)
);

-- Claim Transactions
CREATE TABLE IF NOT EXISTS public.claim_transactions (
    id integer NOT NULL DEFAULT nextval('public.claim_transactions_id_seq'::regclass),
    discord_id character varying(255) NOT NULL,
    amount integer NOT NULL,
    transaction_hash character varying(255),
    status character varying(20) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    processed_at timestamp with time zone,
    error_message text,
    CONSTRAINT claim_transactions_pkey PRIMARY KEY (id),
    CONSTRAINT claim_transactions_status_check CHECK (((status)::text = ANY (ARRAY[('processing'::character varying)::text, ('completed'::character varying)::text, ('failed'::character varying)::text])))
);

-- Collection Counts
CREATE TABLE IF NOT EXISTS public.collection_counts (
    discord_id character varying(100),
    discord_name character varying(255),
    total_count integer,
    last_updated timestamp without time zone,
    gold_count integer DEFAULT 0,
    silver_count integer DEFAULT 0,
    purple_count integer DEFAULT 0,
    dark_green_count integer DEFAULT 0,
    light_green_count integer DEFAULT 0,
    og420_count integer DEFAULT 0,
    cnft_gold_count integer DEFAULT 0,
    cnft_silver_count integer DEFAULT 0,
    cnft_purple_count integer DEFAULT 0,
    cnft_dark_green_count integer DEFAULT 0,
    cnft_light_green_count integer DEFAULT 0,
    cnft_total_count integer DEFAULT 0,
    CONSTRAINT collection_counts_discord_id_key UNIQUE (discord_id)
);

-- Daily Rewards
CREATE TABLE IF NOT EXISTS public.daily_rewards (
    discord_id character varying(255) NOT NULL,
    discord_name character varying(255),
    total_daily_reward integer DEFAULT 0,
    is_processed boolean DEFAULT false,
    last_accumulated_at timestamp with time zone,
    CONSTRAINT daily_rewards_new_pkey PRIMARY KEY (discord_id)
);

-- NFT Metadata
CREATE TABLE IF NOT EXISTS public.nft_metadata (
    id integer NOT NULL DEFAULT nextval('public.nft_metadata_id_seq'::regclass),
    mint_address character varying(44) NOT NULL,
    name character varying(255),
    symbol character varying(50),
    uri text,
    creators jsonb,
    collection jsonb,
    image_url text,
    owner_wallet character varying(44),
    owner_discord_id character varying(100),
    owner_name character varying(255),
    is_listed boolean DEFAULT false,
    list_price numeric(20,9),
    last_sale_price numeric(20,9),
    marketplace character varying(10),
    rarity_rank integer,
    original_lister character varying(44),
    lister_discord_name character varying(255),
    burrows character varying(50),
    CONSTRAINT nft_metadata_pkey PRIMARY KEY (id),
    CONSTRAINT nft_metadata_mint_address_key UNIQUE (mint_address)
);

-- Roles Catalog
CREATE TABLE IF NOT EXISTS public.roles (
    id integer NOT NULL DEFAULT nextval('public.roles_id_seq'::regclass),
    name character varying(255) NOT NULL,
    type character varying(50) NOT NULL,
    collection character varying(50) NOT NULL,
    threshold integer DEFAULT 1,
    discord_role_id character varying(255) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    display_name character varying(255),
    color character varying(7),
    emoji_url text,
    CONSTRAINT roles_pkey PRIMARY KEY (id),
    CONSTRAINT roles_discord_role_id_key UNIQUE (discord_role_id),
    CONSTRAINT roles_type_check CHECK (((type)::text = ANY ((ARRAY['holder'::character varying, 'whale'::character varying, 'token'::character varying, 'special'::character varying, 'collab'::character varying, 'top10'::character varying, 'level'::character varying])::text[])))
);

-- Session (for Express sessions)
CREATE TABLE IF NOT EXISTS public.session (
    sid character varying NOT NULL,
    sess json NOT NULL,
    expire timestamp(6) without time zone NOT NULL,
    CONSTRAINT session_pkey PRIMARY KEY (sid)
);

-- Token Holders
CREATE TABLE IF NOT EXISTS public.token_holders (
    wallet_address character varying(44) NOT NULL,
    balance numeric(20,9) DEFAULT 0,
    owner_discord_id character varying(100),
    owner_name character varying(255),
    last_updated timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    is_exempt boolean DEFAULT false,
    CONSTRAINT token_holders_pkey PRIMARY KEY (wallet_address)
);

-- User Wallets
CREATE TABLE IF NOT EXISTS public.user_wallets (
    id integer NOT NULL DEFAULT nextval('public.user_wallets_id_seq'::regclass),
    discord_id character varying(100) NOT NULL,
    wallet_address character varying(44) NOT NULL,
    is_primary boolean DEFAULT false,
    connected_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    last_used timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    discord_name character varying(255),
    CONSTRAINT user_wallets_pkey PRIMARY KEY (id),
    CONSTRAINT user_wallets_discord_id_wallet_address_key UNIQUE (discord_id, wallet_address)
);

-- User Roles
CREATE TABLE IF NOT EXISTS public.user_roles (
    discord_id character varying(100),
    discord_name text,
    last_updated timestamp without time zone,
    roles jsonb,
    harvester_gold boolean DEFAULT false,
    harvester_silver boolean DEFAULT false,
    harvester_purple boolean DEFAULT false,
    harvester_dark_green boolean DEFAULT false,
    harvester_light_green boolean DEFAULT false
);

-- ============================================
-- VIEWS
-- ============================================

CREATE OR REPLACE VIEW public.nft_metadata_aggregated AS
 SELECT symbol,
    count(*) AS total_supply,
    count(*) FILTER (WHERE is_listed) AS listed_count
   FROM public.nft_metadata
  GROUP BY symbol;

CREATE OR REPLACE VIEW public.token_holders_aggregated AS
 SELECT uw.discord_id,
    COALESCE(sum(bh.balance), (0)::numeric) AS total_balance,
    count(bh.wallet_address) AS wallet_count,
    now() AS last_updated
   FROM (public.user_wallets uw
     LEFT JOIN public.token_holders bh ON (((uw.wallet_address)::text = (bh.wallet_address)::text)))
  GROUP BY uw.discord_id;

CREATE OR REPLACE VIEW public.user_roles_view AS
 SELECT discord_id,
    discord_name,
    roles,
    last_updated
   FROM public.user_roles;

-- ============================================
-- INDEXES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_nft_metadata_symbol_name ON public.nft_metadata(symbol, name);
CREATE INDEX IF NOT EXISTS idx_nft_metadata_owner_wallet ON public.nft_metadata(owner_wallet);
CREATE INDEX IF NOT EXISTS idx_nft_metadata_owner_discord_id ON public.nft_metadata(owner_discord_id);
CREATE INDEX IF NOT EXISTS idx_roles_type_collection ON public.roles(type, collection);
CREATE INDEX IF NOT EXISTS idx_roles_discord_role_id ON public.roles(discord_role_id);
CREATE INDEX IF NOT EXISTS idx_token_holders_owner_discord_id ON public.token_holders(owner_discord_id);
CREATE INDEX IF NOT EXISTS idx_claim_transactions_discord_id ON public.claim_transactions(discord_id);
CREATE INDEX IF NOT EXISTS idx_claim_transactions_status ON public.claim_transactions(status);
CREATE INDEX IF NOT EXISTS nft_lookup_idx ON public.nft_metadata(mint_address);
CREATE INDEX IF NOT EXISTS nft_rank_lookup_idx ON public.nft_metadata(rarity_rank) WHERE rarity_rank IS NOT NULL;

-- ============================================
-- FUNCTIONS
-- ============================================

-- Rebuild user roles function
CREATE OR REPLACE FUNCTION public.rebuild_user_roles(p_discord_id character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  WITH counts AS (
    SELECT * FROM collection_counts WHERE discord_id = p_discord_id
  ),
  token_balance AS (
    SELECT COALESCE(SUM(balance), 0) AS total_balance
    FROM token_holders
    WHERE owner_discord_id = p_discord_id
       OR wallet_address IN (SELECT wallet_address FROM user_wallets WHERE discord_id = p_discord_id)
  ),
  user_role_flags AS (
    SELECT 
      harvester_gold,
      harvester_silver,
      harvester_purple,
      harvester_dark_green,
      harvester_light_green
    FROM user_roles
    WHERE discord_id = p_discord_id
  ),
  eligible AS (
    SELECT r.* FROM roles r
    LEFT JOIN counts c ON r.collection = 'KBDS'
    LEFT JOIN token_balance tb ON true
    LEFT JOIN user_role_flags urf ON true
    WHERE r.collection = 'KBDS'
      AND (
        -- Holder roles based on collection_counts
        (r.type = 'holder' AND (
          (r.name='holder_gold' AND c.gold_count >= COALESCE(r.threshold,1)) OR
          (r.name='holder_silver' AND c.silver_count >= COALESCE(r.threshold,1)) OR
          (r.name='holder_purple' AND c.purple_count >= COALESCE(r.threshold,1)) OR
          (r.name='holder_dark_green' AND c.dark_green_count >= COALESCE(r.threshold,1)) OR
          (r.name='holder_light_green' AND c.light_green_count >= COALESCE(r.threshold,1)) OR
          (r.name='og420' AND c.og420_count >= COALESCE(r.threshold,1))
        )) OR
        -- Token roles based on token_holders balance
        (r.type = 'token' AND tb.total_balance >= COALESCE(r.threshold, 0)) OR
        -- COLLECTOR role: has 1+ of each of the 5 colors
        (r.type = 'special' AND r.name = 'collector' AND 
         c.gold_count >= 1 AND c.silver_count >= 1 AND c.purple_count >= 1 AND 
         c.dark_green_count >= 1 AND c.light_green_count >= 1) OR
        -- LEVEL roles based on total_count (only highest one will be selected)
        (r.type = 'level' AND c.total_count >= COALESCE(r.threshold, 0))
      )
    UNION
    -- HARVESTER roles based on harvester boolean flags
    SELECT r.* FROM roles r
    JOIN user_role_flags urf ON true
    WHERE r.type = 'holder' 
      AND r.collection LIKE 'seedling_%'
      AND (
        (r.collection = 'seedling_gold' AND urf.harvester_gold = TRUE) OR
        (r.collection = 'seedling_silver' AND urf.harvester_silver = TRUE) OR
        (r.collection = 'seedling_purple' AND urf.harvester_purple = TRUE) OR
        (r.collection = 'seedling_dark_green' AND urf.harvester_dark_green = TRUE) OR
        (r.collection = 'seedling_light_green' AND urf.harvester_light_green = TRUE)
      )
  ),
  -- Filter level roles to only include the highest one
  level_roles AS (
    SELECT * FROM eligible WHERE type = 'level'
  ),
  highest_level AS (
    SELECT * FROM level_roles
    ORDER BY threshold DESC
    LIMIT 1
  ),
  -- Combine eligible roles (excluding level roles) with highest level role
  final_eligible AS (
    SELECT * FROM eligible WHERE type != 'level'
    UNION
    SELECT * FROM highest_level
  )
  UPDATE user_roles ur
  SET roles = (
    SELECT jsonb_agg(jsonb_build_object(
      'id', r.discord_role_id,
      'name', r.name,
      'type', r.type,
      'collection', r.collection,
      'color', r.color,
      'emoji_url', r.emoji_url,
      'display_name', r.display_name
    ))
    FROM final_eligible r
  ),
  last_updated = NOW()
  WHERE ur.discord_id = p_discord_id;
END;
$function$;

-- Create user on wallet connect
CREATE OR REPLACE FUNCTION public.create_user_on_wallet_connect() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  wallet_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO wallet_count FROM user_wallets WHERE discord_id = NEW.discord_id;

  IF wallet_count = 1 THEN
    INSERT INTO user_roles (discord_id, discord_name)
    VALUES (NEW.discord_id, NEW.discord_name)
    ON CONFLICT DO NOTHING;

    INSERT INTO claim_accounts (discord_id, unclaimed_amount, total_claimed, last_claim_time)
    VALUES (NEW.discord_id, 0, 0, CURRENT_TIMESTAMP)
    ON CONFLICT DO NOTHING;

    INSERT INTO daily_rewards (discord_id, discord_name, total_daily_reward, is_processed)
    VALUES (NEW.discord_id, NEW.discord_name, 0, false)
    ON CONFLICT (discord_id) DO NOTHING;
  END IF;

  INSERT INTO collection_counts (
    discord_id, discord_name, total_count, last_updated,
    gold_count, silver_count, purple_count, dark_green_count, light_green_count
  )
  VALUES (
    NEW.discord_id, NEW.discord_name, 0, CURRENT_TIMESTAMP,
    0, 0, 0, 0, 0
  )
  ON CONFLICT DO NOTHING;

  RETURN NEW;
END;
$$;

-- Rebuild roles on collection counts update
CREATE OR REPLACE FUNCTION public.rebuild_roles_on_collection_counts_update()
RETURNS TRIGGER AS $$
BEGIN
  -- Update harvester flags from collection_counts
  INSERT INTO user_roles (
    discord_id, 
    harvester_gold, 
    harvester_silver, 
    harvester_purple, 
    harvester_dark_green, 
    harvester_light_green
  )
  SELECT 
    NEW.discord_id,
    (NEW.cnft_gold_count > 0) AS harvester_gold,
    (NEW.cnft_silver_count > 0) AS harvester_silver,
    (NEW.cnft_purple_count > 0) AS harvester_purple,
    (NEW.cnft_dark_green_count > 0) AS harvester_dark_green,
    (NEW.cnft_light_green_count > 0) AS harvester_light_green
  ON CONFLICT (discord_id) DO UPDATE SET
    harvester_gold = EXCLUDED.harvester_gold,
    harvester_silver = EXCLUDED.harvester_silver,
    harvester_purple = EXCLUDED.harvester_purple,
    harvester_dark_green = EXCLUDED.harvester_dark_green,
    harvester_light_green = EXCLUDED.harvester_light_green;

  -- Rebuild roles JSONB array
  PERFORM rebuild_user_roles(NEW.discord_id);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- TRIGGERS
-- ============================================

-- Trigger to create user records when wallet is connected
DROP TRIGGER IF EXISTS trg_create_user_on_wallet_connect ON public.user_wallets;
CREATE TRIGGER trg_create_user_on_wallet_connect
  AFTER INSERT ON user_wallets
  FOR EACH ROW
  EXECUTE FUNCTION create_user_on_wallet_connect();

-- Trigger to rebuild roles when collection_counts changes
DROP TRIGGER IF EXISTS trigger_rebuild_roles_on_collection_counts_update ON public.collection_counts;
CREATE TRIGGER trigger_rebuild_roles_on_collection_counts_update
  AFTER INSERT OR UPDATE ON collection_counts
  FOR EACH ROW
  EXECUTE FUNCTION rebuild_roles_on_collection_counts_update();

-- ============================================
-- FOREIGN KEYS (if needed)
-- ============================================

-- Add foreign key constraint for claim_transactions if needed
-- ALTER TABLE ONLY public.claim_transactions
--     ADD CONSTRAINT claim_transactions_discord_id_fkey 
--     FOREIGN KEY (discord_id) REFERENCES public.claim_accounts(discord_id);

