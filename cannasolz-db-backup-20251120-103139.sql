--
-- PostgreSQL database dump
--

-- Dumped from database version 17.5 (aa1f746)
-- Dumped by pg_dump version 17.5

-- Started on 2025-11-20 10:31:39 GMT

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

ALTER TABLE IF EXISTS ONLY public.claim_transactions DROP CONSTRAINT IF EXISTS claim_transactions_discord_id_fkey;
DROP TRIGGER IF EXISTS update_nft_owner_details_trigger ON public.nft_metadata;
DROP TRIGGER IF EXISTS update_nft_lister_details_trigger ON public.nft_metadata;
DROP TRIGGER IF EXISTS trigger_rebuild_roles_on_collection_counts_update ON public.collection_counts;
DROP TRIGGER IF EXISTS trg_update_nft_metadata_on_wallet_connect ON public.user_wallets;
DROP TRIGGER IF EXISTS trg_update_daily_rewards_on_collection_counts ON public.collection_counts;
DROP TRIGGER IF EXISTS trg_update_collection_counts_on_metadata ON public.nft_metadata;
DROP TRIGGER IF EXISTS trg_create_user_on_wallet_connect ON public.user_wallets;
DROP TRIGGER IF EXISTS set_claim_account_discord_name ON public.claim_accounts;
DROP TRIGGER IF EXISTS collection_counts_update_user_roles ON public.collection_counts;
DROP TRIGGER IF EXISTS bux_holders_update_user_roles ON public.token_holders;
DROP TRIGGER IF EXISTS add_bux_holder_on_wallet_insert ON public.user_wallets;
DROP INDEX IF EXISTS public.user_roles_pkey;
DROP INDEX IF EXISTS public.nft_rank_lookup_idx;
DROP INDEX IF EXISTS public.nft_lookup_idx;
DROP INDEX IF EXISTS public.idx_token_holders_owner_discord_id;
DROP INDEX IF EXISTS public.idx_roles_type_collection;
DROP INDEX IF EXISTS public.idx_roles_discord_role_id;
DROP INDEX IF EXISTS public.idx_nft_metadata_symbol_name;
DROP INDEX IF EXISTS public.idx_claim_transactions_status;
DROP INDEX IF EXISTS public.idx_claim_transactions_discord_id;
ALTER TABLE IF EXISTS ONLY public.user_wallets DROP CONSTRAINT IF EXISTS user_wallets_pkey;
ALTER TABLE IF EXISTS ONLY public.user_wallets DROP CONSTRAINT IF EXISTS user_wallets_discord_id_wallet_address_key;
ALTER TABLE IF EXISTS ONLY public.token_holders DROP CONSTRAINT IF EXISTS token_holders_pkey;
ALTER TABLE IF EXISTS ONLY public.session DROP CONSTRAINT IF EXISTS session_pkey;
ALTER TABLE IF EXISTS ONLY public.roles DROP CONSTRAINT IF EXISTS roles_pkey;
ALTER TABLE IF EXISTS ONLY public.roles DROP CONSTRAINT IF EXISTS roles_discord_role_id_key;
ALTER TABLE IF EXISTS ONLY public.nft_metadata DROP CONSTRAINT IF EXISTS nft_metadata_pkey;
ALTER TABLE IF EXISTS ONLY public.nft_metadata DROP CONSTRAINT IF EXISTS nft_metadata_mint_address_key;
ALTER TABLE IF EXISTS ONLY public.claim_accounts DROP CONSTRAINT IF EXISTS new_claim_accounts_pkey;
ALTER TABLE IF EXISTS ONLY public.daily_rewards DROP CONSTRAINT IF EXISTS daily_rewards_new_pkey;
ALTER TABLE IF EXISTS ONLY public.collection_counts DROP CONSTRAINT IF EXISTS collection_counts_discord_id_key;
ALTER TABLE IF EXISTS ONLY public.claim_transactions DROP CONSTRAINT IF EXISTS claim_transactions_pkey;
ALTER TABLE IF EXISTS public.user_wallets ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.roles ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.nft_metadata ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.claim_transactions ALTER COLUMN id DROP DEFAULT;
DROP SEQUENCE IF EXISTS public.user_wallets_id_seq;
DROP VIEW IF EXISTS public.user_roles_view;
DROP TABLE IF EXISTS public.user_roles;
DROP VIEW IF EXISTS public.token_holders_aggregated;
DROP TABLE IF EXISTS public.user_wallets;
DROP TABLE IF EXISTS public.token_holders;
DROP TABLE IF EXISTS public.session;
DROP SEQUENCE IF EXISTS public.roles_id_seq;
DROP TABLE IF EXISTS public.roles;
DROP SEQUENCE IF EXISTS public.nft_metadata_id_seq;
DROP VIEW IF EXISTS public.nft_metadata_aggregated;
DROP TABLE IF EXISTS public.nft_metadata;
DROP TABLE IF EXISTS public.daily_rewards;
DROP TABLE IF EXISTS public.collection_counts;
DROP SEQUENCE IF EXISTS public.claim_transactions_id_seq;
DROP TABLE IF EXISTS public.claim_transactions;
DROP TABLE IF EXISTS public.claim_accounts;
DROP FUNCTION IF EXISTS public.update_user_roles_on_collection_counts_change();
DROP FUNCTION IF EXISTS public.update_user_roles_on_bux_change();
DROP FUNCTION IF EXISTS public.update_user_roles();
DROP FUNCTION IF EXISTS public.update_roles();
DROP FUNCTION IF EXISTS public.update_ownership();
DROP FUNCTION IF EXISTS public.update_nft_owner_details();
DROP FUNCTION IF EXISTS public.update_nft_metadata_on_wallet_connect();
DROP FUNCTION IF EXISTS public.update_nft_lister_details();
DROP FUNCTION IF EXISTS public.update_daily_rewards_from_collection_counts();
DROP FUNCTION IF EXISTS public.update_collection_counts(p_discord_id text);
DROP FUNCTION IF EXISTS public.trg_update_daily_rewards();
DROP FUNCTION IF EXISTS public.sync_username();
DROP FUNCTION IF EXISTS public.sync_daily_rewards();
DROP FUNCTION IF EXISTS public.sync_claim_account_discord_name();
DROP FUNCTION IF EXISTS public.refresh_counts_on_metadata();
DROP FUNCTION IF EXISTS public.rebuild_user_roles(p_discord_id character varying);
DROP FUNCTION IF EXISTS public.rebuild_roles_on_collection_counts_update();
DROP FUNCTION IF EXISTS public.rebuild_all_roles();
DROP FUNCTION IF EXISTS public.process_pending_rewards();
DROP FUNCTION IF EXISTS public.process_daily_rewards();
DROP FUNCTION IF EXISTS public.notify_role_changes();
DROP FUNCTION IF EXISTS public.manage_whale_roles();
DROP FUNCTION IF EXISTS public.manage_roles_array();
DROP FUNCTION IF EXISTS public.manage_buxdao5_role();
DROP FUNCTION IF EXISTS public.log_nft_ownership_change();
DROP FUNCTION IF EXISTS public.insert_bux_holder_on_new_wallet();
DROP FUNCTION IF EXISTS public.get_user_roles_and_holdings(p_discord_id character varying);
DROP FUNCTION IF EXISTS public.get_user_roles(p_discord_id character varying);
DROP FUNCTION IF EXISTS public.fix_buxdao5_role();
DROP FUNCTION IF EXISTS public.create_user_on_wallet_connect();
DROP FUNCTION IF EXISTS public.create_missing_reward_entries();
DROP FUNCTION IF EXISTS public.calculate_initial_daily_rewards();
DROP FUNCTION IF EXISTS public.calculate_collection_counts();
--
-- TOC entry 234 (class 1255 OID 16487)
-- Name: calculate_collection_counts(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calculate_collection_counts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    debug_info TEXT;
BEGIN
    -- Log the trigger event
    RAISE NOTICE 'Trigger called for wallet: %, old wallet: %', NEW.owner_wallet, OLD.owner_wallet;
    
    WITH collection_totals AS (
        SELECT 
            owner_wallet,
            owner_discord_id,
            owner_name,
            COUNT(CASE WHEN symbol = 'FCKEDCATZ' AND is_listed = false THEN 1 END) as fcked_catz_count,
            COUNT(CASE WHEN symbol = 'MM' AND is_listed = false THEN 1 END) as money_monsters_count,
            COUNT(CASE WHEN symbol = 'AIBB' AND is_listed = false THEN 1 END) as aibitbots_count,
            COUNT(CASE WHEN symbol = 'MM3D' AND is_listed = false THEN 1 END) as money_monsters_3d_count,
            COUNT(CASE WHEN symbol = 'CelebCatz' AND is_listed = false THEN 1 END) as celeb_catz_count,
            COUNT(CASE WHEN is_listed = false THEN 1 END) as total_count
        FROM nft_metadata
        WHERE owner_wallet = COALESCE(NEW.owner_wallet, OLD.owner_wallet)
        GROUP BY owner_wallet, owner_discord_id, owner_name
    )
    INSERT INTO collection_counts (
        wallet_address,
        discord_id,
        discord_name,
        fcked_catz_count,
        money_monsters_count,
        aibitbots_count,
        money_monsters_3d_count,
        celeb_catz_count,
        total_count,
        last_updated
    )
    SELECT 
        owner_wallet,
        owner_discord_id,
        owner_name,
        fcked_catz_count,
        money_monsters_count,
        aibitbots_count,
        money_monsters_3d_count,
        celeb_catz_count,
        total_count,
        CURRENT_TIMESTAMP
    FROM collection_totals
    ON CONFLICT (wallet_address) 
    DO UPDATE SET
        discord_id = EXCLUDED.discord_id,
        discord_name = EXCLUDED.discord_name,
        fcked_catz_count = EXCLUDED.fcked_catz_count,
        money_monsters_count = EXCLUDED.money_monsters_count,
        aibitbots_count = EXCLUDED.aibitbots_count,
        money_monsters_3d_count = EXCLUDED.money_monsters_3d_count,
        celeb_catz_count = EXCLUDED.celeb_catz_count,
        total_count = EXCLUDED.total_count,
        last_updated = CURRENT_TIMESTAMP;
    
    -- Get debug info
    SELECT INTO debug_info
        format('Updated counts for %s: FCKED=%s, MM=%s, AIBB=%s, MM3D=%s, CELEB=%s, Total=%s',
            COALESCE(NEW.owner_wallet, OLD.owner_wallet),
            (SELECT fcked_catz_count FROM collection_counts WHERE wallet_address = COALESCE(NEW.owner_wallet, OLD.owner_wallet)),
            (SELECT money_monsters_count FROM collection_counts WHERE wallet_address = COALESCE(NEW.owner_wallet, OLD.owner_wallet)),
            (SELECT aibitbots_count FROM collection_counts WHERE wallet_address = COALESCE(NEW.owner_wallet, OLD.owner_wallet)),
            (SELECT money_monsters_3d_count FROM collection_counts WHERE wallet_address = COALESCE(NEW.owner_wallet, OLD.owner_wallet)),
            (SELECT celeb_catz_count FROM collection_counts WHERE wallet_address = COALESCE(NEW.owner_wallet, OLD.owner_wallet)),
            (SELECT total_count FROM collection_counts WHERE wallet_address = COALESCE(NEW.owner_wallet, OLD.owner_wallet))
        );
    
    RAISE NOTICE '%', debug_info;
    
    RETURN NEW;
END;
$$;


--
-- TOC entry 235 (class 1255 OID 16488)
-- Name: calculate_initial_daily_rewards(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calculate_initial_daily_rewards() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    collection_counts RECORD;
    total_reward INTEGER := 0;
BEGIN
    -- Get collection counts for the user
    SELECT
        COUNT(CASE WHEN symbol = 'CelebCatz' THEN 1 END) as celeb_catz_count,
        COUNT(CASE WHEN symbol = 'MM3D' THEN 1 END) as money_monsters_3d_count,
        COUNT(CASE WHEN symbol = 'FCKEDCATZ' THEN 1 END) as fcked_catz_count,
        COUNT(CASE WHEN symbol = 'MM' THEN 1 END) as money_monsters_count,
        COUNT(CASE WHEN symbol = 'AIBB' THEN 1 END) as aibitbots_count,
        COUNT(CASE WHEN is_collab = true THEN 1 END) as ai_collabs_count,
        COUNT(*) as total_count
    INTO collection_counts
    FROM nft_metadata
    WHERE owner_wallet = NEW.wallet_address
    AND is_listed = false;

    -- Calculate rewards based on collection counts
    INSERT INTO daily_rewards (
        discord_id,
        calculation_time,
        reward_period_start,
        reward_period_end,
        celeb_catz_count,
        celeb_catz_reward,
        money_monsters_3d_count,
        money_monsters_3d_reward,
        fcked_catz_count,
        fcked_catz_reward,
        money_monsters_count,
        money_monsters_reward,
        aibitbots_count,
        aibitbots_reward,
        ai_collabs_count,
        ai_collabs_reward,
        total_nft_count,
        total_daily_reward,
        is_processed,
        discord_name
    )
    SELECT
        NEW.discord_id,
        CURRENT_TIMESTAMP,
        date_trunc('day', CURRENT_TIMESTAMP),
        date_trunc('day', CURRENT_TIMESTAMP + interval '1 day'),
        collection_counts.celeb_catz_count,
        collection_counts.celeb_catz_count * 20,
        collection_counts.money_monsters_3d_count,
        collection_counts.money_monsters_3d_count * 7,
        collection_counts.fcked_catz_count,
        collection_counts.fcked_catz_count * 5,
        collection_counts.money_monsters_count,
        collection_counts.money_monsters_count * 5,
        collection_counts.aibitbots_count,
        collection_counts.aibitbots_count * 3,
        collection_counts.ai_collabs_count,
        collection_counts.ai_collabs_count * 1,
        collection_counts.total_count,
        (collection_counts.celeb_catz_count * 20) +
        (collection_counts.money_monsters_3d_count * 7) +
        (collection_counts.fcked_catz_count * 5) +
        (collection_counts.money_monsters_count * 5) +
        (collection_counts.aibitbots_count * 3) +
        (collection_counts.ai_collabs_count * 1),
        false,
        (SELECT discord_name FROM user_roles WHERE discord_id = NEW.discord_id)
    ON CONFLICT (discord_id, reward_period_start) DO NOTHING;

    RETURN NEW;
END;
$$;


--
-- TOC entry 236 (class 1255 OID 16489)
-- Name: create_missing_reward_entries(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_missing_reward_entries() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    member RECORD;
BEGIN
    -- Loop through claim_accounts that don't have daily_rewards entries
    FOR member IN
        SELECT ca.*
        FROM claim_accounts ca
        LEFT JOIN daily_rewards_new dr ON ca.discord_id = dr.discord_id
        WHERE dr.discord_id IS NULL
    LOOP
        -- Use the same calculation logic as the trigger
        INSERT INTO daily_rewards_new (
            discord_id,
            discord_name,
            celeb_catz_reward,
            money_monsters_3d_reward,
            fcked_catz_reward,
            money_monsters_reward,
            aibitbots_reward,
            ai_collabs_reward,
            money_monsters_top_10_reward,
            money_monsters_3d_top_10_reward,
            branded_catz_reward,
            total_daily_reward,
            is_processed
        )
        SELECT
            member.discord_id,
            (SELECT discord_name FROM user_roles WHERE discord_id = member.discord_id),
            COUNT(CASE WHEN symbol = 'CelebCatz' THEN 1 END) * 20,
            COUNT(CASE WHEN symbol = 'MM3D' THEN 1 END) * 7,
            COUNT(CASE WHEN symbol = 'FCKEDCATZ' THEN 1 END) * 5,
            COUNT(CASE WHEN symbol = 'MM' THEN 1 END) * 5,
            COUNT(CASE WHEN symbol = 'AIBB' THEN 1 END) * 3,
            COUNT(CASE WHEN is_collab = true THEN 1 END) * 1,
            COUNT(CASE WHEN symbol = 'MM' AND rarity_rank <= 10 THEN 1 END) * 5,
            COUNT(CASE WHEN symbol = 'MM3D' AND rarity_rank <= 10 THEN 1 END) * 7,
            COUNT(CASE WHEN is_branded_cat = true THEN 1 END) * 5,
            (COUNT(CASE WHEN symbol = 'CelebCatz' THEN 1 END) * 20) +
            (COUNT(CASE WHEN symbol = 'MM3D' THEN 1 END) * 7) +
            (COUNT(CASE WHEN symbol = 'FCKEDCATZ' THEN 1 END) * 5) +
            (COUNT(CASE WHEN symbol = 'MM' THEN 1 END) * 5) +
            (COUNT(CASE WHEN symbol = 'AIBB' THEN 1 END) * 3) +
            (COUNT(CASE WHEN is_collab = true THEN 1 END) * 1) +
            (COUNT(CASE WHEN symbol = 'MM' AND rarity_rank <= 10 THEN 1 END) * 5) +
            (COUNT(CASE WHEN symbol = 'MM3D' AND rarity_rank <= 10 THEN 1 END) * 7) +
            (COUNT(CASE WHEN is_branded_cat = true THEN 1 END) * 5),
            false
        FROM nft_metadata
        WHERE owner_wallet = member.wallet_address
        AND is_listed = false
        GROUP BY member.discord_id;
    END LOOP;
END;
$$;


--
-- TOC entry 252 (class 1255 OID 16490)
-- Name: create_user_on_wallet_connect(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_user_on_wallet_connect() RETURNS trigger
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


--
-- TOC entry 248 (class 1255 OID 16491)
-- Name: fix_buxdao5_role(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fix_buxdao5_role() RETURNS void
    LANGUAGE plpgsql
    AS $$ DECLARE user_record RECORD; role_record RECORD; BEGIN FOR user_record IN SELECT * FROM user_roles WHERE buxdao_5 = true LOOP SELECT * INTO role_record FROM roles WHERE name = 'BUXDAO 5'; UPDATE user_roles SET roles = COALESCE((SELECT jsonb_agg(value) FROM jsonb_array_elements(roles) WHERE value->>'name' != 'BUXDAO 5'), '[]'::jsonb) || jsonb_build_object('id', role_record.discord_role_id, 'name', role_record.name, 'type', role_record.type, 'collection', role_record.collection, 'color', role_record.color, 'emoji_url', role_record.emoji_url, 'display_name', role_record.display_name) WHERE discord_id = user_record.discord_id; END LOOP; END; $$;


--
-- TOC entry 249 (class 1255 OID 16492)
-- Name: get_user_roles(character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_user_roles(p_discord_id character varying) RETURNS TABLE(roles jsonb, holdings jsonb)
    LANGUAGE plpgsql
    AS $$ DECLARE user_data record; BEGIN SELECT * INTO user_data FROM user_roles WHERE discord_id = p_discord_id; IF NOT FOUND THEN RETURN QUERY SELECT '[]'::jsonb as roles, '{}'::jsonb as holdings; RETURN; END IF; RETURN QUERY SELECT COALESCE(user_data.roles, '[]'::jsonb) as roles, jsonb_build_object('fckedCatz', user_data.fcked_catz_holder, 'moneyMonsters', user_data.money_monsters_holder, 'aiBitbots', user_data.ai_bitbots_holder, 'moneyMonsters3d', user_data.moneymonsters3d_holder, 'celebCatz', user_data.celebcatz_holder) as holdings; END; $$;


--
-- TOC entry 250 (class 1255 OID 16493)
-- Name: get_user_roles_and_holdings(character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_user_roles_and_holdings(p_discord_id character varying) RETURNS TABLE(roles jsonb, holdings jsonb)
    LANGUAGE plpgsql
    AS $$ BEGIN RETURN QUERY SELECT COALESCE(v.roles, '[]'::jsonb), COALESCE(v.holdings, '{}'::jsonb) FROM user_roles_view v WHERE v.discord_id = p_discord_id; END; $$;


--
-- TOC entry 264 (class 1255 OID 16494)
-- Name: insert_bux_holder_on_new_wallet(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.insert_bux_holder_on_new_wallet() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  UPDATE token_holders
  SET owner_discord_id = NEW.discord_id,
      owner_name = NEW.discord_name,
      last_updated = NOW()
  WHERE wallet_address = NEW.wallet_address
    AND (owner_discord_id IS NULL OR owner_discord_id = '');
  RETURN NEW;
END;
$$;


--
-- TOC entry 251 (class 1255 OID 16495)
-- Name: log_nft_ownership_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.log_nft_ownership_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.owner_wallet IS DISTINCT FROM OLD.owner_wallet THEN
        INSERT INTO nft_events (mint_address, old_owner, new_owner)
        VALUES (NEW.mint_address, OLD.owner_wallet, NEW.owner_wallet);
    END IF;
    RETURN NEW;
END;
$$;


--
-- TOC entry 253 (class 1255 OID 16497)
-- Name: manage_buxdao5_role(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.manage_buxdao5_role() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE buxdao5_role_id text; role_obj jsonb; role_data record; BEGIN RAISE NOTICE 'Starting manage_buxdao5_role for user: %', NEW.discord_id; SELECT * INTO role_data FROM roles WHERE name = 'BUXDAO 5'; RAISE NOTICE 'Found BUXDAO 5 role data: %', role_data; IF NEW.fcked_catz_holder = true AND NEW.money_monsters_holder = true AND NEW.ai_bitbots_holder = true AND NEW.moneymonsters3d_holder = true AND NEW.celebcatz_holder = true THEN NEW.buxdao_5 = true; IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(NEW.roles) WHERE (value->>'id') = role_data.discord_role_id) THEN role_obj = jsonb_build_object('id', role_data.discord_role_id, 'name', role_data.name, 'type', role_data.type, 'collection', role_data.collection, 'display_name', role_data.display_name, 'color', role_data.color, 'emoji_url', role_data.emoji_url); RAISE NOTICE 'Adding BUXDAO 5 role: %', role_obj; NEW.roles = NEW.roles || role_obj; RAISE NOTICE 'Updated roles array: %', NEW.roles; END IF; ELSE NEW.buxdao_5 = false; NEW.roles = (SELECT jsonb_agg(value) FROM jsonb_array_elements(NEW.roles) WHERE (value->>'id') != role_data.discord_role_id); RAISE NOTICE 'Removed BUXDAO 5 role, updated roles array: %', NEW.roles; END IF; RAISE NOTICE 'Finished manage_buxdao5_role for user: %', NEW.discord_id; RETURN NEW; END; $$;


--
-- TOC entry 254 (class 1255 OID 16498)
-- Name: manage_roles_array(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.manage_roles_array() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$ 
DECLARE 
  roles_array jsonb := '[]'::jsonb;
  top_10_status RECORD;
BEGIN
  -- Get top 10 status from collection_counts
  SELECT money_monsters_top_10, money_monsters_3d_top_10 INTO top_10_status
  FROM collection_counts 
  WHERE discord_id = NEW.discord_id;

  -- 1. Token roles (BUX)
  IF NEW.bux_beginner THEN 
    roles_array = roles_array || jsonb_build_object('id', '1095363984581984357', 'name', 'BUX Beginner', 'type', 'token', 'color', '#daff00', 'emoji_url', '/emojis/BUX.webp', 'collection', 'bux', 'display_name', 'BUX BEGINNER');
  END IF;
  
  IF NEW.bux_builder THEN 
    roles_array = roles_array || jsonb_build_object('id', '1095363984581984357', 'name', 'BUX Builder', 'type', 'token', 'color', '#daff00', 'emoji_url', '/emojis/BUX.webp', 'collection', 'bux', 'display_name', 'BUX BUILDER');
  END IF;
  
  IF NEW.bux_saver THEN 
    roles_array = roles_array || jsonb_build_object('id', '1095363984581984357', 'name', 'BUX Saver', 'type', 'token', 'color', '#daff00', 'emoji_url', '/emojis/BUX.webp', 'collection', 'bux', 'display_name', 'BUX SAVER');
  END IF;
  
  IF NEW.bux_banker THEN 
    roles_array = roles_array || jsonb_build_object('id', '1095363984581984357', 'name', 'BUX Banker', 'type', 'token', 'color', '#daff00', 'emoji_url', '/emojis/BUX.webp', 'collection', 'bux', 'display_name', 'BUX BANKER');
  END IF;

  -- 2. Whale roles
  IF NEW.fcked_catz_whale THEN 
    roles_array = roles_array || jsonb_build_object('id', '1093606438674382858', 'name', 'FCKed Catz Whale', 'type', 'whale', 'color', '#7294ab', 'emoji_url', '/emojis/CAT 🐋.webp', 'collection', 'fcked_catz', 'display_name', 'CAT 🐋');
  END IF;
  
  IF NEW.money_monsters_whale THEN 
    roles_array = roles_array || jsonb_build_object('id', '1093606438674382858', 'name', 'Money Monsters Whale', 'type', 'whale', 'color', '#7294ab', 'emoji_url', '/emojis/MONSTER 🐋.webp', 'collection', 'money_monsters', 'display_name', 'MONSTER 🐋');
  END IF;
  
  IF NEW.moneymonsters3d_whale THEN 
    roles_array = roles_array || jsonb_build_object('id', '1093606579355525252', 'name', 'Money Monsters 3D Whale', 'type', 'whale', 'color', '#52b4f3', 'emoji_url', '/emojis/MONSTER 3D 🐋.webp', 'collection', 'moneymonsters3d', 'display_name', 'MONSTER 3D 🐋');
  END IF;
  
  IF NEW.ai_bitbots_whale THEN 
    roles_array = roles_array || jsonb_build_object('id', '1095033899492573274', 'name', 'AI BitBots Whale', 'type', 'whale', 'color', '#e1f2a1', 'emoji_url', '/emojis/MEGA BOT 🐋.webp', 'collection', 'ai_bitbots', 'display_name', 'MEGA BOT 🐋');
  END IF;

  -- 3. Main collection holder roles
  IF NEW.fcked_catz_holder THEN 
    roles_array = roles_array || jsonb_build_object('id', '1095033759612547133', 'name', 'FCKed Catz Holder', 'type', 'holder', 'color', '#7e6ff7', 'emoji_url', '/emojis/CAT.webp', 'collection', 'fcked_catz', 'display_name', 'CAT');
  END IF;
  
  IF NEW.money_monsters_holder THEN 
    roles_array = roles_array || jsonb_build_object('id', '1093607056696692828', 'name', 'Money Monsters Holder', 'type', 'holder', 'color', '#fc7c7c', 'emoji_url', '/emojis/MONSTER.webp', 'collection', 'money_monsters', 'display_name', 'MONSTER');
  END IF;
  
  IF NEW.ai_bitbots_holder THEN 
    roles_array = roles_array || jsonb_build_object('id', '1095034117877399686', 'name', 'AI BitBots Holder', 'type', 'holder', 'color', '#097e67', 'emoji_url', '/emojis/BITBOT.webp', 'collection', 'ai_bitbots', 'display_name', 'BITBOT');
  END IF;
  
  IF NEW.moneymonsters3d_holder THEN 
    roles_array = roles_array || jsonb_build_object('id', '1093607187454111825', 'name', 'Money Monsters 3D Holder', 'type', 'holder', 'color', '#ff0000', 'emoji_url', '/emojis/MONSTER 3D.webp', 'collection', 'moneymonsters3d', 'display_name', 'MONSTER 3D');
  END IF;
  
  IF NEW.celebcatz_holder THEN 
    roles_array = roles_array || jsonb_build_object('id', '1095335098112561234', 'name', 'Celebrity Catz Holder', 'type', 'holder', 'color', '#5dffd8', 'emoji_url', '/emojis/CELEB.webp', 'collection', 'celebcatz', 'display_name', 'CELEB');
  END IF;

  -- Top 10 roles based on collection_counts (part of main collection roles)
  IF top_10_status.money_monsters_top_10 > 0 THEN 
    roles_array = roles_array || jsonb_build_object('id', '1095338675224707103', 'name', 'Money Monsters Top 10', 'type', 'holder', 'color', '#48a350', 'emoji_url', '/emojis/MMTOP10.webp', 'collection', 'money_monsters', 'display_name', 'MM TOP 10');
  END IF;

  IF top_10_status.money_monsters_3d_top_10 > 0 THEN 
    roles_array = roles_array || jsonb_build_object('id', '1095338840178294795', 'name', 'Money Monsters 3D Top 10', 'type', 'holder', 'color', '#6ad1a0', 'emoji_url', '/emojis/MM3DTOP10.webp', 'collection', 'moneymonsters3d', 'display_name', 'MM3D TOP 10');
  END IF;

  -- 4. BUXDAO 5 role
  IF NEW.buxdao_5 THEN 
    roles_array = roles_array || jsonb_build_object('id', '1248428373487784006', 'name', 'BUXDAO 5', 'type', 'special', 'color', '#00be22', 'emoji_url', '/emojis/BUX.webp', 'collection', 'all', 'display_name', 'BUX$DAO 5');
  END IF;

  -- 5. Collaboration collection roles
  IF NEW.shxbb_holder THEN 
    roles_array = roles_array || jsonb_build_object('id', '16661', 'name', 'A.I. Warriors Holder', 'type', 'collab', 'color', '#bbbaba', 'emoji_url', '/emojis/globe.svg', 'collection', 'shxbb', 'display_name', 'AI warrior');
  END IF;

  IF NEW.ausqrl_holder THEN 
    roles_array = roles_array || jsonb_build_object('id', '16662', 'name', 'A.I. Squirrels Holder', 'type', 'collab', 'color', '#bbbaba', 'emoji_url', '/emojis/globe.svg', 'collection', 'ausqrl', 'display_name', 'AI squirrel');
  END IF;

  IF NEW.aelxaibb_holder THEN 
    roles_array = roles_array || jsonb_build_object('id', '16663', 'name', 'A.I. Energy Apes', 'type', 'collab', 'color', '#bbbaba', 'emoji_url', '/emojis/globe.svg', 'collection', 'aelxaibb', 'display_name', 'AI energy ape');
  END IF;

  IF NEW.airb_holder THEN 
    roles_array = roles_array || jsonb_build_object('id', '16664', 'name', 'Rejected Bots Holder', 'type', 'collab', 'color', '#bbbaba', 'emoji_url', '/emojis/globe.svg', 'collection', 'airb', 'display_name', 'Rjctd bot');
  END IF;

  IF NEW.clb_holder THEN 
    roles_array = roles_array || jsonb_build_object('id', '16665', 'name', 'Candy Bot Holder', 'type', 'collab', 'color', '#bbbaba', 'emoji_url', '/emojis/globe.svg', 'collection', 'clb', 'display_name', 'Candy bot');
  END IF;

  IF NEW.ddbot_holder THEN 
    roles_array = roles_array || jsonb_build_object('id', '16666', 'name', 'Doodle Bot Holder', 'type', 'collab', 'color', '#bbbaba', 'emoji_url', '/emojis/globe.svg', 'collection', 'ddbot', 'display_name', 'Doodle bot');
  END IF;

  NEW.roles = roles_array;
  RETURN NEW;
END;
$_$;


--
-- TOC entry 255 (class 1255 OID 16499)
-- Name: manage_whale_roles(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.manage_whale_roles() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  whale_role record;
  role_obj jsonb;
  nft_counts record;
BEGIN
  RAISE NOTICE 'Starting manage_whale_roles for wallet: %', NEW.wallet_address;

  -- Get NFT counts from collection_counts
  SELECT 
    COALESCE(fcked_catz_count, 0) as fcked_catz_count,
    COALESCE(money_monsters_count, 0) as money_monsters_count,
    COALESCE(aibitbots_count, 0) as aibitbots_count,
    COALESCE(money_monsters_3d_count, 0) as money_monsters_3d_count
  INTO nft_counts
  FROM collection_counts
  WHERE wallet_address = NEW.wallet_address;

  RAISE NOTICE 'NFT counts: %', nft_counts;

  -- Initialize nft_counts if no record found
  IF nft_counts IS NULL THEN
    RAISE NOTICE 'No NFT counts found, initializing to zeros';
    SELECT 
      0 as fcked_catz_count,
      0 as money_monsters_count,
      0 as aibitbots_count,
      0 as money_monsters_3d_count
    INTO nft_counts;
  END IF;

  -- AI BitBots Whale
  IF nft_counts.aibitbots_count >= 10 THEN
    RAISE NOTICE 'Adding AI BitBots Whale role';
    SELECT * INTO whale_role FROM roles WHERE type = 'whale' AND collection = 'ai_bitbots';
    NEW.ai_bitbots_whale := true;
    
    IF whale_role IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(NEW.roles) WHERE (value->>'id') = whale_role.discord_role_id
    ) THEN
      role_obj := jsonb_build_object(
        'id', whale_role.discord_role_id,
        'name', whale_role.name,
        'type', whale_role.type,
        'collection', whale_role.collection,
        'display_name', whale_role.display_name,
        'color', whale_role.color,
        'emoji_url', whale_role.emoji_url
      );
      NEW.roles := NEW.roles || role_obj;
      RAISE NOTICE 'Added AI BitBots Whale role: %', role_obj;
    END IF;
  ELSIF nft_counts.aibitbots_count < 10 AND NEW.ai_bitbots_whale THEN
    RAISE NOTICE 'Removing AI BitBots Whale role';
    NEW.ai_bitbots_whale := false;
    SELECT discord_role_id INTO whale_role FROM roles WHERE type = 'whale' AND collection = 'ai_bitbots';
    IF whale_role IS NOT NULL THEN
      NEW.roles := (
        SELECT jsonb_agg(value)
        FROM jsonb_array_elements(NEW.roles)
        WHERE (value->>'id') != whale_role.discord_role_id
      );
    END IF;
  END IF;

  -- Money Monsters Whale
  IF nft_counts.money_monsters_count >= 25 THEN
    RAISE NOTICE 'Adding Money Monsters Whale role';
    SELECT * INTO whale_role FROM roles WHERE type = 'whale' AND collection = 'money_monsters';
    NEW.money_monsters_whale := true;
    
    IF whale_role IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(NEW.roles) WHERE (value->>'id') = whale_role.discord_role_id
    ) THEN
      role_obj := jsonb_build_object(
        'id', whale_role.discord_role_id,
        'name', whale_role.name,
        'type', whale_role.type,
        'collection', whale_role.collection,
        'display_name', whale_role.display_name,
        'color', whale_role.color,
        'emoji_url', whale_role.emoji_url
      );
      NEW.roles := NEW.roles || role_obj;
      RAISE NOTICE 'Added Money Monsters Whale role: %', role_obj;
    END IF;
  ELSIF nft_counts.money_monsters_count < 25 AND NEW.money_monsters_whale THEN
    RAISE NOTICE 'Removing Money Monsters Whale role';
    NEW.money_monsters_whale := false;
    SELECT discord_role_id INTO whale_role FROM roles WHERE type = 'whale' AND collection = 'money_monsters';
    IF whale_role IS NOT NULL THEN
      NEW.roles := (
        SELECT jsonb_agg(value)
        FROM jsonb_array_elements(NEW.roles)
        WHERE (value->>'id') != whale_role.discord_role_id
      );
    END IF;
  END IF;

  -- Money Monsters 3D Whale
  IF nft_counts.money_monsters_3d_count >= 25 THEN
    RAISE NOTICE 'Adding Money Monsters 3D Whale role';
    SELECT * INTO whale_role FROM roles WHERE type = 'whale' AND collection = 'moneymonsters3d';
    NEW.moneymonsters3d_whale := true;
    
    IF whale_role IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(NEW.roles) WHERE (value->>'id') = whale_role.discord_role_id
    ) THEN
      role_obj := jsonb_build_object(
        'id', whale_role.discord_role_id,
        'name', whale_role.name,
        'type', whale_role.type,
        'collection', whale_role.collection,
        'display_name', whale_role.display_name,
        'color', whale_role.color,
        'emoji_url', whale_role.emoji_url
      );
      NEW.roles := NEW.roles || role_obj;
      RAISE NOTICE 'Added Money Monsters 3D Whale role: %', role_obj;
    END IF;
  ELSIF nft_counts.money_monsters_3d_count < 25 AND NEW.moneymonsters3d_whale THEN
    RAISE NOTICE 'Removing Money Monsters 3D Whale role';
    NEW.moneymonsters3d_whale := false;
    SELECT discord_role_id INTO whale_role FROM roles WHERE type = 'whale' AND collection = 'moneymonsters3d';
    IF whale_role IS NOT NULL THEN
      NEW.roles := (
        SELECT jsonb_agg(value)
        FROM jsonb_array_elements(NEW.roles)
        WHERE (value->>'id') != whale_role.discord_role_id
      );
    END IF;
  END IF;

  -- Fcked Catz Whale
  IF nft_counts.fcked_catz_count >= 25 THEN
    RAISE NOTICE 'Adding FCKed Catz Whale role';
    SELECT * INTO whale_role FROM roles WHERE type = 'whale' AND collection = 'fcked_catz';
    NEW.fcked_catz_whale := true;
    
    IF whale_role IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(NEW.roles) WHERE (value->>'id') = whale_role.discord_role_id
    ) THEN
      role_obj := jsonb_build_object(
        'id', whale_role.discord_role_id,
        'name', whale_role.name,
        'type', whale_role.type,
        'collection', whale_role.collection,
        'display_name', whale_role.display_name,
        'color', whale_role.color,
        'emoji_url', whale_role.emoji_url
      );
      NEW.roles := NEW.roles || role_obj;
      RAISE NOTICE 'Added FCKed Catz Whale role: %', role_obj;
    END IF;
  ELSIF nft_counts.fcked_catz_count < 25 AND NEW.fcked_catz_whale THEN
    RAISE NOTICE 'Removing FCKed Catz Whale role';
    NEW.fcked_catz_whale := false;
    SELECT discord_role_id INTO whale_role FROM roles WHERE type = 'whale' AND collection = 'fcked_catz';
    IF whale_role IS NOT NULL THEN
      NEW.roles := (
        SELECT jsonb_agg(value)
        FROM jsonb_array_elements(NEW.roles)
        WHERE (value->>'id') != whale_role.discord_role_id
      );
    END IF;
  END IF;

  RAISE NOTICE 'Finished manage_whale_roles for wallet: %', NEW.wallet_address;
  RETURN NEW;
END;
$$;


--
-- TOC entry 256 (class 1255 OID 16500)
-- Name: notify_role_changes(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_role_changes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Only notify if roles array has changed
  IF OLD.roles IS DISTINCT FROM NEW.roles THEN
    -- Call the sync endpoint
    PERFORM pg_notify('role_changes', json_build_object(
      'discord_id', NEW.discord_id,
      'event', 'role_update'
    )::text);
  END IF;
  RETURN NEW;
END;
$$;


--
-- TOC entry 257 (class 1255 OID 16501)
-- Name: process_daily_rewards(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.process_daily_rewards() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Update unclaimed_amount in claim_accounts
    UPDATE claim_accounts ca
    SET unclaimed_amount = ca.unclaimed_amount + dr.total_daily_reward
    FROM daily_rewards_new dr
    WHERE ca.discord_id = dr.discord_id
    AND dr.is_processed = false;

    -- Mark the processed rewards
    UPDATE daily_rewards_new
    SET is_processed = true
    WHERE is_processed = false;

    RETURN NEW;
END;
$$;


--
-- TOC entry 258 (class 1255 OID 16502)
-- Name: process_pending_rewards(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.process_pending_rewards() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN 
    UPDATE claim_accounts ca 
    SET unclaimed_amount = ca.unclaimed_amount + dr.total_daily_reward 
    FROM daily_rewards_new dr 
    WHERE ca.discord_id = dr.discord_id; 
    
    UPDATE daily_rewards_new 
    SET is_processed = true; 
END;
$$;


--
-- TOC entry 259 (class 1255 OID 16503)
-- Name: rebuild_all_roles(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rebuild_all_roles() RETURNS void
    LANGUAGE plpgsql
    AS $$ DECLARE user_record RECORD; BEGIN FOR user_record IN SELECT * FROM user_roles LOOP WITH user_roles_data AS (SELECT r.* FROM roles r WHERE (r.name = 'BUXDAO 5' AND user_record.buxdao_5 = true) OR (r.type = 'holder' AND EXISTS (SELECT 1 FROM nft_metadata WHERE owner_wallet = user_record.wallet_address AND symbol = CASE r.collection WHEN 'fcked_catz' THEN 'FCKEDCATZ' WHEN 'money_monsters' THEN 'MM' WHEN 'moneymonsters3d' THEN 'MM3D' WHEN 'ai_bitbots' THEN 'AIBB' WHEN 'celebcatz' THEN 'CelebCatz' END)) OR (r.type = 'whale' AND EXISTS (SELECT 1 FROM nft_metadata WHERE owner_wallet = user_record.wallet_address AND symbol = CASE r.collection WHEN 'fcked_catz' THEN 'FCKEDCATZ' WHEN 'money_monsters' THEN 'MM' WHEN 'moneymonsters3d' THEN 'MM3D' WHEN 'ai_bitbots' THEN 'AIBB' END GROUP BY symbol HAVING COUNT(*) >= CASE r.collection WHEN 'ai_bitbots' THEN 10 ELSE 25 END)) OR (r.type = 'token' AND EXISTS (SELECT 1 FROM bux_holders bh WHERE bh.wallet_address = user_record.wallet_address AND CASE r.name WHEN 'BUX Beginner' THEN bh.balance BETWEEN 2500 AND 9999 WHEN 'BUX Builder' THEN bh.balance BETWEEN 10000 AND 24999 WHEN 'BUX Saver' THEN bh.balance BETWEEN 25000 AND 49999 WHEN 'BUX Banker' THEN bh.balance >= 50000 END))) UPDATE user_roles SET roles = (SELECT jsonb_agg(jsonb_build_object('id', discord_role_id, 'name', name, 'type', type, 'collection', collection, 'color', color, 'emoji_url', emoji_url, 'display_name', display_name)) FROM user_roles_data) WHERE discord_id = user_record.discord_id; END LOOP; END; $$;


--
-- TOC entry 276 (class 1255 OID 254197)
-- Name: rebuild_roles_on_collection_counts_update(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rebuild_roles_on_collection_counts_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- TOC entry 277 (class 1255 OID 16504)
-- Name: rebuild_user_roles(character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rebuild_user_roles(p_discord_id character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
    LEFT JOIN counts c ON r.collection = 'CNSZ'
    LEFT JOIN token_balance tb ON true
    LEFT JOIN user_role_flags urf ON true
    WHERE r.collection = 'CNSZ'
      AND (
        -- Holder roles based on collection_counts
        (r.type = 'holder' AND (
          (r.name='potter_any' AND c.total_count >= COALESCE(r.threshold,1)) OR
          (r.name='holder_gold' AND c.gold_count >= COALESCE(r.threshold,1)) OR
          (r.name='holder_silver' AND c.silver_count >= COALESCE(r.threshold,1)) OR
          (r.name='holder_purple' AND c.purple_count >= COALESCE(r.threshold,1)) OR
          (r.name='holder_dark_green' AND c.dark_green_count >= COALESCE(r.threshold,1)) OR
          (r.name='holder_light_green' AND c.light_green_count >= COALESCE(r.threshold,1)) OR
          (r.name='og420' AND c.og420_count >= COALESCE(r.threshold,1))
        )) OR
        -- Token roles based on token_holders balance
        (r.type = 'token' AND tb.total_balance >= COALESCE(r.threshold, 0)) OR
        -- COLLECTOR role: has 1+ of each of the 5 colors (gold, silver, purple, dark_green, light_green)
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
$$;


--
-- TOC entry 272 (class 1255 OID 106512)
-- Name: refresh_counts_on_metadata(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_counts_on_metadata() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  PERFORM update_collection_counts(NEW.owner_discord_id);
  RETURN NEW;
END;
$$;


--
-- TOC entry 260 (class 1255 OID 16505)
-- Name: sync_claim_account_discord_name(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_claim_account_discord_name() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
   BEGIN
     NEW.discord_name := (SELECT discord_name FROM user_roles WHERE discord_id = NEW.discord_id);
     RETURN NEW;
   END;
   $$;


--
-- TOC entry 261 (class 1255 OID 16506)
-- Name: sync_daily_rewards(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_daily_rewards() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Insert or update daily rewards for all users
    INSERT INTO daily_rewards_new (
        discord_name,
        discord_id,
        celeb_catz_reward,
        money_monsters_3d_reward,
        fcked_catz_reward,
        money_monsters_reward,
        aibitbots_reward,
        ai_collabs_reward,
        money_monsters_top_10_reward,
        money_monsters_3d_top_10_reward,
        branded_catz_reward,
        total_daily_reward
    )
    SELECT
        ur.discord_name,
        cc.discord_id,
        cc.celeb_catz_count * 20,
        cc.money_monsters_3d_count * 7,
        cc.fcked_catz_count * 5,
        cc.money_monsters_count * 5,
        cc.aibitbots_count * 3,
        cc.ai_collabs_count * 1,
        cc.money_monsters_top_10 * 5,
        cc.money_monsters_3d_top_10 * 7,
        cc.branded_catz_count * 5,
        (cc.celeb_catz_count * 20) +
        (cc.money_monsters_3d_count * 7) +
        (cc.fcked_catz_count * 5) +
        (cc.money_monsters_count * 5) +
        (cc.aibitbots_count * 3) +
        (cc.ai_collabs_count * 1) +
        (cc.money_monsters_top_10 * 5) +
        (cc.money_monsters_3d_top_10 * 7) +
        (cc.branded_catz_count * 5)
    FROM collection_counts cc
    JOIN user_roles ur ON cc.discord_id = ur.discord_id
    WHERE cc.discord_id IS NOT NULL
    ON CONFLICT (discord_id)
    DO UPDATE SET
        discord_name = EXCLUDED.discord_name,
        celeb_catz_reward = EXCLUDED.celeb_catz_reward,
        money_monsters_3d_reward = EXCLUDED.money_monsters_3d_reward,
        fcked_catz_reward = EXCLUDED.fcked_catz_reward,
        money_monsters_reward = EXCLUDED.money_monsters_reward,
        aibitbots_reward = EXCLUDED.aibitbots_reward,
        ai_collabs_reward = EXCLUDED.ai_collabs_reward,
        money_monsters_top_10_reward = EXCLUDED.money_monsters_top_10_reward,
        money_monsters_3d_top_10_reward = EXCLUDED.money_monsters_3d_top_10_reward,
        branded_catz_reward = EXCLUDED.branded_catz_reward,
        total_daily_reward = EXCLUDED.total_daily_reward;

    -- Create claim accounts for users who don't have one
    INSERT INTO claim_accounts (discord_id, wallet_address)
    SELECT
        ur.discord_id,
        ur.wallet_address
    FROM user_roles ur
    LEFT JOIN claim_accounts ca ON ur.discord_id = ca.discord_id 
    WHERE ca.discord_id IS NULL
    AND ur.wallet_address IS NOT NULL;
END;
$$;


--
-- TOC entry 262 (class 1255 OID 16507)
-- Name: sync_username(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_username() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN UPDATE bux_holders SET owner_name = NEW.discord_name WHERE wallet_address = NEW.wallet_address; UPDATE collection_counts SET discord_name = NEW.discord_name WHERE wallet_address = NEW.wallet_address; RETURN NEW; END; $$;


--
-- TOC entry 274 (class 1255 OID 245766)
-- Name: trg_update_daily_rewards(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_update_daily_rewards() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  PERFORM update_daily_rewards_from_collection_counts();
  RETURN NEW;
END;
$$;


--
-- TOC entry 273 (class 1255 OID 106509)
-- Name: update_collection_counts(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_collection_counts(p_discord_id text) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO collection_counts (
    discord_id, discord_name,
    gold_count, silver_count, purple_count, dark_green_count, light_green_count,
    og420_count, total_count, last_updated
  )
  SELECT
    p_discord_id,
    MAX(owner_name),
    COUNT(*) FILTER (WHERE leaf_colour = 'Gold')        AS gold_count,
    COUNT(*) FILTER (WHERE leaf_colour = 'Silver')      AS silver_count,
    COUNT(*) FILTER (WHERE leaf_colour = 'Purple')      AS purple_count,
    COUNT(*) FILTER (WHERE leaf_colour = 'Dark green')  AS dark_green_count,
    COUNT(*) FILTER (WHERE leaf_colour = 'Light green') AS light_green_count,
    COUNT(*) FILTER (WHERE og420 = TRUE)                AS og420_count,
    COUNT(*) AS total_count,
    NOW() AS last_updated
  FROM nft_metadata
  WHERE owner_discord_id = p_discord_id
  GROUP BY owner_discord_id
  ON CONFLICT (discord_id) DO UPDATE SET
    discord_name = EXCLUDED.discord_name,
    gold_count = EXCLUDED.gold_count,
    silver_count = EXCLUDED.silver_count,
    purple_count = EXCLUDED.purple_count,
    dark_green_count = EXCLUDED.dark_green_count,
    light_green_count = EXCLUDED.light_green_count,
    og420_count = EXCLUDED.og420_count,
    total_count = EXCLUDED.total_count,
    last_updated = NOW();
END;
$$;


--
-- TOC entry 275 (class 1255 OID 245765)
-- Name: update_daily_rewards_from_collection_counts(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_daily_rewards_from_collection_counts() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Daily yield rates per NFT
  INSERT INTO daily_rewards (discord_id, discord_name, total_daily_reward, is_processed)
  SELECT
    cc.discord_id,
    cc.discord_name,
    -- Calculate total daily reward based on NFT counts and yield rates
    (COALESCE(cc.og420_count, 0) * 20) +      -- OG420: 20 per NFT
    (COALESCE(cc.gold_count, 0) * 30) +       -- Gold: 30 per NFT
    (COALESCE(cc.silver_count, 0) * 25) +     -- Silver: 25 per NFT
    (COALESCE(cc.purple_count, 0) * 20) +    -- Purple: 20 per NFT
    (COALESCE(cc.dark_green_count, 0) * 15) + -- Dark Green: 15 per NFT
    (COALESCE(cc.light_green_count, 0) * 10)  -- Light Green: 10 per NFT
    AS total_daily_reward,
    false AS is_processed
  FROM collection_counts cc
  ON CONFLICT (discord_id) DO UPDATE SET
    discord_name = EXCLUDED.discord_name,
    total_daily_reward = EXCLUDED.total_daily_reward,
    is_processed = false;  -- Reset processed flag when reward amount changes
END;
$$;


--
-- TOC entry 263 (class 1255 OID 16510)
-- Name: update_nft_lister_details(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_nft_lister_details() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (TG_OP = 'UPDATE' AND (OLD.original_lister IS NULL OR NEW.original_lister != OLD.original_lister)) THEN
        -- Clear the lister_discord_name first
        UPDATE nft_metadata SET lister_discord_name = NULL WHERE mint_address = NEW.mint_address;
        
        -- If there's a new original_lister, try to get their discord name
        IF NEW.original_lister IS NOT NULL THEN
            UPDATE nft_metadata 
            SET lister_discord_name = ur.discord_name 
            FROM user_wallets uw
            JOIN user_roles ur ON uw.discord_id = ur.discord_id
            WHERE nft_metadata.mint_address = NEW.mint_address 
            AND uw.wallet_address = NEW.original_lister;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;


--
-- TOC entry 271 (class 1255 OID 106510)
-- Name: update_nft_metadata_on_wallet_connect(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_nft_metadata_on_wallet_connect() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  UPDATE nft_metadata
  SET owner_discord_id = NEW.discord_id,
      owner_name = NEW.discord_name
  WHERE owner_wallet = NEW.wallet_address;

  -- Recompute counts for this user
  PERFORM update_collection_counts(NEW.discord_id);
  RETURN NEW;
END;
$$;


--
-- TOC entry 265 (class 1255 OID 16512)
-- Name: update_nft_owner_details(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_nft_owner_details() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Only proceed if owner_wallet has changed
    IF (TG_OP = 'UPDATE' AND
        (OLD.owner_wallet IS NULL OR NEW.owner_wallet != OLD.owner_wallet)) THEN

        -- First, set discord details to null
        UPDATE nft_metadata
        SET
            owner_discord_id = NULL,
            owner_name = NULL
        WHERE mint_address = NEW.mint_address;

        -- Then, if new owner exists, update with their details
        -- Join through user_wallets to get discord_id, then to user_roles
        IF NEW.owner_wallet IS NOT NULL THEN
            UPDATE nft_metadata
            SET
                owner_discord_id = ur.discord_id,
                owner_name = ur.discord_name
            FROM user_wallets uw
            JOIN user_roles ur ON uw.discord_id = ur.discord_id
            WHERE nft_metadata.mint_address = NEW.mint_address
            AND uw.wallet_address = NEW.owner_wallet;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


--
-- TOC entry 266 (class 1255 OID 16513)
-- Name: update_ownership(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_ownership() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Update NFT ownership
    UPDATE nft_metadata
    SET owner_discord_id = NEW.discord_id,
        owner_name = NEW.discord_name
    WHERE owner_wallet = NEW.wallet_address;

    -- Update BUX ownership
    UPDATE bux_holders
    SET owner_discord_id = NEW.discord_id,
        owner_name = NEW.discord_name
    WHERE wallet_address = NEW.wallet_address;

    -- Create claim account if it doesn't exist
    INSERT INTO claim_accounts (discord_id, wallet_address, unclaimed_amount, total_claimed, last_claim_time)
    SELECT 
        NEW.discord_id,
        NEW.wallet_address,
        0, -- Start with 0 unclaimed amount
        0, -- Start with 0 total claimed
        NOW() -- Set last claim time to now
    WHERE NEW.discord_id IS NOT NULL 
    AND NEW.wallet_address IS NOT NULL
    AND NOT EXISTS (
        SELECT 1 FROM claim_accounts 
        WHERE discord_id = NEW.discord_id
    )
    ON CONFLICT (discord_id) DO NOTHING;

    -- Update daily rewards for this user
    WITH user_holdings AS (
        SELECT
            NEW.discord_id as discord_id,
            NEW.discord_name as discord_name,
            cc.celeb_catz_count,
            cc.money_monsters_3d_count,
            cc.fcked_catz_count,
            cc.money_monsters_count,
            cc.aibitbots_count,
            cc.ai_collabs_count,
            cc.branded_catz_count,
            cc.money_monsters_top_10,
            cc.money_monsters_3d_top_10
        FROM collection_counts cc
        WHERE cc.discord_id = NEW.discord_id
    )
    INSERT INTO daily_rewards (
        discord_id,
        discord_name,
        reward_period_start,
        reward_period_end,
        celeb_catz_count,
        celeb_catz_reward,
        money_monsters_3d_count,
        money_monsters_3d_reward,
        fcked_catz_count,
        fcked_catz_reward,
        money_monsters_count,
        money_monsters_reward,
        aibitbots_count,
        aibitbots_reward,
        ai_collabs_count,
        ai_collabs_reward,
        money_monsters_top_10_count,
        money_monsters_top_10_reward,
        money_monsters_3d_top_10_count,
        money_monsters_3d_top_10_reward,
        branded_catz_count,
        branded_catz_reward,
        total_nft_count,
        total_daily_reward
    )
    SELECT
        h.discord_id,
        h.discord_name,
        date_trunc('day', NOW()),
        date_trunc('day', NOW()) + interval '1 day',
        h.celeb_catz_count,
        h.celeb_catz_count * 20,
        h.money_monsters_3d_count,
        h.money_monsters_3d_count * 7,
        h.fcked_catz_count,
        h.fcked_catz_count * 5,
        h.money_monsters_count,
        h.money_monsters_count * 5,
        h.aibitbots_count,
        h.aibitbots_count * 3,
        h.ai_collabs_count,
        h.ai_collabs_count * 1,
        h.money_monsters_top_10,
        h.money_monsters_top_10 * 5,
        h.money_monsters_3d_top_10,
        h.money_monsters_3d_top_10 * 7,
        h.branded_catz_count,
        h.branded_catz_count * 5,
        (h.celeb_catz_count + h.money_monsters_3d_count + h.fcked_catz_count +
         h.money_monsters_count + h.aibitbots_count + h.ai_collabs_count +
         h.branded_catz_count + h.money_monsters_top_10 + h.money_monsters_3d_top_10),
        (h.celeb_catz_count * 20 + h.money_monsters_3d_count * 7 + h.fcked_catz_count * 5 +
         h.money_monsters_count * 5 + h.aibitbots_count * 3 + h.ai_collabs_count * 1 +
         h.branded_catz_count * 5 + h.money_monsters_top_10 * 5 + h.money_monsters_3d_top_10 * 7)
    FROM user_holdings h
    ON CONFLICT (discord_id, reward_period_start) DO UPDATE SET
        discord_name = EXCLUDED.discord_name,
        celeb_catz_count = EXCLUDED.celeb_catz_count,
        celeb_catz_reward = EXCLUDED.celeb_catz_reward,
        money_monsters_3d_count = EXCLUDED.money_monsters_3d_count,
        money_monsters_3d_reward = EXCLUDED.money_monsters_3d_reward,
        fcked_catz_count = EXCLUDED.fcked_catz_count,
        fcked_catz_reward = EXCLUDED.fcked_catz_reward,
        money_monsters_count = EXCLUDED.money_monsters_count,
        money_monsters_reward = EXCLUDED.money_monsters_reward,
        aibitbots_count = EXCLUDED.aibitbots_count,
        aibitbots_reward = EXCLUDED.aibitbots_reward,
        ai_collabs_count = EXCLUDED.ai_collabs_count,
        ai_collabs_reward = EXCLUDED.ai_collabs_reward,
        money_monsters_top_10_count = EXCLUDED.money_monsters_top_10_count,
        money_monsters_top_10_reward = EXCLUDED.money_monsters_top_10_reward,
        money_monsters_3d_top_10_count = EXCLUDED.money_monsters_3d_top_10_count,
        money_monsters_3d_top_10_reward = EXCLUDED.money_monsters_3d_top_10_reward,
        branded_catz_count = EXCLUDED.branded_catz_count,
        branded_catz_reward = EXCLUDED.branded_catz_reward,
        total_nft_count = EXCLUDED.total_nft_count,
        total_daily_reward = EXCLUDED.total_daily_reward,
        calculation_time = CURRENT_TIMESTAMP;

    RETURN NEW;
END;
$$;


--
-- TOC entry 267 (class 1255 OID 16514)
-- Name: update_roles(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_roles() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
    bux_balance NUMERIC;
    role_record RECORD;
    nft_count INTEGER;
    current_value BOOLEAN;
    new_value BOOLEAN;
    collection_counts RECORD;
    holder_roles RECORD;
BEGIN
    -- Get BUX balance
    SELECT COALESCE(balance, 0) INTO bux_balance
    FROM bux_holders
    WHERE wallet_address = NEW.wallet_address;

    -- Get collection counts
    SELECT * INTO collection_counts
    FROM collection_counts
    WHERE wallet_address = NEW.wallet_address;

    -- Get holder roles
    SELECT fcked_catz_holder, money_monsters_holder, moneymonsters3d_holder, ai_bitbots_holder, celebcatz_holder
    INTO holder_roles
    FROM user_roles
    WHERE discord_id = NEW.discord_id;

    -- Update BUXDAO5 role based on holder roles
    new_value := (
        holder_roles.fcked_catz_holder AND
        holder_roles.money_monsters_holder AND
        holder_roles.moneymonsters3d_holder AND
        holder_roles.ai_bitbots_holder AND
        holder_roles.celebcatz_holder
    );
    SELECT buxdao_5 INTO current_value
    FROM user_roles
    WHERE discord_id = NEW.discord_id;
    IF current_value IS DISTINCT FROM new_value THEN
        UPDATE user_roles
        SET buxdao_5 = new_value
        WHERE discord_id = NEW.discord_id;
    END IF;

    -- Update Money Monsters Top 10 role
    new_value := (COALESCE(collection_counts.money_monsters_top_10, 0) > 0);
    SELECT money_monsters_top_10 INTO current_value
    FROM user_roles
    WHERE discord_id = NEW.discord_id;
    IF current_value IS DISTINCT FROM new_value THEN
        UPDATE user_roles
        SET money_monsters_top_10 = new_value
        WHERE discord_id = NEW.discord_id;
    END IF;

    -- Update Money Monsters 3D Top 10 role
    new_value := (COALESCE(collection_counts.money_monsters_3d_top_10, 0) > 0);
    SELECT money_monsters_3d_top_10 INTO current_value
    FROM user_roles
    WHERE discord_id = NEW.discord_id;
    IF current_value IS DISTINCT FROM new_value THEN
        UPDATE user_roles
        SET money_monsters_3d_top_10 = new_value
        WHERE discord_id = NEW.discord_id;
    END IF;

    -- Loop through roles
    FOR role_record IN SELECT * FROM roles LOOP
        -- For holder and collab roles
        IF role_record.type IN ('holder', 'collab') THEN
            -- Get NFT count
            SELECT COUNT(*) INTO nft_count
            FROM nft_metadata
            WHERE owner_wallet = NEW.wallet_address
            AND LOWER(symbol) = role_record.collection;
            -- Determine new value
            new_value := (nft_count >= role_record.threshold);
            -- Get current value
            EXECUTE format('SELECT %I FROM user_roles WHERE discord_id = $1', role_record.collection || '_holder')
            INTO current_value
            USING NEW.discord_id;
            -- Only update if value changed
            IF current_value IS DISTINCT FROM new_value THEN
                EXECUTE format('UPDATE user_roles SET %I = $1 WHERE discord_id = $2', role_record.collection || '_holder')
                USING new_value, NEW.discord_id;
            END IF;
        END IF;
        -- For BUX roles
        IF role_record.type = 'bux' THEN
            -- Determine new value
            new_value := (bux_balance >= role_record.threshold);
            -- Get current value
            EXECUTE format('SELECT %I FROM user_roles WHERE discord_id = $1', 'bux_' || role_record.name)
            INTO current_value
            USING NEW.discord_id;
            -- Only update if value changed
            IF current_value IS DISTINCT FROM new_value THEN
                EXECUTE format('UPDATE user_roles SET %I = $1 WHERE discord_id = $2', 'bux_' || role_record.name)
                USING new_value, NEW.discord_id;
            END IF;
        END IF;
    END LOOP;
    RETURN NEW;
END;
$_$;


--
-- TOC entry 268 (class 1255 OID 16515)
-- Name: update_user_roles(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_user_roles() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN IF OLD.owner_wallet IS NOT NULL THEN INSERT INTO user_roles (discord_id, wallet_address, discord_name, fcked_catz_holder, money_monsters_holder, moneymonsters3d_holder, ai_bitbots_holder, celebcatz_holder, fcked_catz_whale, money_monsters_whale, moneymonsters3d_whale, ai_bitbots_whale) SELECT MAX(owner_discord_id), OLD.owner_wallet, MAX(owner_name), COUNT(*) FILTER (WHERE symbol = 'FCKEDCATZ') > 0, COUNT(*) FILTER (WHERE symbol = 'MM') > 0, COUNT(*) FILTER (WHERE symbol = 'MM3D') > 0, COUNT(*) FILTER (WHERE symbol = 'AIBB') > 0, COUNT(*) FILTER (WHERE symbol = 'CelebCatz') > 0, COUNT(*) FILTER (WHERE symbol = 'FCKEDCATZ') >= 25, COUNT(*) FILTER (WHERE symbol = 'MM') >= 25, COUNT(*) FILTER (WHERE symbol = 'MM3D') >= 25, COUNT(*) FILTER (WHERE symbol = 'AIBB') >= 10 FROM nft_metadata WHERE owner_wallet = OLD.owner_wallet AND owner_discord_id IS NOT NULL GROUP BY owner_wallet ON CONFLICT (discord_id) DO UPDATE SET wallet_address = EXCLUDED.wallet_address, discord_name = EXCLUDED.discord_name, fcked_catz_holder = EXCLUDED.fcked_catz_holder, money_monsters_holder = EXCLUDED.money_monsters_holder, moneymonsters3d_holder = EXCLUDED.moneymonsters3d_holder, ai_bitbots_holder = EXCLUDED.ai_bitbots_holder, celebcatz_holder = EXCLUDED.celebcatz_holder, fcked_catz_whale = EXCLUDED.fcked_catz_whale, money_monsters_whale = EXCLUDED.money_monsters_whale, moneymonsters3d_whale = EXCLUDED.moneymonsters3d_whale, ai_bitbots_whale = EXCLUDED.ai_bitbots_whale, last_updated = CURRENT_TIMESTAMP; END IF; IF NEW.owner_wallet IS NOT NULL THEN INSERT INTO user_roles (discord_id, wallet_address, discord_name, fcked_catz_holder, money_monsters_holder, moneymonsters3d_holder, ai_bitbots_holder, celebcatz_holder, fcked_catz_whale, money_monsters_whale, moneymonsters3d_whale, ai_bitbots_whale) SELECT MAX(owner_discord_id), NEW.owner_wallet, MAX(owner_name), COUNT(*) FILTER (WHERE symbol = 'FCKEDCATZ') > 0, COUNT(*) FILTER (WHERE symbol = 'MM') > 0, COUNT(*) FILTER (WHERE symbol = 'MM3D') > 0, COUNT(*) FILTER (WHERE symbol = 'AIBB') > 0, COUNT(*) FILTER (WHERE symbol = 'CelebCatz') > 0, COUNT(*) FILTER (WHERE symbol = 'FCKEDCATZ') >= 25, COUNT(*) FILTER (WHERE symbol = 'MM') >= 25, COUNT(*) FILTER (WHERE symbol = 'MM3D') >= 25, COUNT(*) FILTER (WHERE symbol = 'AIBB') >= 10 FROM nft_metadata WHERE owner_wallet = NEW.owner_wallet AND owner_discord_id IS NOT NULL GROUP BY owner_wallet ON CONFLICT (discord_id) DO UPDATE SET wallet_address = EXCLUDED.wallet_address, discord_name = EXCLUDED.discord_name, fcked_catz_holder = EXCLUDED.fcked_catz_holder, money_monsters_holder = EXCLUDED.money_monsters_holder, moneymonsters3d_holder = EXCLUDED.moneymonsters3d_holder, ai_bitbots_holder = EXCLUDED.ai_bitbots_holder, celebcatz_holder = EXCLUDED.celebcatz_holder, fcked_catz_whale = EXCLUDED.fcked_catz_whale, money_monsters_whale = EXCLUDED.money_monsters_whale, moneymonsters3d_whale = EXCLUDED.moneymonsters3d_whale, ai_bitbots_whale = EXCLUDED.ai_bitbots_whale, last_updated = CURRENT_TIMESTAMP; END IF; RETURN NEW; END; $$;


--
-- TOC entry 270 (class 1255 OID 16516)
-- Name: update_user_roles_on_bux_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_user_roles_on_bux_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_discord_id varchar;
BEGIN
  IF TG_OP = 'DELETE' THEN
    -- On delete, rebuild roles for the owner if they had one
    IF OLD.owner_discord_id IS NOT NULL THEN
      PERFORM rebuild_user_roles(OLD.owner_discord_id);
    ELSE
      -- Try to find owner via user_wallets
      SELECT discord_id INTO v_discord_id
      FROM user_wallets
      WHERE wallet_address = OLD.wallet_address
      LIMIT 1;
      
      IF v_discord_id IS NOT NULL THEN
        PERFORM rebuild_user_roles(v_discord_id);
      END IF;
    END IF;
  ELSE
    -- On insert/update, rebuild roles for the owner
    IF NEW.owner_discord_id IS NOT NULL THEN
      PERFORM rebuild_user_roles(NEW.owner_discord_id);
    ELSE
      -- Try to find owner via user_wallets
      SELECT discord_id INTO v_discord_id
      FROM user_wallets
      WHERE wallet_address = NEW.wallet_address
      LIMIT 1;
      
      IF v_discord_id IS NOT NULL THEN
        PERFORM rebuild_user_roles(v_discord_id);
      END IF;
    END IF;
  END IF;
  RETURN NULL;
END;
$$;


--
-- TOC entry 269 (class 1255 OID 16517)
-- Name: update_user_roles_on_collection_counts_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_user_roles_on_collection_counts_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  PERFORM rebuild_user_roles(NEW.discord_id);
  RETURN NULL;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 220 (class 1259 OID 16535)
-- Name: claim_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.claim_accounts (
    discord_id character varying(255) NOT NULL,
    unclaimed_amount bigint DEFAULT 0,
    total_claimed bigint DEFAULT 0,
    last_claim_time timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    discord_name text
);


--
-- TOC entry 221 (class 1259 OID 16548)
-- Name: claim_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.claim_transactions (
    id integer NOT NULL,
    discord_id character varying(255) NOT NULL,
    amount integer NOT NULL,
    transaction_hash character varying(255),
    status character varying(20) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    processed_at timestamp with time zone,
    error_message text,
    CONSTRAINT claim_transactions_status_check CHECK (((status)::text = ANY (ARRAY[('processing'::character varying)::text, ('completed'::character varying)::text, ('failed'::character varying)::text])))
);


--
-- TOC entry 222 (class 1259 OID 16555)
-- Name: claim_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.claim_transactions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3524 (class 0 OID 0)
-- Dependencies: 222
-- Name: claim_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.claim_transactions_id_seq OWNED BY public.claim_transactions.id;


--
-- TOC entry 223 (class 1259 OID 16556)
-- Name: collection_counts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.collection_counts (
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
    cnft_total_count integer DEFAULT 0
);


--
-- TOC entry 224 (class 1259 OID 16559)
-- Name: daily_rewards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.daily_rewards (
    discord_id character varying(255) NOT NULL,
    discord_name character varying(255),
    total_daily_reward integer DEFAULT 0,
    is_processed boolean DEFAULT false,
    last_accumulated_at timestamp with time zone
);


--
-- TOC entry 225 (class 1259 OID 16603)
-- Name: nft_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nft_metadata (
    id integer NOT NULL,
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
    leaf_colour text,
    og420 boolean DEFAULT false,
    CONSTRAINT nft_metadata_leaf_colour_check CHECK (((leaf_colour IS NULL) OR (leaf_colour = ANY (ARRAY['Light green'::text, 'Dark green'::text, 'Purple'::text, 'Silver'::text, 'Gold'::text]))))
);


--
-- TOC entry 232 (class 1259 OID 16752)
-- Name: nft_metadata_aggregated; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.nft_metadata_aggregated AS
 SELECT symbol,
    count(*) AS total_supply,
    count(*) FILTER (WHERE is_listed) AS listed_count
   FROM public.nft_metadata
  GROUP BY symbol;


--
-- TOC entry 226 (class 1259 OID 16615)
-- Name: nft_metadata_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.nft_metadata_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3525 (class 0 OID 0)
-- Dependencies: 226
-- Name: nft_metadata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.nft_metadata_id_seq OWNED BY public.nft_metadata.id;


--
-- TOC entry 227 (class 1259 OID 16625)
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id integer NOT NULL,
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
    CONSTRAINT roles_type_check CHECK (((type)::text = ANY ((ARRAY['holder'::character varying, 'whale'::character varying, 'token'::character varying, 'special'::character varying, 'collab'::character varying, 'top10'::character varying, 'level'::character varying])::text[])))
);


--
-- TOC entry 228 (class 1259 OID 16634)
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.roles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3526 (class 0 OID 0)
-- Dependencies: 228
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;


--
-- TOC entry 229 (class 1259 OID 16635)
-- Name: session; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.session (
    sid character varying NOT NULL,
    sess json NOT NULL,
    expire timestamp(6) without time zone NOT NULL
);


--
-- TOC entry 217 (class 1259 OID 16518)
-- Name: token_holders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.token_holders (
    wallet_address character varying(44) NOT NULL,
    balance numeric(20,9) DEFAULT 0,
    owner_discord_id character varying(100),
    owner_name character varying(255),
    last_updated timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    is_exempt boolean DEFAULT false
);


--
-- TOC entry 218 (class 1259 OID 16524)
-- Name: user_wallets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_wallets (
    id integer NOT NULL,
    discord_id character varying(100) NOT NULL,
    wallet_address character varying(44) NOT NULL,
    is_primary boolean DEFAULT false,
    connected_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    last_used timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    discord_name character varying(255)
);


--
-- TOC entry 219 (class 1259 OID 16530)
-- Name: token_holders_aggregated; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.token_holders_aggregated AS
 SELECT uw.discord_id,
    COALESCE(sum(bh.balance), (0)::numeric) AS total_balance,
    count(bh.wallet_address) AS wallet_count,
    now() AS last_updated
   FROM (public.user_wallets uw
     LEFT JOIN public.token_holders bh ON (((uw.wallet_address)::text = (bh.wallet_address)::text)))
  GROUP BY uw.discord_id;


--
-- TOC entry 230 (class 1259 OID 16654)
-- Name: user_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_roles (
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


--
-- TOC entry 233 (class 1259 OID 65541)
-- Name: user_roles_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.user_roles_view AS
 SELECT discord_id,
    discord_name,
    roles,
    last_updated
   FROM public.user_roles;


--
-- TOC entry 231 (class 1259 OID 16668)
-- Name: user_wallets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_wallets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3527 (class 0 OID 0)
-- Dependencies: 231
-- Name: user_wallets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_wallets_id_seq OWNED BY public.user_wallets.id;


--
-- TOC entry 3281 (class 2604 OID 16675)
-- Name: claim_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_transactions ALTER COLUMN id SET DEFAULT nextval('public.claim_transactions_id_seq'::regclass);


--
-- TOC entry 3297 (class 2604 OID 16677)
-- Name: nft_metadata id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nft_metadata ALTER COLUMN id SET DEFAULT nextval('public.nft_metadata_id_seq'::regclass);


--
-- TOC entry 3300 (class 2604 OID 16679)
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- TOC entry 3274 (class 2604 OID 16681)
-- Name: user_wallets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_wallets ALTER COLUMN id SET DEFAULT nextval('public.user_wallets_id_seq'::regclass);


--
-- TOC entry 3507 (class 0 OID 16535)
-- Dependencies: 220
-- Data for Name: claim_accounts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.claim_accounts (discord_id, unclaimed_amount, total_claimed, last_claim_time, created_at, discord_name) FROM stdin;
392070555102085130	0	0	2025-11-19 09:46:16.704629+00	2025-11-19 09:46:16.704629+00	Gaeaphile | tD P4L
968226679963148318	460	0	2025-11-18 05:01:25.982482+00	2025-11-18 05:01:25.982482+00	jeffdukes1 $BETSKI
931160720261939230	100	5	2025-11-18 19:24:54.983427+00	2025-11-16 08:13:15.500443+00	Tom [SLOTTO]
1082504606690582601	1400	0	2025-11-20 03:13:15.607273+00	2025-11-20 03:13:15.607273+00	CannaSolz420
290531269970755587	380	0	2025-11-16 18:14:58.932683+00	2025-11-16 18:14:58.932683+00	Gob1
890398220600115271	3690	1845	2025-11-18 19:05:39.883481+00	2025-11-16 23:48:30.437064+00	Snoop D Fox
\.


--
-- TOC entry 3508 (class 0 OID 16548)
-- Dependencies: 221
-- Data for Name: claim_transactions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.claim_transactions (id, discord_id, amount, transaction_hash, status, created_at, processed_at, error_message) FROM stdin;
\.


--
-- TOC entry 3510 (class 0 OID 16556)
-- Dependencies: 223
-- Data for Name: collection_counts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.collection_counts (discord_id, discord_name, total_count, last_updated, gold_count, silver_count, purple_count, dark_green_count, light_green_count, og420_count, cnft_gold_count, cnft_silver_count, cnft_purple_count, cnft_dark_green_count, cnft_light_green_count, cnft_total_count) FROM stdin;
968226679963148318	jeffdukes1	6	2025-11-20 09:54:17.180352	0	1	3	1	1	6	0	0	0	0	0	0
392070555102085130	gaeaphile	0	2025-11-20 09:54:17.197509	0	0	0	0	0	0	0	1	2	1	3	7
290531269970755587	gob.1.	3	2025-11-20 09:54:17.211589	1	0	1	0	1	3	1	1	2	1	1	6
931160720261939230	Tom [SLOTTO]	1	2025-11-20 09:54:17.256169	0	0	0	1	0	1	0	0	0	0	0	0
1082504606690582601	snoopdfox	39	2025-11-20 09:54:17.226531	3	4	6	10	16	39	2	14	3	3	1	23
890398220600115271	.shoeman	52	2025-11-20 09:54:17.241399	2	5	9	13	23	52	1	1	1	1	1	5
\.


--
-- TOC entry 3511 (class 0 OID 16559)
-- Dependencies: 224
-- Data for Name: daily_rewards; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.daily_rewards (discord_id, discord_name, total_daily_reward, is_processed, last_accumulated_at) FROM stdin;
1082504606690582601	snoopdfox	1482	f	2025-11-20 03:34:45.997124+00
890398220600115271	.shoeman	1845	f	2025-11-20 03:34:45.997124+00
931160720261939230	Tom [SLOTTO]	35	f	2025-11-20 03:34:45.997124+00
968226679963148318	jeffdukes1	230	f	2025-11-20 03:34:45.997124+00
392070555102085130	gaeaphile	15	f	\N
290531269970755587	gob.1.	138	f	2025-11-20 03:34:45.997124+00
\.


--
-- TOC entry 3512 (class 0 OID 16603)
-- Dependencies: 225
-- Data for Name: nft_metadata; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.nft_metadata (id, mint_address, name, symbol, uri, creators, collection, image_url, owner_wallet, owner_discord_id, owner_name, is_listed, list_price, last_sale_price, marketplace, rarity_rank, original_lister, lister_discord_name, leaf_colour, og420) FROM stdin;
183	5koXoMUeytZV9fP5p8GTrAMdgFh2eP6YrzAEVE2jbPeJ	CannaSolz #254	CNSZ	https://gateway.pinit.io/ipfs/QmTfn72hB8aN65jVEPJh4JBwvAGory1QAajgUP7U1ywzgG/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/253	A1hb6VgugqDRKT6xmgx5fG36F2vZF8fJtWorUKKjTKTn	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
184	5hTarugxKy6jByfg3C5nmG2QCZ15gaj2r3xZ6VH7GDFB	CannaSolz #257	CNSZ	https://gateway.pinit.io/ipfs/QmVzTPADdP2sQKzPGoM8whDJijyjSmQuJcYvv3vc4u9M6V/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/256	AJMMYDyBfnCkNZPrgz5E4QJwoyphVfc6ipiUR8koE6DW	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
9	HbtCQ2giw7F5f6CbdG3VxqyMgeVCA3iHCMpidhGpww5H	CannaSolz #192	CNSZ	https://gateway.pinit.io/ipfs/QmRSfDtaMWdzeTDJ3nDgGL2A5UCnpSEujJZf2grRCZi4Bn/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/191	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Dark green	t
543	FkDAPeHSkVDDMg1eAJbzgqptbmYe5VQnCv15zi4MA7wT	NFT #29	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/29	FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	\N	f
545	EdayeoGiKxxcB2Y27mZM2w29jvM2TaDf8vLNFLsgvky8	NFT #28	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/28	FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	\N	f
553	AfBXsqc95Bf9KXPcNiKP7RPyupYX4gEMAnesQmCp9byF	NFT #31	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/31	FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	\N	f
554	AAFj7ScP1ij2Cf1VqA8cRnPfzZhQAvTYnovKn3q2WMPd	NFT #32	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/32	FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	\N	f
560	7ZQcunMgtj8V44ZXhzcNcybDi5U5xyY5dYbY2vcZy8fE	NFT #35	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/35	FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	\N	f
566	5QJu4zfGVZz7mRKpvS1kLxC9vfyCSThnNWBFmfbLshke	NFT #37	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/37	FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	\N	f
568	4pvVZBQtndY4az9zrXmYEJh28tYGAakB3AuAb3kLsp2D	NFT #33	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/33	FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	\N	f
612	EbjLUEQBKSyENdGoA4V5P7iHCeFHtvj3jXwfVE9kVAFa	NFT #22	seedling_dark_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/3befa941-9417-49e2-bfd5-e06c43cffca2/22	FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	\N	f
6	HjuibxDiXTdYd4kY4qktdi8mwiSuGATeDytSnimNdfRc	CannaSolz #8	CNSZ	https://gateway.pinit.io/ipfs/Qmb68FkdmWbotxfCkCt6RbrojroVBEErRXyZNiLEGJHxGW/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/7	HKN4zACpPLhE6CBQtarSfk2Dn45NVVWTKU2RLrtCLdwA	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
99	CBPKgkPJ4vJM2yETQ71AptkjMWLpvZWh3rwAPgJ3U8Jj	CannaSolz #44	CNSZ	https://gateway.pinit.io/ipfs/QmPWvUrQDUTZyoYYLwaYTDbYMm2wz2n2jcvzajQ1KCPfpA/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/43	HKN4zACpPLhE6CBQtarSfk2Dn45NVVWTKU2RLrtCLdwA	\N	\N	f	\N	\N	\N	\N	\N	\N	Purple	t
15	H9iaxQaT6TVCSS7KmpjdC9Sjvvrp5mWLEzrVRTMpzxzo	CannaSolz #143	CNSZ	https://gateway.pinit.io/ipfs/QmTfQADeUA1pCecfc5CTSeXCDQjHReJNj9WzzgFDMrP72H/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/142	9ckRqNxeCmvezNjQdPyYnAaDvJTfbku2Gn4J4sVqFF6o	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
19	H1g6yu7c49A44ggELiymvyNvrnFUSVx8dqAfagxoCx2v	CannaSolz #230	CNSZ	https://gateway.pinit.io/ipfs/QmYkWVcuDMCE3PGj9xErKKtPjvPbrxzFCZwcwiyE7WRfsW/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/229	CDFQARAF9a4H7x1qMQYKqv8jA1Csaj3c11P3srGAfivQ	\N	\N	f	\N	0.167068928	\N	\N	\N	\N	Dark green	t
20	GxcomAtjZ85Ubpq1ioangbxd9yJDTCkDaQXN26ghHjuZ	CannaSolz #165	CNSZ	https://gateway.pinit.io/ipfs/QmcBuv41E3chjwMF4ekGffy62Sg8pfxbndMGwwarn8cjtE/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/164	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Light green	t
14	HGnEYpu6NKYaL8PjnXT8CHaZrtgJvfNdpMtWj36qCGXb	CannaSolz #245	CNSZ	https://gateway.pinit.io/ipfs/QmdP3Vfmg4mAYMJuTpaDXn7pT2iMus8G3xkS8iaLwyWUkD/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/244	BgHcACwthQhFrgfb8KpyTMDFomWcSaQ7zzHQHyyXsZdA	\N	\N	f	\N	\N	\N	\N	\N	\N	Gold	t
254	6aU2ED4iRzuLPYBfzJqE9gPWFvsqgidaui3CD3aMnjk	CannaSolz #30	CNSZ	https://gateway.pinit.io/ipfs/QmTiKPbSSb7rqQhSpi2kaqcREoG165EfeiLZd7rt7PW6bH/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/29	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Light green	t
225	2jKfSUkTK2fbLcSoZ5YHEPmc7oCU7cKNECS2jxAFs13Y	CannaSolz #68	CNSZ	https://gateway.pinit.io/ipfs/QmWUeLk72esbGB2qZUv3eCXxFjGugRgguLx8UaWQzFbsB7/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/67	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Dark green	t
199	4iPGmWjKLFzoVs3RJiaKjmBudhh4RJs3szBmWNxyZEo5	CannaSolz #17	CNSZ	https://gateway.pinit.io/ipfs/QmVRyaPzKZFELhPKku59atpePtRdhv4aejrJU4bhptKCQi/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/16	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Purple	t
23	GvcS2pfpDGG2XRcBEyrpXYMoBAyDQL27P5fGcP8WN5FS	CannaSolz #187	CNSZ	https://gateway.pinit.io/ipfs/Qmct2RjAaber8Y1mEhPfS9ERS5g4CnXShxvUe1LjvvVvbY/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/186	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Dark green	t
194	5EaihPqKLn2VrTsmvJ45WyCxfBsxgwjHb5epSy6f9BUC	CannaSolz #40	CNSZ	https://gateway.pinit.io/ipfs/QmRSvqprHMLp5b4JWHRzEcBkY1ohZKpLtHNPFuEMqmgTQU/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/39	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Dark green	t
4	J3yaTKFxfP8aaH1nFk2iiG6LRU9tpRtWG4mvvyc4vmwg	CannaSolz #60	CNSZ	https://gateway.pinit.io/ipfs/QmNRKXWGNYj4vPaVSFSzirTHeU1FsvetyP1VCLq2zD8pe5/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/59	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Silver	t
37	G6mkhv3k6CrRBGNYqskKASdD85fbjT5oaw4SqPnx7Mdg	CannaSolz #139	CNSZ	https://gateway.pinit.io/ipfs/QmbcwEG9cw1r2hXQ3E8pbSk96g2qoLHdRDjJxjtNRju3DS/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/138	9ckRqNxeCmvezNjQdPyYnAaDvJTfbku2Gn4J4sVqFF6o	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
17	H5FKkcHWxYgY76gyfn16jZ29xDRRaH5H69WG5oosrL6i	CannaSolz #111	CNSZ	https://gateway.pinit.io/ipfs/QmSsLT8PYeDfxiHzYBHUAFgHKWxkvgCvcgBR2GfSJ9JLQ8/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/110	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Dark green	t
16	H5xH1j2H85CJazpMJsSMAtQ1brzDcrNDCsX6DtYvh5bP	CannaSolz #27	CNSZ	https://gateway.pinit.io/ipfs/QmXg9G8VuHUc6hcbWgXwTbdLeJSFfYHPy3wXj52CwqdFxa/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/26	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Light green	t
164	7SNMYnN1wALT1A1oRDzTitDuQQMrUacXpKUgtA2pcCor	CannaSolz #71	CNSZ	https://gateway.pinit.io/ipfs/QmRMMfxHxqN3FFSc51uAPjx2GeAdLdbWwFGJRGWdaVcFR9/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/70	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Dark green	t
27	GYsgonvZ6LSvbKarjNCgeMj4hWXdLaK7Vq6M4gbwub37	CannaSolz #85	CNSZ	https://gateway.pinit.io/ipfs/QmbxTzkKxRraCyk12fTaLJWoDD4FNgJZMTnPDhDhEKzSRc/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/84	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Light green	t
55	FC2WNeEX5H6a381JUFgof1SXQkNeT3yhQG4cphxAsGyX	CannaSolz #46	CNSZ	https://gateway.pinit.io/ipfs/Qma4GMWNtZybnV6tvGLfzmqbMx9D1xcVGGRKLiSFTESnSM/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/45	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Light green	t
40	FuZHgGExtDXWxrTUV73GRy7DZJCgum9CrFVGfmWgMP58	CannaSolz #219	CNSZ	https://gateway.pinit.io/ipfs/QmPRpk5nFuSpqKQVUdpJhF1Nqt6snoxqY1d8xbC2tfXkKm/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/218	66EMDQEr8uGn28fXKgfmA8noN1qr3su1VpNzM9DEUC7o	\N	\N	f	\N	0.167030309	\N	\N	\N	\N	Dark green	t
1	JDr7z92TvNfnmaaujtSRZY2yYPp4vpQMYDc3XF3HocfF	CannaSolz #148	CNSZ	https://gateway.pinit.io/ipfs/QmWC74ZEnuHzks6VUAAKcPMD4EM8eBJZFD9ihHcTio4aKL/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/147	AcWwsEwgcEHz6rzUTXcnSksFZbETtc2JhA4jF7PKjp9T	931160720261939230	Tom [SLOTTO]	f	\N	\N	\N	\N	\N	\N	Dark green	t
39	FxqzmNUU4rtpdy8qmuorSiN89sp85K2vh6UnV3oz51zm	CannaSolz #86	CNSZ	https://gateway.pinit.io/ipfs/Qmd8XJ3Mi7Mv6nogxVUniz7vLGqPdFnkbmydXs8C1VjDPd/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/85	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Dark green	t
65	EXokpiVaTDf7Z6oMEFBMao77SqSN16qYa2m5UjqCErxd	CannaSolz #59	CNSZ	https://gateway.pinit.io/ipfs/Qme78mtp28ngYZdMkPpyGAqf8TJfta6UFDDpECizUWaTiM/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/58	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Light green	t
252	92NVZCZJaW21nNcaKEhYWUb3cpSjvuWDXLiqgu5CRLu	CannaSolz #112	CNSZ	https://gateway.pinit.io/ipfs/QmcHvTY66uidL4K7n1HUF8aJE9biF4S21jsuWmuJiQ5zRr/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/111	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Dark green	t
609	FvmBzmrr5PXefsoEXSBx1YdHQNbGSSd4xStidqJSSccT	NFT #0	seedling_dark_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/3befa941-9417-49e2-bfd5-e06c43cffca2/0	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	\N	f
26	Gj7CgkysZSGvyaUcfXde1JWGsk1TR4dQcTDAZ1u5qjLE	CannaSolz #132	CNSZ	https://gateway.pinit.io/ipfs/Qmdc1qqrZ5cHNuejfpRw2RteSDUBTMxkdAYaHo2eYdrgnm/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/131	Dxmt3kvYbecfWhUL2W1SbR9xLUtukGStyi5z9R4zVEV	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
516	HtKAR7yaZAbC4hPLd9KSErrRgFoSCgR3gZvFMSrYGjrt	NFT #5	seedling_gold	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/8928926c-567d-45b5-889e-c7c3c1112901/5	G4KnzkwCkK2dNxeazGbxnTtkwnwC1QWg6ey6LEVEWpCZ	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
517	HSLn6npwdiKyjc2ZAADXSGqWJonZmUgQkS5Wmronc2x6	NFT #14	seedling_gold	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/8928926c-567d-45b5-889e-c7c3c1112901/14	6SMH9uvR3UEo2XUTUGJ8x1FXwDX1SCF6t7d1FK3pZuN2	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
518	FFZ18i7GYY3k1ebzu1wRLU2XzBFK9EuGRTeDyNC2pHou	NFT #10	seedling_gold	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/8928926c-567d-45b5-889e-c7c3c1112901/10	BZ449ifq2FvMDm8MPwkwtxviFXwQsWsX4WmSMNUBoj1Z	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
520	ESSzTuLmYmpzZ78dxFREtPWv3WFZVkN5nT93r62ZZorM	NFT #20	seedling_gold	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/8928926c-567d-45b5-889e-c7c3c1112901/20	6SMH9uvR3UEo2XUTUGJ8x1FXwDX1SCF6t7d1FK3pZuN2	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
521	BsV7n5e9Z37ARGGmm6WqSsmvhCfVshQuYPJGhzBeymQY	NFT #7	seedling_gold	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/8928926c-567d-45b5-889e-c7c3c1112901/7	ffeabXrJgdcNFd8k1xJka2rKganFwdBQPUzZugDZsFJ	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
522	AkaaiGMNiv27atwDqPvV7uhz9YdyLdJwTfQRJL62GAct	NFT #13	seedling_gold	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/8928926c-567d-45b5-889e-c7c3c1112901/13	A1hb6VgugqDRKT6xmgx5fG36F2vZF8fJtWorUKKjTKTn	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
523	A2T5fW5cmWnjhnUgiL8cpvCiXpCJqSrqgSqPSH4mpYtN	NFT #8	seedling_gold	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/8928926c-567d-45b5-889e-c7c3c1112901/8	6SMH9uvR3UEo2XUTUGJ8x1FXwDX1SCF6t7d1FK3pZuN2	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
524	9UMMM24nU6h5exuxUrj67q1dNyhGaq4CXma7ns5nKpXt	NFT #19	seedling_gold	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/8928926c-567d-45b5-889e-c7c3c1112901/19	Es8uorywaftETgtQxjUvA6mGzuYwXJA7V6zKn65mYxNw	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
525	9CKZunrUZHJzQTHQR29BgAt5NmXVeBpmqVyyk8o72dLq	NFT #11	seedling_gold	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/8928926c-567d-45b5-889e-c7c3c1112901/11	C9xiFhke9pTU89YdNoLskuA64YNScWF42dmCJach13yh	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
526	82FHYjP9Dt1xavubF9U8gngpwsgfTnNc8o8AEVe2SpQh	NFT #2	seedling_gold	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/8928926c-567d-45b5-889e-c7c3c1112901/2	D6NdBATavTnzPThqYYnjZ7ZVfT9LnfN4qBoX9ZtmF4VC	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
28	GUDTe7gq1Ur5h1Y41wm44kZTVoWXQoxYWAnw5yQEJF8B	CannaSolz #215	CNSZ	https://gateway.pinit.io/ipfs/QmNwms55TXu2ictSK87bLZD8nywhZPh6gxY661JGHEWCwk/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/214	BUB21Fe2ttCid3Y9Bka12VKPfRzhD5cpCmiBHmdDY41r	\N	\N	f	\N	0.167016380	\N	\N	\N	\N	Light green	t
527	7sT7VBWTHRaab8Py7Zw9XbeaACUbQwVGk6XBAYqnmgWD	NFT #6	seedling_gold	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/8928926c-567d-45b5-889e-c7c3c1112901/6	9xiDUvtguHAVMAggcYsvxaJAKwDJeJFNSqa4t6okXKUY	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
528	6PsD9rEfdfwoXwU9Ue5B5WJcVs65QmK3W9tdDwGBnW2Y	NFT #1	seedling_gold	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/8928926c-567d-45b5-889e-c7c3c1112901/1	A1hb6VgugqDRKT6xmgx5fG36F2vZF8fJtWorUKKjTKTn	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
529	6DNPyG7EaYNmJVuAVCgb3hFrgFonFzXiXJyjDQ8mWkdT	NFT #17	seedling_gold	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/8928926c-567d-45b5-889e-c7c3c1112901/17	6SMH9uvR3UEo2XUTUGJ8x1FXwDX1SCF6t7d1FK3pZuN2	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
531	5iRPpCKZj3FaZauVYWzpG3trnVbhPcAsAZQ9miHMWbQr	NFT #15	seedling_gold	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/8928926c-567d-45b5-889e-c7c3c1112901/15	6SMH9uvR3UEo2XUTUGJ8x1FXwDX1SCF6t7d1FK3pZuN2	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
533	3vpxXQNLgsWXDPSoF5g7FbwDwA9DQf8ymmGtJ8LaoUWJ	NFT #16	seedling_gold	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/8928926c-567d-45b5-889e-c7c3c1112901/16	y1JFr5uQZfw2T2X1ER8XLcCnTMLqE3xGfVvPHMHhT2n	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
534	3DhKnNg971Jk7eioFnejPnWmXb6p3qoDU1VKKKPsGg8F	NFT #9	seedling_gold	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/8928926c-567d-45b5-889e-c7c3c1112901/9	C9xiFhke9pTU89YdNoLskuA64YNScWF42dmCJach13yh	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
535	2fwij8F7DV1cNPf2LKvcTDqi3MHcLo2ADqekpa1QicxL	NFT #18	seedling_gold	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/8928926c-567d-45b5-889e-c7c3c1112901/18	HcHa65RzujcPmrb2UatobG17BuLKBVyqZckEUiTTYJuB	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
536	29G5pe1XWdiaw19TAqDeTGm1UHz6UC4RwejJQLhXBHPm	NFT #12	seedling_gold	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/8928926c-567d-45b5-889e-c7c3c1112901/12	G4KnzkwCkK2dNxeazGbxnTtkwnwC1QWg6ey6LEVEWpCZ	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
530	5tdscCWaPqCDeE8S4PdJnwx8Leh9cE5xgqsp8vSrqmRj	NFT #22	seedling_gold	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/8928926c-567d-45b5-889e-c7c3c1112901/22	FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	\N	f
519	FCw96nfpDxapZtW5NNU5ekzEVXrrQ1MNCmfvzbds7eHw	NFT #3	seedling_gold	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/8928926c-567d-45b5-889e-c7c3c1112901/3	A6w5xnT64gbKQynkPmcPuSXiy6sUNK3cJpzdUTQWSrMZ	290531269970755587	gob.1.	f	\N	\N	\N	\N	\N	\N	\N	f
537	288qEDQXKwC9NDTRt2QCNAurDac1Yu5WvqsZfe6wGbGa	NFT #4	seedling_gold	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/8928926c-567d-45b5-889e-c7c3c1112901/4	C9xiFhke9pTU89YdNoLskuA64YNScWF42dmCJach13yh	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
53	FQ5N4o3h9gBwSpnENue1nsYxsDYPjhdC4ejhdo3LgvF2	CannaSolz #226	CNSZ	https://gateway.pinit.io/ipfs/QmQ37dVBvXXJKWmc5F9AmnGt91JxhPkdPztEPDtL95LY2o/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/225	AYsfPAsDyiw1GQpDFYEQBmd6q1QQ28A9pUMq9GNbNBYo	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
60	EoxjrA1Jpxw9jtmayP8nc4m4fFccUnJBAk6TSLTDpfS1	CannaSolz #212	CNSZ	https://gateway.pinit.io/ipfs/QmShgcW4eeYSDqmo9yNx3HLHJqdizMX7VeUe56mWDQzAGZ/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/211	BUB21Fe2ttCid3Y9Bka12VKPfRzhD5cpCmiBHmdDY41r	\N	\N	f	\N	0.167048880	\N	\N	\N	\N	Dark green	t
68	EKGgEH4xNikjxbir1FszFRB4upU71qTApJWCb2Z9FRsm	CannaSolz #57	CNSZ	https://gateway.pinit.io/ipfs/QmVfjGY7iHWL9u6ZH3dptSsWnBnkXnwvmJs8xB3UhmGaNM/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/56	BgEtfZdZ3kSDEYr5GqCCh3HpXwPqV8UShdMzrYkSmEKU	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
540	GmHicULJzS9nSbvsfd7RrL3uth6g1P8sRT12BHSvsfDm	NFT #17	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/17	BR8h8qiA7jDFhS8UeF3ioMEbc5pALDM7WimToNnur8Gh	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
70	EDuWwo3nP4hp3PA4UJBuP9Caz8zLtT7UCZUhjcii1s9R	CannaSolz #90	CNSZ	https://gateway.pinit.io/ipfs/QmWyagCeybMvnjHDZZykqaCUQBNWLwvJHRtT6iyRoX3FCQ/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/89	3fjkWASNsChdfv9MVjCN8GXhVNQWxntHh4bzZVM1yBzp	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
542	GKRDLcj9q5qYn8tWvvb2qrPU19vz9yxAtoEbKQQhR4p9	NFT #8	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/8	D6NdBATavTnzPThqYYnjZ7ZVfT9LnfN4qBoX9ZtmF4VC	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
34	GCxpxScvWEh1oo8uvBjw46skDqgCFSs7prSXkimJjrvW	CannaSolz #147	CNSZ	https://gateway.pinit.io/ipfs/QmNpiX3TDhCSJJcvUWaKbZt8Q5zqwGrm9tRciXDTxQubGi/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/146	9Eub4AUaLZZCyNXBWdZK27t8SctSasi67yTZESZCyLkH	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
546	Ec3mWbdd9YKCDwRwDFEsJ8Ehk9tVMnbuy6z8xxEBp1L5	NFT #12	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/12	BZ449ifq2FvMDm8MPwkwtxviFXwQsWsX4WmSMNUBoj1Z	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
547	DdHC2NLCXV3iSE1uuNA1rE3Yda52R2vJ5FcYZF7MDPBj	NFT #13	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/13	G4KnzkwCkK2dNxeazGbxnTtkwnwC1QWg6ey6LEVEWpCZ	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
548	DXusQMVdeRXSBYQiqWzVK3Zd3sbnCaG2pABw39Sw3tE5	NFT #6	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/6	A1hb6VgugqDRKT6xmgx5fG36F2vZF8fJtWorUKKjTKTn	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
538	v9c8me5fowCgySpvhLR584eodPndxpo8iWy5VtYyEyQ	NFT #21	seedling_gold	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/8928926c-567d-45b5-889e-c7c3c1112901/21	FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	\N	f
539	HJBY6WzcrXBi24659dXPxiJB7Ur7KCnuiGJZkxUFFrbd	NFT #26	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/26	FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	\N	f
541	GjArAcyY92M3fhMS1EUkYCtTU1YV6bLdQT1cdi4fpZ7c	NFT #30	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/30	FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	\N	f
551	BGhcV27Nnyc1RDqbouye7CCwKryD7kFHzf4c95yuyW7V	NFT #10	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/10	BZ449ifq2FvMDm8MPwkwtxviFXwQsWsX4WmSMNUBoj1Z	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
555	9rnubFJx2n7rfwL1NZVoPbj9XdsaQFsMG1LVwJ8R6Hy5	NFT #5	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/5	D6NdBATavTnzPThqYYnjZ7ZVfT9LnfN4qBoX9ZtmF4VC	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
556	9kDoxg1J3AR2dpJ5tKtPSsvm4bbfS2tcQoUGVKF1oh5m	NFT #22	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/22	HcHa65RzujcPmrb2UatobG17BuLKBVyqZckEUiTTYJuB	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
557	9TerE2VdbD8ucBhZMbFJyvPtqnhYm3XCfpmcuzkjGAKF	NFT #7	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/7	D6NdBATavTnzPThqYYnjZ7ZVfT9LnfN4qBoX9ZtmF4VC	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
32	GHxM2GcQKcrgUdMy8AhhVhZ9fhRyjXMj4qdKYF7kYs43	CannaSolz #101	CNSZ	https://gateway.pinit.io/ipfs/QmeK3R4us4uisfvZbRZLgNJrZK2uSPkR6p2QfTfLiXNEAH/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/100	E28hBxZSjPFPZX4fMNnj2sfU2ENM6cJHyDAWJhNPVu7V	\N	\N	f	\N	0.000000000	\N	\N	\N	\N	Light green	t
549	DRzLz7rvF4pvL25G41LJWQ9oLXyHET2yBQ9fouWFRqNG	NFT #36	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/36	FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	\N	f
559	8Wj7wY8qoZyuCH5QCrP3gHsAhjJKDME8MT9ZaYrZ84Zv	NFT #19	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/19	BwiWyx6gicWVkgdAyTqRw2Q28wxqA6YugWiZhLAQdSmy	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
43	FmDyPzGDAmYor8Dob7My577B4AGamCGtJ3xV9xM5mNBx	CannaSolz #136	CNSZ	https://gateway.pinit.io/ipfs/QmVdTp3ZXa8JghGW5JU9Z447RJhmFA8YhgqNhHnA9bo2sQ/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/135	bctzt1rfj4yYLh7iGgdkjpHXwR3mf7EgcFHuXcBopcJ	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
550	CAsiMecXFh2VDpEMHBYRdnmfWBSuBtRVxc3wsqte7NCr	NFT #27	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/27	FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	\N	f
561	7WCHtu4wq8sxmJQFRB4B5ajVuKfya7vAoCjgqQ5Se3JV	NFT #11	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/11	C9xiFhke9pTU89YdNoLskuA64YNScWF42dmCJach13yh	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
562	6hTSn2YNjnrdfuVbo9hpQ4djHftYEpKtD198wjYs9oUw	NFT #18	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/18	5hPtBzn75mq5kJfTRHb5oT17hJxdSqQg4MS6meoy8dVD	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
563	6gkgAULT3CQvqAM4FNSAmGy3TRdZPdxnCJkBTewaruRh	NFT #24	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/24	Es8uorywaftETgtQxjUvA6mGzuYwXJA7V6zKn65mYxNw	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
564	6dVJKYdvk7h1EG627w4GFz8euT1oDR725aZUZefyUwNV	NFT #1	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/1	BZ449ifq2FvMDm8MPwkwtxviFXwQsWsX4WmSMNUBoj1Z	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
565	69kHcXyiubKMsviN3gbVr8a7kftBMgPs6oH9ZjJ5RcwN	NFT #3	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/3	D6NdBATavTnzPThqYYnjZ7ZVfT9LnfN4qBoX9ZtmF4VC	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
567	5NH2XfD6qHdz19AcYS81M5WmVVdjT1Yyqqp9fy1XPufZ	NFT #16	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/16	GExJDDpdMvVjQMtbK5o7kfozz3tmWSSJPS2q97xH844X	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
569	4RL2MzgdzdPwAEgZL2cXbAcNiVxucxxv3f4SXN6Fe1xd	NFT #15	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/15	A1hb6VgugqDRKT6xmgx5fG36F2vZF8fJtWorUKKjTKTn	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
552	Ar9aiuZibojcgBvRv4nRbqhho7kq6YTdG5EgdrWtyDFx	NFT #38	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/38	FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	\N	f
571	3h1g3oepetNE94yk2vCzbRfvwVm6ke1sC9oab3u49dnz	NFT #25	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/25	Es8uorywaftETgtQxjUvA6mGzuYwXJA7V6zKn65mYxNw	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
572	3gtMrfGvtf3vX3Vq87EFciNpFofQAPipURBKpMESi3An	NFT #2	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/2	D6NdBATavTnzPThqYYnjZ7ZVfT9LnfN4qBoX9ZtmF4VC	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
573	3YkqMzEvTNywjLwgwBGR8w9WMKNBoANGJdJCoUgoxXmQ	NFT #21	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/21	HcHa65RzujcPmrb2UatobG17BuLKBVyqZckEUiTTYJuB	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
42	Fmb3Pz8QXy8JHjSaDtc4852fJQpspCurc6dpjU8qNDKj	CannaSolz #12	CNSZ	https://gateway.pinit.io/ipfs/QmdhHeedQzBj31fLwAmenFaA5y7XGRdr9LDQnZk11sLrwn/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/11	AHb75NRwSuvDEXqwsDN8kg277taq1iHhzohWUZF9G4P5	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
575	2hfXHWbt3eLWPVN6vzEL7gHWGxvSPNNeXd32CKDxhAVH	NFT #9	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/9	A1hb6VgugqDRKT6xmgx5fG36F2vZF8fJtWorUKKjTKTn	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
577	ymk3yMz54JzHuL9yLPx7rc5XQ8UZeSjyKiuLRxtsXXS	NFT #20	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/20	BR8h8qiA7jDFhS8UeF3ioMEbc5pALDM7WimToNnur8Gh	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
578	pmARbtYtj8VCvcQ9QV6cFR8rFPJKssXEZVTqeLzQCxf	NFT #14	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/14	G4KnzkwCkK2dNxeazGbxnTtkwnwC1QWg6ey6LEVEWpCZ	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
579	Hqs1zXXZRFfcHFh4cKh6veDBnde9UM9AaiLMqhENn7Ns	NFT #1	seedling_purple	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/428ba47f-02bf-4f40-b2f1-cc651d26f9fb/1	G4KnzkwCkK2dNxeazGbxnTtkwnwC1QWg6ey6LEVEWpCZ	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
45	FdtTNCN5scCcXVgkEKDW5iQzhd1YZnUpgLCYW54Skis9	CannaSolz #238	CNSZ	https://gateway.pinit.io/ipfs/Qmcej344ELdapWsPTnQXty2gGN2diP9fAR83iccsuTfDi5/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/237	66EMDQEr8uGn28fXKgfmA8noN1qr3su1VpNzM9DEUC7o	\N	\N	f	\N	0.166981380	\N	\N	\N	\N	Light green	t
581	GDLHtsNKxicWRDcg2NRcQPPjm5VsBC4ot5a1wDqzN8Gi	NFT #14	seedling_purple	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/428ba47f-02bf-4f40-b2f1-cc651d26f9fb/14	G78WjHbT7PqCagaDXU5Zmhekcdi9Pu2Pnfoxofg2swnA	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
582	FsdzUbSRQZxejhxCVsauz97MaDZLDHxAXfbEaXfjNeSi	NFT #15	seedling_purple	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/428ba47f-02bf-4f40-b2f1-cc651d26f9fb/15	D6NdBATavTnzPThqYYnjZ7ZVfT9LnfN4qBoX9ZtmF4VC	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
583	FEJTfW9NGSLbDvgU1Z2j8iE7wpGdztGssZigbGAi41Zw	NFT #19	seedling_purple	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/428ba47f-02bf-4f40-b2f1-cc651d26f9fb/19	HcHa65RzujcPmrb2UatobG17BuLKBVyqZckEUiTTYJuB	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
584	F4Rfmh8Pr2nQqjWfQrgkthuFMucp5EPEtMJYCKBgXXCP	NFT #20	seedling_purple	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/428ba47f-02bf-4f40-b2f1-cc651d26f9fb/20	HcHa65RzujcPmrb2UatobG17BuLKBVyqZckEUiTTYJuB	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
570	3omhwWayARMTH9ZD2B7ZfpvuWaoonuSBV1B3xomXtvwW	NFT #34	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/34	FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	\N	f
590	B2ezwpRYqZCckBRDDwRqdNcfnc2FfrQGD5N8LBNUt6CP	NFT #18	seedling_purple	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/428ba47f-02bf-4f40-b2f1-cc651d26f9fb/18	6SMH9uvR3UEo2XUTUGJ8x1FXwDX1SCF6t7d1FK3pZuN2	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
587	D5ryzRaYPQJwAAUWYj4SwDKAJEdyX2DwtKwgnG1D2L1z	NFT #4	seedling_purple	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/428ba47f-02bf-4f40-b2f1-cc651d26f9fb/4	A6w5xnT64gbKQynkPmcPuSXiy6sUNK3cJpzdUTQWSrMZ	290531269970755587	gob.1.	f	\N	\N	\N	\N	\N	\N	\N	f
574	2tvxdL3NPh4BKF8DofMuKGZoiG6nbAq4rwEvMqTwS3ba	NFT #39	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/39	FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	\N	f
580	GS5SX4aAyYRXJjEjYFiuX2fziqCV4MJdpJWSnAYrZsmz	NFT #25	seedling_purple	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/428ba47f-02bf-4f40-b2f1-cc651d26f9fb/25	FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	\N	f
586	EpzE4hdQBzzXYzYiFRWfCsGZKFDZAhh2GFLBc7t7Bqfi	NFT #24	seedling_purple	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/428ba47f-02bf-4f40-b2f1-cc651d26f9fb/24	FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	\N	f
591	9my8T3FPnm7poAsHqV42RmMTHXDK6nnapSd7QszSvquL	NFT #22	seedling_purple	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/428ba47f-02bf-4f40-b2f1-cc651d26f9fb/22	6SMH9uvR3UEo2XUTUGJ8x1FXwDX1SCF6t7d1FK3pZuN2	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
592	9hvPAyHCQ6yybMfM7zazWRP6yiqHKLMSoQ2iq9xktCf7	NFT #12	seedling_purple	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/428ba47f-02bf-4f40-b2f1-cc651d26f9fb/12	9xiDUvtguHAVMAggcYsvxaJAKwDJeJFNSqa4t6okXKUY	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
593	9DLiYkahYHptKQxgikjN5E7NPmiWijvjhFdZDjaLstTJ	NFT #17	seedling_purple	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/428ba47f-02bf-4f40-b2f1-cc651d26f9fb/17	HcHa65RzujcPmrb2UatobG17BuLKBVyqZckEUiTTYJuB	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
595	6djrK2xGPNbjGonjRVBkrpqQibJPvqnDrYUjVpcZyQin	NFT #16	seedling_purple	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/428ba47f-02bf-4f40-b2f1-cc651d26f9fb/16	BR8h8qiA7jDFhS8UeF3ioMEbc5pALDM7WimToNnur8Gh	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
596	6N26BLiJXw1iXjkK7byNTSa8KsjWhRbthDnz6gUhUqUX	NFT #9	seedling_purple	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/428ba47f-02bf-4f40-b2f1-cc651d26f9fb/9	BR8h8qiA7jDFhS8UeF3ioMEbc5pALDM7WimToNnur8Gh	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
597	68Rnr1qN3u2iUkwbCveXFa5Czq4GtLbpp3S3u2zPKfZT	NFT #10	seedling_purple	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/428ba47f-02bf-4f40-b2f1-cc651d26f9fb/10	5hPtBzn75mq5kJfTRHb5oT17hJxdSqQg4MS6meoy8dVD	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
598	3CqYF2cLTgKygWMc3Z36N2poqRX6X7cGEZonx3sa28UK	NFT #23	seedling_purple	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/428ba47f-02bf-4f40-b2f1-cc651d26f9fb/23	Es8uorywaftETgtQxjUvA6mGzuYwXJA7V6zKn65mYxNw	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
513	Hwam8BpGb2mm7Rs5yqauFRKwuGB4uxXuJLEY4vbhZBdy	\N	\N	\N	\N	\N	\N	6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
600	32KYktzL4xx7wmnzdBMcfqpeMpTWDzQ66hWHnLj1nFMm	NFT #11	seedling_purple	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/428ba47f-02bf-4f40-b2f1-cc651d26f9fb/11	GExJDDpdMvVjQMtbK5o7kfozz3tmWSSJPS2q97xH844X	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
46	FbhzwUA6MnUJw8xd5WFKUPXyWN9ATCKYEy6WB4zHoVmJ	CannaSolz #34	CNSZ	https://gateway.pinit.io/ipfs/QmW2BCjCEWmaLbXJnV1pzZqLqQQ6x9JxSaS9R4Naw4SqDF/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/33	43GbnpZ8WtFf1Me78CXCgvtBjkMW7Wt5qBHtxW6dg6yP	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
601	2y59mfgdB5LcNsKqdpKBbdTYozTYoX1epapFMWJ1VW9p	NFT #21	seedling_purple	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/428ba47f-02bf-4f40-b2f1-cc651d26f9fb/21	6SMH9uvR3UEo2XUTUGJ8x1FXwDX1SCF6t7d1FK3pZuN2	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
602	2FadZXwM2TxKpEAWwu4jhjhW5Fyj6mYoCoEbJkqaxvHj	NFT #7	seedling_purple	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/428ba47f-02bf-4f40-b2f1-cc651d26f9fb/7	D6NdBATavTnzPThqYYnjZ7ZVfT9LnfN4qBoX9ZtmF4VC	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
44	FjCDTmCfzZNSQMMFQCX2caknQy3unRctuwEuBa67iDnc	CannaSolz #37	CNSZ	https://gateway.pinit.io/ipfs/QmdvXghPi93hedBiXQ7gZoKqRWK5jKxoEMnEtHNE8q6jrf/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/36	B5ZCWUT9xb7FgKe2mmesMc7rEEaxUZ5ShTRnYUz6udZA	\N	\N	f	\N	\N	\N	\N	\N	\N	Silver	t
603	XrKXUnz1JHYpoVA6gL6zHvrr2VnzWGwBrNkdmCQgAWJ	NFT #2	seedling_purple	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/428ba47f-02bf-4f40-b2f1-cc651d26f9fb/2	DSfAWGkMcpeN18vXioNkGWGKywYTKFH4DXdLsVav6Bqa	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
604	1m3MSAuGvKdsAkYw1xDZprVExPAvzihpBKL7PB45MdN	NFT #13	seedling_purple	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/428ba47f-02bf-4f40-b2f1-cc651d26f9fb/13	C9xiFhke9pTU89YdNoLskuA64YNScWF42dmCJach13yh	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
605	HD58hhRqatK7TGY4hkAsXcAFDnDgnkihGu7DuSYwV8J3	NFT #4	seedling_dark_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/3befa941-9417-49e2-bfd5-e06c43cffca2/4	BZ449ifq2FvMDm8MPwkwtxviFXwQsWsX4WmSMNUBoj1Z	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
606	H6rMThNxo6wr85qDLofEKs5gvizcAxfS7EzDzJPH7wZ8	NFT #3	seedling_dark_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/3befa941-9417-49e2-bfd5-e06c43cffca2/3	BZ449ifq2FvMDm8MPwkwtxviFXwQsWsX4WmSMNUBoj1Z	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
607	GhkbJfJjKJWwhrwd1Xc98n9v1FRNWq7hbnLAdypntV4G	NFT #8	seedling_dark_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/3befa941-9417-49e2-bfd5-e06c43cffca2/8	A1hb6VgugqDRKT6xmgx5fG36F2vZF8fJtWorUKKjTKTn	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
610	FXbJ2MNcQmRKhs3KSNoKPHPEM8d2wt2r6pEBMXkbAmZo	NFT #16	seedling_dark_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/3befa941-9417-49e2-bfd5-e06c43cffca2/16	HcHa65RzujcPmrb2UatobG17BuLKBVyqZckEUiTTYJuB	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
611	EmAtfZ2btMHcQRUyAuPU6sgyBB6NbXQ18gdYgD8FXDpM	NFT #14	seedling_dark_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/3befa941-9417-49e2-bfd5-e06c43cffca2/14	G4KnzkwCkK2dNxeazGbxnTtkwnwC1QWg6ey6LEVEWpCZ	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
613	DNGr7eQ3Vnv8WbmaBSb3U9r67xRNa3LsG3GsgRijzAQ3	NFT #6	seedling_dark_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/3befa941-9417-49e2-bfd5-e06c43cffca2/6	D6NdBATavTnzPThqYYnjZ7ZVfT9LnfN4qBoX9ZtmF4VC	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
594	7R3AsMvhZZEsCqKqU5T2Aam5zQior4F62Twxy5RjNyJz	NFT #3	seedling_purple	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/428ba47f-02bf-4f40-b2f1-cc651d26f9fb/3	FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	\N	f
608	GFddFv7gXb7qAJvySqcJbRme8T3UwVfnV915tEHEyaTU	NFT #21	seedling_dark_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/3befa941-9417-49e2-bfd5-e06c43cffca2/21	FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	\N	f
614	CGbphUX3ZurnyU3FZPjHKYMYLy5naTmWCrGSobTj15XZ	NFT #17	seedling_dark_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/3befa941-9417-49e2-bfd5-e06c43cffca2/17	6SMH9uvR3UEo2XUTUGJ8x1FXwDX1SCF6t7d1FK3pZuN2	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
616	BmbZwHMewrMSvsBJ5UXCeEHKRGimV8BCze2a2UAM92x3	NFT #20	seedling_dark_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/3befa941-9417-49e2-bfd5-e06c43cffca2/20	FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	\N	f
52	FQ7QmKVG5X13kLu5vYsSjVcJYNB6rgFrPkjiQSkhR5eV	CannaSolz #221	CNSZ	https://gateway.pinit.io/ipfs/QmcgpRQ6TXH8dNe3KAZWu7EQ3wG4if8w6yTA5SPyfasgYF/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/220	66EMDQEr8uGn28fXKgfmA8noN1qr3su1VpNzM9DEUC7o	\N	\N	f	\N	0.167048880	\N	\N	\N	\N	Dark green	t
617	APwv8RYeDWHrASt3s7Yasw8js8tNfkpGevmZZGx7dYXK	NFT #9	seedling_dark_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/3befa941-9417-49e2-bfd5-e06c43cffca2/9	GExJDDpdMvVjQMtbK5o7kfozz3tmWSSJPS2q97xH844X	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
139	8xvxAtco4ePjEbVLtkHWgGv1x6P57Um6vmLQAbRnYKCt	CannaSolz #120	CNSZ	https://gateway.pinit.io/ipfs/QmRmLFgGtZEfyoc1W2wYFrg9pudJfoCFhNVMDvJMLz18Wy/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/119	Dxmt3kvYbecfWhUL2W1SbR9xLUtukGStyi5z9R4zVEV	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
618	9J5EpjTpnuBrqB6gb5hSztxUtEf9oJzyeELUan9Nmwj9	NFT #10	seedling_dark_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/3befa941-9417-49e2-bfd5-e06c43cffca2/10	G4KnzkwCkK2dNxeazGbxnTtkwnwC1QWg6ey6LEVEWpCZ	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
144	8YhjGFJYRsVn3mZRT6ppD36eyAizBpioNc3SjjDtYhbH	CannaSolz #83	CNSZ	https://gateway.pinit.io/ipfs/QmSPDYgLEehcMMhw3xpm2VA3HLRAKNfrvzuqiieeMPwXxG/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/82	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Light green	t
76	DVVFERGEPfjGNYdA68wPCYf2qLoaijbG4SkdvkzyyJir	CannaSolz #52	CNSZ	https://gateway.pinit.io/ipfs/Qmb76Gx8iykNobYKRjWJ3Dj2boChL16ZdSh3CNhVi1vad7/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/51	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Purple	t
93	CRMSwdvafua2kmSe6bqso4tzqxJcWcMdBnsacPdjsZZ3	CannaSolz #13	CNSZ	https://gateway.pinit.io/ipfs/QmaR2j93AEu3qpH6Ax2Y7Lzwkih8wxkBvrWCppMCdhBaBL/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/12	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Light green	t
31	GJmq9yKmx56kEWaNgThmtybZAYs9zGGhG1BJXyWWyJAv	CannaSolz #81	CNSZ	https://gateway.pinit.io/ipfs/QmSQ7UDZE2rooTMBo2tn6Mc5uUVsgQhXnm5qJJ4DNTMQi8/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/80	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Dark green	t
64	EYcGY8bZDQ7NTA24kGDhdTs1qmb7Mx2nFU3zMtv7NDvb	CannaSolz #62	CNSZ	https://gateway.pinit.io/ipfs/QmQez65ZMamCf5vx7vxXfx2Uxr6kvG2ujegw4NkSP4T6B9/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/61	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Purple	t
158	7pekRzAug6UP9NdZF6XecTkiakBiuzM5avJHA47uvueR	CannaSolz #208	CNSZ	https://gateway.pinit.io/ipfs/QmYwyj9d5NPKi8h6oCbKhZhocHNZwCYrpXL62TdZMLANHs/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/207	A1hb6VgugqDRKT6xmgx5fG36F2vZF8fJtWorUKKjTKTn	\N	\N	f	\N	0.167048880	\N	\N	\N	\N	Dark green	t
619	7vogPt3qdqx5GY2Z28UaaRscDx9GunWwQLdFYK6UaSMa	NFT #15	seedling_dark_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/3befa941-9417-49e2-bfd5-e06c43cffca2/15	C9xiFhke9pTU89YdNoLskuA64YNScWF42dmCJach13yh	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
620	7nuUB5jfs4r5g7RM91JFzSrA22BSHuEhzotRd1R3SkG2	NFT #2	seedling_dark_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/3befa941-9417-49e2-bfd5-e06c43cffca2/2	D6NdBATavTnzPThqYYnjZ7ZVfT9LnfN4qBoX9ZtmF4VC	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
56	FB2B25SxQDQ2mHz2m3PSbLL5Ty1pGYzGzJ9xhLeZtFCy	CannaSolz #202	CNSZ	https://gateway.pinit.io/ipfs/QmYmYPeTMJdwfFvPX3ePStvYErdyzfzxyLN33g4PHFy5oc/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/201	F6dfav2HipYKjDa594uVBG6hhkes5PrM3U2rDebbcPye	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
621	7UuLBus6uNc2f9VLMYMe7TW3mJr2YpBYhiyd5y6QTE8P	NFT #12	seedling_dark_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/3befa941-9417-49e2-bfd5-e06c43cffca2/12	BZ449ifq2FvMDm8MPwkwtxviFXwQsWsX4WmSMNUBoj1Z	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
622	6FjpNdzWEg4Q5KnBS5CeB4BWWandQWBf6Hptp2EEb3zd	NFT #7	seedling_dark_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/3befa941-9417-49e2-bfd5-e06c43cffca2/7	D6NdBATavTnzPThqYYnjZ7ZVfT9LnfN4qBoX9ZtmF4VC	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
623	4tQxg5ZTRHaX9dC7TvNk4VW2jUU3KikkBA3a7QFuQQj6	NFT #13	seedling_dark_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/3befa941-9417-49e2-bfd5-e06c43cffca2/13	C9xiFhke9pTU89YdNoLskuA64YNScWF42dmCJach13yh	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
625	2FdzYb9crQU62LgCZ1qjq8bJoRt93nxN9Hw2HRBm2BXC	NFT #19	seedling_dark_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/3befa941-9417-49e2-bfd5-e06c43cffca2/19	3ernPawEh2g6TxNfCpnrvTT17rX5wEsLsbCm7kEKHiBq	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
626	xZESr8B7EvqydAKyMLVov7qdfjivU2LbJiRa6Yfp4pH	NFT #1	seedling_dark_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/3befa941-9417-49e2-bfd5-e06c43cffca2/1	DSfAWGkMcpeN18vXioNkGWGKywYTKFH4DXdLsVav6Bqa	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
627	EUf2krRdaL63aZUpmmZBuJXtTS2UVDTV8oLWSd7hJNY	NFT #18	seedling_dark_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/3befa941-9417-49e2-bfd5-e06c43cffca2/18	Es8uorywaftETgtQxjUvA6mGzuYwXJA7V6zKn65mYxNw	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
628	J659LuTSowmckAiEWwYQZ88NX7SZF8eer8SS3v9XHutr	NFT #14	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/14	4upHKXZP8996fZgAJERudoMhiDrsCojfjZpAgG6YrQqW	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
629	HzLicJR4V2m6zphZvsjTsM3ZS13ZS9HdhQNHkHoNjg7U	NFT #5	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/5	BZ449ifq2FvMDm8MPwkwtxviFXwQsWsX4WmSMNUBoj1Z	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
631	HDrZoHCYHzixR8xq8fFKiMyrmqsZAVaKFXVvjzvaYp9v	NFT #6	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/6	D6NdBATavTnzPThqYYnjZ7ZVfT9LnfN4qBoX9ZtmF4VC	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
632	GxbeMjryex8UZx81F66Xkb3HDoGKnBaW1x7eth1Z14B8	NFT #4	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/4	CDFQARAF9a4H7x1qMQYKqv8jA1Csaj3c11P3srGAfivQ	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
633	GNgDK7FBw7CtocqDDgEKzgXVaqNnMf96kuKVdwfB8ret	NFT #8	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/8	Aa5xb9Ri7UwmYLvtRsqbVTSiwVvj5AoyQ4Ru31wGPLFW	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
634	G3nFG2FCvpeCxME1E34fbwfFJDhWWJKkvGYtKzscA7eq	NFT #24	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/24	Es8uorywaftETgtQxjUvA6mGzuYwXJA7V6zKn65mYxNw	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
635	CvBrxK76yeBcHfwdqXKs3bMCK7cp4JBFY5cnBXY3quFa	NFT #9	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/9	BR8h8qiA7jDFhS8UeF3ioMEbc5pALDM7WimToNnur8Gh	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
637	CCKRDADgr62hHBQdup1rKrEPyW8pmsP4xbAFfgrcc69L	NFT #16	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/16	DpFELK1DpdKZWGwuPqJ9qaEHQKubFdzWFHuQ3ST2nXBp	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
638	AJz1P9TU8kJaCMPEkTmGYEhKrnhuRcoHzzBT1jEeFvVb	NFT #12	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/12	C9xiFhke9pTU89YdNoLskuA64YNScWF42dmCJach13yh	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
630	HX5HGJHPazVEjvpaianJHSsQ7QNjHpWn69otHofy4SCW	NFT #26	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/26	FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	\N	f
641	971Gczoib34DpNoDfkms5SPV2wgZT2LLabhjEQo6KwHX	NFT #17	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/17	4upHKXZP8996fZgAJERudoMhiDrsCojfjZpAgG6YrQqW	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
624	4oHJQj94qccPKyX7ES5sXJW9VHyXZ4zmtjueYGeN2Hti	NFT #11	seedling_dark_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/3befa941-9417-49e2-bfd5-e06c43cffca2/11	CCACZDCrttZiEwdVQus6BtMWHn6PWsnkqKw77xy7mLj9	392070555102085130	gaeaphile	f	\N	\N	\N	\N	\N	\N	\N	f
642	8RYuRnZ8w1D9DEzruTU3fRcCuVup2JGWK1JFK7zCtQUf	NFT #23	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/23	HcHa65RzujcPmrb2UatobG17BuLKBVyqZckEUiTTYJuB	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
644	8JVg9FRDGJ9oX5nfq955CTysBqqBR5rmYzjdTFnU5TMh	NFT #15	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/15	GExJDDpdMvVjQMtbK5o7kfozz3tmWSSJPS2q97xH844X	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
645	81gTjwiGmViDHmUEaVP4uGTqx7y8CspcheJSbiFPHXvf	NFT #18	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/18	FaocJsFCdryna6982VrRexcJT4KUco9FHqp8DE6nPE4s	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
58	F32ACH7BwfQZavfTr3nX4LhEw9A9qj5mmvaVgV6aafTc	CannaSolz #1	CNSZ	https://gateway.pinit.io/ipfs/QmXFsGmSvBBRpA4bz6TwQWEYZgNapDukYxJUq8WXooDJGa/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/0	HKN4zACpPLhE6CBQtarSfk2Dn45NVVWTKU2RLrtCLdwA	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
59	ErFCD57kZYtLBfxGBM2wbJJFyq6Z9YcRpqtzodYa8d7D	CannaSolz #11	CNSZ	https://gateway.pinit.io/ipfs/QmTuZyvGhsyL3SKenFn2oZx8ZSmoxHTVAUE97dJLaA4zdp/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/10	AHb75NRwSuvDEXqwsDN8kg277taq1iHhzohWUZF9G4P5	\N	\N	f	\N	\N	\N	\N	\N	\N	Silver	t
646	7C5PT2yKu9XrHjpYgsk1toe2YRmBfJxS5vVj2DCvEyjT	NFT #22	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/22	HcHa65RzujcPmrb2UatobG17BuLKBVyqZckEUiTTYJuB	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
66	EQuZnFg6GGFqEtrp2VJRoUnCjvaRjaxhzgwanCqc7SE8	CannaSolz #2	CNSZ	https://gateway.pinit.io/ipfs/QmXX1TruGbd6ZVeT6GyawUGx3xjH4GpbCpchKk6o9LiaPg/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/1	HKN4zACpPLhE6CBQtarSfk2Dn45NVVWTKU2RLrtCLdwA	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
167	6un7gWz92zKghUDfGHYWfJnYSdwZAaRyZjERJMeSD5Jw	CannaSolz #3	CNSZ	https://gateway.pinit.io/ipfs/QmamqGJTM61d6c4T6WiDVWbq1RFuowzHc5WAckjS8ScER5/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/2	HKN4zACpPLhE6CBQtarSfk2Dn45NVVWTKU2RLrtCLdwA	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
648	57CBh9ZejyTAMm9Rmm83Btpp2EXDnxQeeYKUVh61NTNx	NFT #25	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/25	Es8uorywaftETgtQxjUvA6mGzuYwXJA7V6zKn65mYxNw	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
649	4vDPK5Yt44GLBJk1viveAher5471Grwks96isjCZ1S5g	NFT #3	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/3	D6NdBATavTnzPThqYYnjZ7ZVfT9LnfN4qBoX9ZtmF4VC	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
57	F6jXvuvNh68DEmkx1s1erPHdsWsQnH5X898icr5q4soD	CannaSolz #152	CNSZ	https://gateway.pinit.io/ipfs/QmVz53dBZf78TNteLGDLnxvUatp2L1cTi5bkGzXJBfc36m/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/151	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Light green	t
643	8Kmj8D2SLMibF8frzp4Hk6E4BQPs9agEHVLpJyVNPBsU	NFT #7	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/7	A6w5xnT64gbKQynkPmcPuSXiy6sUNK3cJpzdUTQWSrMZ	290531269970755587	gob.1.	f	\N	\N	\N	\N	\N	\N	\N	f
647	72AF2yZXjtZoB9RaQHiEggRVTkPc3zmL9rnhi8JYA9nN	NFT #21	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/21	CCACZDCrttZiEwdVQus6BtMWHn6PWsnkqKw77xy7mLj9	392070555102085130	gaeaphile	f	\N	\N	\N	\N	\N	\N	\N	f
650	3yMPHb26G6uxJLDkSKwKs78v8UgLubnLbS8oXkCFSFgL	NFT #2	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/2	CDFQARAF9a4H7x1qMQYKqv8jA1Csaj3c11P3srGAfivQ	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
651	2X8EaupLr9tXuBRPzjMkt4jPkR3bRKuBnvFvU4pvrk7g	NFT #1	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/1	MS1J8a7oSQJrNJX8ahhew48ihHbxaw36uYg7tS65ous	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
652	tYcRHmvGRMetEWxWcrcLkgFJXquaJHzeL2zp2FKfBHe	NFT #19	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/19	FaocJsFCdryna6982VrRexcJT4KUco9FHqp8DE6nPE4s	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
653	piBHeGeTuSSrxk245m9t7Ve5oRjEJhJtrUeN8dirigx	NFT #13	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/13	6SMH9uvR3UEo2XUTUGJ8x1FXwDX1SCF6t7d1FK3pZuN2	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
654	147F6MepMLgQe6ZDtjLHw6N4PT65c47gbgfTP21qC74Z	NFT #11	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/11	5hPtBzn75mq5kJfTRHb5oT17hJxdSqQg4MS6meoy8dVD	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	f
240	oYrdsehUUK5TKiWXZZQ9YAfysWofRXgoTKXGnwGUsec	CannaSolz #124	CNSZ	https://gateway.pinit.io/ipfs/QmbtRa3eogBPMTeeVyzZk7cg9RELKsymY5ykkCsiJCMMMv/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/123	CJD7gXVNgXpyN8dqx3VMDp843Nc4MFEQAymjEZuSZzX7	\N	\N	f	\N	\N	\N	\N	\N	\N	Purple	t
62	EiK69BPTS12RLMEXYixAj6HoodubgqwkFSTJ4GvM5LGx	CannaSolz #268	CNSZ	https://gateway.pinit.io/ipfs/QmNoDuKcA7YYGda6p3MGRCHAR1Zi13P7xVzmPrJuxYpU8u/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/267	GvxoCvVfMgwdKuUmPKqXnDS5KfiNWNyW2yidvNDXtofD	\N	\N	f	\N	0.165856099	\N	\N	\N	\N	Light green	t
169	6qUHeLsspZN6QYPFTPiPX4sExhVF5KM3s1k3eS48xTMQ	CannaSolz #169	CNSZ	https://gateway.pinit.io/ipfs/QmVC2DKkBpxR6UQBoEWCcu9YW5iLLMBxWv4ATECb8qXExV/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/168	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Dark green	t
558	9G5g3RpTJEwN3xVpTiH8Nt4Ph6CKERohJ8QRShRCNxWc	NFT #0	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/0	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	\N	f
585	F3Ht5Xa9agCF5TXj3ZH1t8dWdgutEokwjyxy7VpadXLW	NFT #0	seedling_purple	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/428ba47f-02bf-4f40-b2f1-cc651d26f9fb/0	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	\N	f
170	6pV1pDUcpFzk8TKANfo88LZ6uHg1gGUAiyV9e647gnZh	CannaSolz #51	CNSZ	https://gateway.pinit.io/ipfs/QmeRntuswja2H1J47BCmEFJGdcqdhqDXdAuzUKUBpYfSek/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/50	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Purple	t
179	63jJ3i5bELgazBi9jQortzueYV6W6PWtcdDGbUNrDtPF	CannaSolz #20	CNSZ	https://gateway.pinit.io/ipfs/QmTth7jDwCb5gtDd24MiuNwmWidQ4sTHrZwcecjw7bvAx2/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/19	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Purple	t
12	HUxALufVurHobZ9jNyrkrdHXDJ5jJKRttMeBstMd3Gjw	CannaSolz #135	CNSZ	https://gateway.pinit.io/ipfs/QmfZtGjzdxLxn2i3fyMVNau3CxCbKE2sA7iHhD9PSNfMi5/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/134	BfBokuitRZSx4wf5v4jBLAp5AGmp6rfS55STzw3UzGJJ	968226679963148318	jeffdukes1	f	\N	\N	\N	\N	\N	\N	Purple	t
182	5pmgpBdabeUAUsNcgssNdgpZsY1HkyK1TVSpXNnEe66M	CannaSolz #65	CNSZ	https://gateway.pinit.io/ipfs/QmexkqJvA31SzNqSg63r7i6e8rpYPGkGYc3L1gbYs8uEVo/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/64	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Silver	t
69	EGJmcVgDGuHtWnovRfyjebeYTgUbtXEzexeYRq8B74gs	CannaSolz #104	CNSZ	https://gateway.pinit.io/ipfs/QmZ6UAou9KQ5d1wELKiA8jgPDsTtWa5syYgJh5mLRSgGiA/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/103	HKN4zACpPLhE6CBQtarSfk2Dn45NVVWTKU2RLrtCLdwA	\N	\N	f	\N	\N	\N	\N	\N	\N	Silver	t
245	cCpPDLdTPyZxP1vWot9bTf4iZAnrwg7D5A2djH2TQmQ	CannaSolz #29	CNSZ	https://gateway.pinit.io/ipfs/QmXtFz5j1haRRg1faoAjDtGKA2jEm2yy7BVbdXyUBEyqsH/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/28	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Purple	t
73	DvrDgMsprTyPXej51ZQBpnLobEcgYyJMMkGAnaqt6WDz	CannaSolz #55	CNSZ	https://gateway.pinit.io/ipfs/QmZudZhaGMuowuCTBxiaNgeJpL5YzFFtLkhe7hD8cJdA4q/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/54	BgEtfZdZ3kSDEYr5GqCCh3HpXwPqV8UShdMzrYkSmEKU	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
176	6KfPu5aDyyHaGvYN4n1RuZohbZjsgrYSjqwkbHy9VUTD	CannaSolz #260	CNSZ	https://gateway.pinit.io/ipfs/QmYqi6diJfqcnBxHBgQ4DAbFR6izAr6SP65xp4aCCdpBxe/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/259	A1hb6VgugqDRKT6xmgx5fG36F2vZF8fJtWorUKKjTKTn	\N	\N	f	\N	0.165209241	\N	\N	\N	\N	Dark green	t
177	6JitJnLd1XncFdYkAztJrBr3M9LCAEzpRyAgWkbV7hso	CannaSolz #102	CNSZ	https://gateway.pinit.io/ipfs/QmUcePEA78C4YX7jF4xeCKLaKAAqreb91Qf7kjeseiqteC/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/101	E28hBxZSjPFPZX4fMNnj2sfU2ENM6cJHyDAWJhNPVu7V	\N	\N	f	\N	0.000000000	\N	\N	\N	\N	Dark green	t
116	AKxJ9scnYu8uk4vJRqr9GeLyLabmpFagbv2vrurjvkbG	CannaSolz #14	CNSZ	https://gateway.pinit.io/ipfs/QmRqPjDXFebv65agPDqoUUJpPuWqXBAdWnDUTSLtxjNMMJ/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/13	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Purple	t
49	FSBzt8EZVzcuVCt3BHpfTzRPinScXvSCQf1vhs2q8NBE	CannaSolz #49	CNSZ	https://gateway.pinit.io/ipfs/QmPdshJrCG9f6bc3wxSRhrntZQjR5bJUJ6FVsBXuvk2NsD/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/48	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Purple	t
205	4VsDwSr1sBNmVtXgms7ppJeGfrVYbB1aethazZNkqZAz	CannaSolz #84	CNSZ	https://gateway.pinit.io/ipfs/QmNr7kcppurxrPR4BEGPbCcmgcSN2ds7NXcWKyrz8NeaMf/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/83	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Light green	t
220	2yDdxh3YfkyjG41mwxzrHNshGdjLApUvWb6bdKGtPdNR	CannaSolz #119	CNSZ	https://gateway.pinit.io/ipfs/QmSfXuk8EpHT9TgP3WzLKUFVfaE1SXZMaL8x2c6chovMgn/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/118	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Silver	t
35	GANvQF4Gsghh5hrNGNj53tg1Z7wXnk7k6vdFBLLrjSau	CannaSolz #18	CNSZ	https://gateway.pinit.io/ipfs/QmccpxQPRuBHpDfJFMpTyjE1X5CxS2kqRN7Qq3coRMddgF/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/17	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Dark green	t
75	DbWkB9TqdNrK4FWncVWZeRWvWpSGgEwSSTqQo5ZmpVuW	CannaSolz #118	CNSZ	https://gateway.pinit.io/ipfs/QmfFKoub1vvaRHqZeGuw2QC8u7pspmXzthwMTdiRHaiAqi/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/117	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Gold	t
121	A9SzCFo3np5mf6NUeMQL3eh4UqqoZCKN4mChiRJrHvjf	CannaSolz #145	CNSZ	https://gateway.pinit.io/ipfs/Qmct3EMEhM1z6msUFcUi9s6y4jVJXXJuMUzz6PXpgQf7wr/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/144	9ckRqNxeCmvezNjQdPyYnAaDvJTfbku2Gn4J4sVqFF6o	\N	\N	f	\N	\N	\N	\N	\N	\N	Purple	t
78	DLTTnok2TBJJz8K47kZRHLYsfBwAaVT17ggPrkZQMgAF	CannaSolz #205	CNSZ	https://gateway.pinit.io/ipfs/QmVKeLxyHC9ZU3hm7eS18ygzSy7BVeXJB5g8GzVxUqT8av/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/204	66EMDQEr8uGn28fXKgfmA8noN1qr3su1VpNzM9DEUC7o	\N	\N	f	\N	0.167042972	\N	\N	\N	\N	Light green	t
196	5ABCkGXkSzy8sTepKrEJEhdPMJFdEaUL57QDU3aFJcGx	CannaSolz #45	CNSZ	https://gateway.pinit.io/ipfs/QmXXmmQho2NcZJrV1UFwvtr4h2jiRusS9Nu1NgN7J6fyeT/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/44	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Light green	t
77	DMJPscAbCoTDrrUoqov5itaDgoKozJ6EJYaz6Jt5UMGU	CannaSolz #228	CNSZ	https://gateway.pinit.io/ipfs/QmQSDEQukdPJ1oBTx5FNjHvszSgSAoFPGD8xUvh8eXbzPp/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/227	A1hb6VgugqDRKT6xmgx5fG36F2vZF8fJtWorUKKjTKTn	\N	\N	f	\N	0.168027853	\N	\N	\N	\N	Silver	t
201	4ckGbRV46767Lq52wD4prr9L8VvXUx5yPsy6FHYN4xxZ	CannaSolz #19	CNSZ	https://gateway.pinit.io/ipfs/QmVUz8fDub9an5sdom6MsZ4vnPJArqi4KUHqawMLG6f2Dq/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/18	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Light green	t
80	DEuvV7GRcqJaGQRPbNWWrsvFM8v4mWT9NqjX6QSim39X	CannaSolz #227	CNSZ	https://gateway.pinit.io/ipfs/QmTZY4EuD742WaTZPQqXSmAofCpRpLEXVVVnQQFAwk3uPS/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/226	CDFQARAF9a4H7x1qMQYKqv8jA1Csaj3c11P3srGAfivQ	\N	\N	f	\N	0.167048880	\N	\N	\N	\N	Light green	t
30	GLdi72LA6JpkrmbdyHY8zpMKD4msYTxJT73yfLT3PMbp	CannaSolz #110	CNSZ	https://gateway.pinit.io/ipfs/QmbtXo8ANZUcdLZNuMXsRqkGV6wMpcDnZC7RB4TexQGiCj/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/109	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Purple	t
83	D4Rm1SfJepBxkUmKGYxMvFg3dP31u7FoaeSyu373cnRe	CannaSolz #7	CNSZ	https://gateway.pinit.io/ipfs/QmbJW7wthkrGnx3iSz2x3sCb6G8Zy6MyfbcR9dFpoqX3nr/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/6	HY2HtZrUkg6ogmh9vk8qS7TQfpH9Pz8aw6wBWiBtPQGn	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
114	AgmrMR4rdvXdaniN7nrw9bAFp97qQ7ZzyKCHYq8d94ii	CannaSolz #78	CNSZ	https://gateway.pinit.io/ipfs/QmVCKwwDSNNn35gNpvTwV56RStWDydPZRLXQPeqk2tH8TV/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/77	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Light green	t
153	82VguS8W8r479kBWjQneJUZsBaYrgVPdW5DkwjfDVpRx	CannaSolz #63	CNSZ	https://gateway.pinit.io/ipfs/QmbmewodiYhhBuDwyXXibtvV7ssVCk8JCTeQ6TuPGjuqVv/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/62	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Light green	t
89	CXtC8tWnZVVcLYJNeeRiQ33awTgqPQnWFTN4Tcba6nUP	CannaSolz #267	CNSZ	https://gateway.pinit.io/ipfs/QmNNMgZPcmKV9cJ5dWLfWTWTF9K6bW5HA2MMqXYPq38qJU/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/266	GdenJQyk5Xwu5wDmJo3Qw28ZyZfnMXn9RFMd76cono5t	\N	\N	f	\N	0.165794110	\N	\N	\N	\N	Dark green	t
79	DHMgfazThV9rCJCSmwvKYk4ara9wniXD2SWkfVvPCnB7	CannaSolz #82	CNSZ	https://gateway.pinit.io/ipfs/QmQEjzg4UgUruzzjQF9CYXeEtGQnqYWeoBmy6FT5aofE9d/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/81	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Dark green	t
63	EcT9xdjzFxtVNFcaUyppJcwz4wes2BFyTMiwB9z1oEEN	CannaSolz #167	CNSZ	https://gateway.pinit.io/ipfs/QmcLFxqPucKYVFR8rLac1oA2GQQ91cmnXSKd2LMdM9kS8X/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/166	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Light green	t
249	TD3Avk9yPTwwkQcyWZ6vWBaygikGTEtf2mxQRo74amZ	CannaSolz #22	CNSZ	https://gateway.pinit.io/ipfs/QmYPDRH64SLBjxXGNNgE14VPxS8AuA63fLYDHqhGsetKxZ/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/21	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Gold	t
3	J94S4tzFx1nPnw7bkgn3Sezk6xi35FFoVamzec3h3gcp	CannaSolz #66	CNSZ	https://gateway.pinit.io/ipfs/QmZGz97qZDoAPx5Bi3cchHe7JkKa5BmjDnWmo9jBY9k8KN/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/65	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Light green	t
186	5dHWx2fcYcyfMa8pjrQZXwguh1sivYssaFKroDLjrJ4i	CannaSolz #241	CNSZ	https://gateway.pinit.io/ipfs/QmeDukdPNgbbD2AiMDpX1Ha6Z275nGJAzR4VJoKaUdk6ds/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/240	66EMDQEr8uGn28fXKgfmA8noN1qr3su1VpNzM9DEUC7o	\N	\N	f	\N	0.166909880	\N	\N	\N	\N	Dark green	t
147	8NvCx3dXwnCXuNgixKpC8um5TRoyaizbwTi9QvrE6YA2	CannaSolz #61	CNSZ	https://gateway.pinit.io/ipfs/QmZWAANUHhgjZiCS7sKnk1bbi8xW57qjB37xiwugeA93ES/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/60	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Dark green	t
133	9PjJxyMpn6YnsfUqvr9K2NaLPtD4GzgLdReyxhVb61nK	CannaSolz #47	CNSZ	https://gateway.pinit.io/ipfs/QmQnY9HkJBdGxFXmzn34MmdKtvmQB91SG4XqbbjkPRRfxQ/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/46	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Silver	t
190	5QKhGFed8mdGpFgV53ypsiMgL4XiD6tBKXNiyofFgvSk	CannaSolz #9	CNSZ	https://gateway.pinit.io/ipfs/QmTTS8NMRqep8ypCii42DySRGyfaWRy5Szvui1bzU8U285/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/8	AHb75NRwSuvDEXqwsDN8kg277taq1iHhzohWUZF9G4P5	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
221	2x1h4UEL8Jm4Hh1JWRGTMkeuHmun4E4GrBh29RLS1UBC	CannaSolz #207	CNSZ	https://gateway.pinit.io/ipfs/QmeCdkfZmEmyW8PZAsmQ8J8H52YyVV5cHqViE9CUEqqGVW/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/206	A1hb6VgugqDRKT6xmgx5fG36F2vZF8fJtWorUKKjTKTn	\N	\N	f	\N	0.168023280	\N	\N	\N	\N	Purple	t
192	5HJpQpb3ZnVNhygb7SXsxFYTmzdmcoYVFJYMGiMZMfhc	CannaSolz #21	CNSZ	https://gateway.pinit.io/ipfs/QmbsXv3BfepSTFNBPPNuj2ZsnifH7PmvKknVAHhWYasF45/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/20	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Light green	t
159	7kX5fxBj9CNSrmMowXAv52sKKwfRMfwgvCXTrLWnRiXj	CannaSolz #15	CNSZ	https://gateway.pinit.io/ipfs/QmZdmn6Q2LJvihomc1DPkmV5K3K4ak41yByYAZWnM9pg52/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/14	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Light green	t
100	C9Q34dLY8CRrUtkFMWWCgQxr8Vrq3WnFTBNQWPH3dkmC	CannaSolz #69	CNSZ	https://gateway.pinit.io/ipfs/QmYVJTFgfrhg5sKndEpWinbvzYPVug9b25SPWJXRdb7Vfb/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/68	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Dark green	t
36	G7TWzh1tn2FPAaGNfFJ6XkaxRUCP9XvYKeLWRMEoiSEZ	CannaSolz #50	CNSZ	https://gateway.pinit.io/ipfs/QmWVZJS1XRaG7J6Pj5vEDzRKYWnuYG88Kafs61GwMP6Mcx/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/49	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Dark green	t
238	we3GWM16rSzhSQfyMTTzePEUQqQXwrt8qhnmRz84sSC	CannaSolz #67	CNSZ	https://gateway.pinit.io/ipfs/Qmb2oePyaPAwSACNGe13cqwYGz9SyVf8WuoWzCfmXi5nbi/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/66	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Dark green	t
207	4KDuw9d2eX9euzgfqEDwEZKU8hLgScZBBRNwqXXmv3zo	CannaSolz #48	CNSZ	https://gateway.pinit.io/ipfs/QmcfSnvC4756UpUStFpQNRRPt6KrB2risKsPmSWxkddXGi/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/47	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Light green	t
82	D6DJLibjMS7i8p6QJCP9q4bRW61T4AJKM5Bus7tchpWP	CannaSolz #10	CNSZ	https://gateway.pinit.io/ipfs/QmeKDx1b6jvD7QbZGXMQmpFmQhcrQYhGC6jZA6z1qZtZEu/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/9	AHb75NRwSuvDEXqwsDN8kg277taq1iHhzohWUZF9G4P5	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
85	CrLRPwJVc7nCDkyeUBzNeEKsnB5k6GnkDo2hKbQypp4N	CannaSolz #133	CNSZ	https://gateway.pinit.io/ipfs/QmdbXUCtRsG86beMV23Hu3eydeeY5gsBpi5E9ppZ4xJFMy/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/132	AHb75NRwSuvDEXqwsDN8kg277taq1iHhzohWUZF9G4P5	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
189	5X3Mbv6w2iQN9neWvHvCFkxMBKspJo9CMzwWKooys8oD	CannaSolz #79	CNSZ	https://gateway.pinit.io/ipfs/QmXqniBKoaqZiiRZKGA4ghJYEvPhBVq6MTGRnMnMpdiGFA/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/78	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Light green	t
94	CQVFc5nFoh7aHuDt66ZDDwETrqAipTLCz23nhie6Y9mM	CannaSolz #64	CNSZ	https://gateway.pinit.io/ipfs/QmNgP13v8ojU8DhXZMWLmpsgmTDdoyVadrue2kDryo4hhf/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/63	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Light green	t
239	pshLjLZHrULfExDRLg3YyVoYwivSS52aRxxycM5PdS5	CannaSolz #70	CNSZ	https://gateway.pinit.io/ipfs/QmNds6LkKL25eqqhR4ypqh1RaCX7JJPZFdqcqqmeysvgxi/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/69	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Light green	t
96	CCkviCEEVoCRz7umB7hoEx5wi7qsbuRrWhVwQ2BDQZAK	CannaSolz #269	CNSZ	https://gateway.pinit.io/ipfs/QmRUQ3G85jaRaHpnoSFCZ71VSSwE8nC87zo4akEgD1MwoU/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/268	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	0.166378640	\N	\N	\N	\N	Silver	t
95	CLc4MuFHKpnkDM2w6anJeu5KtxizZLMpiuH5THmZRdpT	CannaSolz #161	CNSZ	https://gateway.pinit.io/ipfs/QmVYZoRBD4XTVT8S9ar5DuGjW8ZghdrAgi7hdVyYjcpDph/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/160	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Dark green	t
195	5AwEBT4Rkj3GLvHXn5F9bHiYcoazBfpGnPK28aNi1d6P	CannaSolz #275	CNSZ	https://nftstorage.link/ipfs/bafybeihyyrc3wuqt7hws66xo5gynvm3pksukfkkxqlklnkojel4tsle7am/274.json	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/274	xU1YrL3U99tUmbkHia5FSaoFA2FQuQwkSJFeSZyZzGU	\N	\N	f	\N	0.165566859	\N	\N	\N	\N	Dark green	t
173	6RkUibXqFb5JAUaT7XssMvYgawdhzd8UAykBTDEvypth	CannaSolz #263	CNSZ	https://gateway.pinit.io/ipfs/QmWQyGfsSQujLyfMHNL2NHADM5mSnSqPwKzhTbvK9L8Sjm/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/262	A1hb6VgugqDRKT6xmgx5fG36F2vZF8fJtWorUKKjTKTn	\N	\N	f	\N	0.165404240	\N	\N	\N	\N	Purple	t
22	GvdaCX5CfAkqNNiyv6ubo1zotV8aLfbFiA44KA5bw6Pd	CannaSolz #201	CNSZ	https://gateway.pinit.io/ipfs/QmYSUpmFdmWZeMi6kNWcAGiDVkVvG5PsPeXJEpq2TA11pK/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/200	AfVXtsmsbmeVDuYSTdEQdiJsYKsi8EKZEdzoTmRb8mQ	290531269970755587	Gob1	f	\N	\N	\N	\N	\N	\N	Gold	t
48	FUZnS43kuXDqUhEGmtg1zTJxoP2MpLKPVkqBBRauQcEn	CannaSolz #158	CNSZ	https://gateway.pinit.io/ipfs/QmSTR6nYKC6ti52fakBcbBLTTpCbib2CBALWh8ZSx13tD6/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/157	AfVXtsmsbmeVDuYSTdEQdiJsYKsi8EKZEdzoTmRb8mQ	290531269970755587	Gob1	f	\N	\N	\N	\N	\N	\N	Light green	t
103	BvmXSjtf5cE39TeG97DfLv7XDfigD2q5Yqpn6YW9vDLH	CannaSolz #210	CNSZ	https://gateway.pinit.io/ipfs/QmaN5WRBvEdZm8wBXZBJN8jmf2KnZHAz8AmTptjD1XzzdC/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/209	BZ449ifq2FvMDm8MPwkwtxviFXwQsWsX4WmSMNUBoj1Z	\N	\N	f	\N	0.167048022	\N	\N	\N	\N	Dark green	t
105	BnYfMBJgtHQBZjfRifxGKCaSXC7BJeNVd2BJmwAh7PcX	CannaSolz #73	CNSZ	https://gateway.pinit.io/ipfs/QmXezV2Zx2c4ZNPCH37xCFcGtcxdvUyBJ2CXyDhtqoZBjx/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/72	BEytQkVa6yoo5moNsnCfBEekY191FQKEZc1ho6KguGS1	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
104	BuDFEBn3HBah4L3jUg2DXEsn7QzsNguKSTvAfBEoyhWv	CannaSolz #41	CNSZ	https://gateway.pinit.io/ipfs/QmYfLz7qH2zbTptqKKTMDbnrcsvWM7d9eQmWwzYE7VAc7f/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/40	HKN4zACpPLhE6CBQtarSfk2Dn45NVVWTKU2RLrtCLdwA	\N	\N	f	\N	\N	\N	\N	\N	\N	Purple	t
191	5JLSR7EqVeKMNAfoR74KQ5Z7GxDXzq6x1i1bCphJvGxT	CannaSolz #261	CNSZ	https://gateway.pinit.io/ipfs/QmPArMCbAPVZTLkFMRkbVCoT48LhYQZyiqAjYgiqHaB8gV/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/260	A1hb6VgugqDRKT6xmgx5fG36F2vZF8fJtWorUKKjTKTn	\N	\N	f	\N	0.165209241	\N	\N	\N	\N	Dark green	t
88	CbbH9HYGSHzwb9q3uRDnYCUiVx2kxrf2DojcL8Y9HPQ8	CannaSolz #80	CNSZ	https://gateway.pinit.io/ipfs/QmSW9rDJUuJSngUCBa41xH4dCY4Ri4kp7ipTTY5vrFuvqV/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/79	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Light green	t
102	C858eMZwa8DHCUMXvaf95Qk5ADPBmB5MohN63RnefSq3	CannaSolz #106	CNSZ	https://gateway.pinit.io/ipfs/QmXhPdhH69ihjNmTayK1ZzvoFRrYdHtq3CEeteK2eHVQ73/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/105	BfBokuitRZSx4wf5v4jBLAp5AGmp6rfS55STzw3UzGJJ	968226679963148318	jeffdukes1	f	\N	\N	\N	\N	\N	\N	Silver	t
532	4N5dna6PGnaEDKGpcWp35QRZRpzuiGEjFe78VaPFgYHv	NFT #0	seedling_gold	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/8928926c-567d-45b5-889e-c7c3c1112901/0	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	\N	f
47	FYdUT8ARfzpmV728nDKDpuZXfFBduvHV62t1DDpG43tb	CannaSolz #154	CNSZ	https://gateway.pinit.io/ipfs/QmPfZjFTp3UUx9MSsTNk9FvRoJz83M7fVW977CzWxFkhaf/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/153	AfVXtsmsbmeVDuYSTdEQdiJsYKsi8EKZEdzoTmRb8mQ	290531269970755587	Gob1	f	\N	\N	\N	\N	\N	\N	Purple	t
108	BDw8pnb9afFeBuTGweLrp1Zaid8S6xf9x8KpdvU8Ug3e	CannaSolz #270	CNSZ	https://gateway.pinit.io/ipfs/QmVbm34DBy2bfm4oqeWBFts3CBN8Vs9DYZE6zsQ3FyW63r/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/269	A1hb6VgugqDRKT6xmgx5fG36F2vZF8fJtWorUKKjTKTn	\N	\N	f	\N	0.164585240	\N	\N	\N	\N	Light green	t
109	BD1cuqLcary7osbhWj6L2bnyDCJoukGtK8Aai8e8e2Cg	CannaSolz #129	CNSZ	https://gateway.pinit.io/ipfs/QmcDQaEApj95ziTmN8a4yVxAehaUTxqpcYNXT76cs3vTn8/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/128	Dxmt3kvYbecfWhUL2W1SbR9xLUtukGStyi5z9R4zVEV	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
640	9FYL5XeSkkNP4LKtFrpu73M3WnRLcgdNu6zyJ9WB6Pyn	NFT #0	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/0	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	\N	f
21	GweSXPdrEWCyYfUPpErQjo168Zc765M2WAUWhiu9gnzg	CannaSolz #87	CNSZ	https://gateway.pinit.io/ipfs/QmeakHufYBaodesojUTdXxpmZmNZm3wMtG7tZZNbHkvPMg/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/86	GZX1WdQrNMTk13XdSSWyL1BZFEAzXLkVmKimprpMwM7r	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
106	Bkmbhgy2NzsPpf2Dg53BZv6yrJaw1nb3C2aqTJZUq4NV	CannaSolz #164	CNSZ	https://gateway.pinit.io/ipfs/Qme3wtBczbkLBtwLkBXDutGQSjGKifHBdAQxkuoBWZuzL8/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/163	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Purple	t
118	AGumW2sf3LHMhFXABTtAMXJRZYHZeceznKEksep5cn8b	CannaSolz #175	CNSZ	https://gateway.pinit.io/ipfs/QmV1e6iin7yD9ho12RP7wUJcEhEV3RyiqR7dz75vJ3eohq/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/174	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Dark green	t
544	FGrFpaRf6g4s9qkFzhMJWmKYnNwLDDWjcrNCCyaSqkpp	NFT #4	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/4	A6w5xnT64gbKQynkPmcPuSXiy6sUNK3cJpzdUTQWSrMZ	290531269970755587	gob.1.	f	\N	\N	\N	\N	\N	\N	\N	f
589	BNwTXky65vWfoCp8Sp5cYb7D75re6krWzEZSeU99m8Sw	NFT #8	seedling_purple	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/428ba47f-02bf-4f40-b2f1-cc651d26f9fb/8	A6w5xnT64gbKQynkPmcPuSXiy6sUNK3cJpzdUTQWSrMZ	290531269970755587	gob.1.	f	\N	\N	\N	\N	\N	\N	\N	f
615	Bw3na4ccewqggfqCNBERGdGbC4xQrSgwxSXuEK5mU5Ly	NFT #5	seedling_dark_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/3befa941-9417-49e2-bfd5-e06c43cffca2/5	A6w5xnT64gbKQynkPmcPuSXiy6sUNK3cJpzdUTQWSrMZ	290531269970755587	gob.1.	f	\N	\N	\N	\N	\N	\N	\N	f
38	FyS3zDE57CmepaLvigkzudfVuBT3LcjqT172PazC2fto	CannaSolz #28	CNSZ	https://gateway.pinit.io/ipfs/QmerzPzv97B7PuWvxp3icq8XYnjW7r6vkQiXY3B7wGtDus/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/27	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Light green	t
2	J9C8LfUAE2mimRPQsCNmQ1sYjNGQJ9gp4KfPs9LmbMci	CannaSolz #264	CNSZ	https://gateway.pinit.io/ipfs/QmcgPcjfv9A37hTTLVisuiuWXHAZvDPu15dvJETQSW6pmx/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/263	1BWutmTvYPwDtmw9abTkS4Ssr8no61spGAvW1X6NDix	\N	\N	t	0.988000000	0.940000000	MagicEden	\N	DEN1FhdAWpjf3P1Hz3YrqdVUtuo6VmyMuXQ8NsTbctnq	\N	Dark green	t
119	ACyE99wSFuqqjvijGCJ242Jsoi6vokYE4bM3BzmUP7zZ	CannaSolz #252	CNSZ	https://gateway.pinit.io/ipfs/QmcwerLJauJeWVFPMwb82bZziTYXpRsoKzk5z37bcu1NG6/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/251	AJMMYDyBfnCkNZPrgz5E4QJwoyphVfc6ipiUR8koE6DW	\N	\N	f	\N	0.167533881	\N	\N	\N	\N	Silver	t
120	AA8szvcrgbByETMBT7iYtYdEPzRdZG2SWzRHJYqGEoUH	CannaSolz #176	CNSZ	https://gateway.pinit.io/ipfs/QmT65VcM6N1fod4qAR6yvkqATWSzrES4t1AYCkkfnJawS8/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/175	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Dark green	t
576	2EJvraF8Lo9TkPnFURnT1mzKNjXUDkgSWWAYRkHUV7Rs	NFT #23	seedling_silver	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/2a2abf90-fa32-411d-9f18-5d87fc669838/23	CCACZDCrttZiEwdVQus6BtMWHn6PWsnkqKw77xy7mLj9	392070555102085130	gaeaphile	f	\N	\N	\N	\N	\N	\N	\N	f
599	3ANv8Mf18sHWfpSKkQKikYWyQkjxh3DZdWf4ypQ4hxiY	NFT #6	seedling_purple	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/428ba47f-02bf-4f40-b2f1-cc651d26f9fb/6	CCACZDCrttZiEwdVQus6BtMWHn6PWsnkqKw77xy7mLj9	392070555102085130	gaeaphile	f	\N	\N	\N	\N	\N	\N	\N	f
636	CuAaQCuL7PAEEhdckMsW4hb8CGn1ScG4mquzwZeweJiL	NFT #10	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/10	CCACZDCrttZiEwdVQus6BtMWHn6PWsnkqKw77xy7mLj9	392070555102085130	gaeaphile	f	\N	\N	\N	\N	\N	\N	\N	f
639	ACuV4XW6HsXkyGS3mkcAx2rDoiNzRwu21Uba68xtYniJ	NFT #20	seedling_light_green	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/c8d64ebf-e19d-42f8-839f-52098c7a9283/20	CCACZDCrttZiEwdVQus6BtMWHn6PWsnkqKw77xy7mLj9	392070555102085130	gaeaphile	f	\N	\N	\N	\N	\N	\N	\N	f
126	9yYhDrGkA8Xfgm7cjhDNhLGpeDYA4gNQ6FCvKPqui2T1	CannaSolz #108	CNSZ	https://gateway.pinit.io/ipfs/QmTga28TVuyyyNTJ5tshLjZiifwNRcLj6hDFcMsYRSnZB5/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/107	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	890398220600115271	.shoeman	f	\N	\N	\N	\N	\N	\N	Light green	t
122	A6v5woTqVbxe5ymNCXC6dSZcmUQ5wz96rDe2W7Eb7ZPV	CannaSolz #88	CNSZ	https://gateway.pinit.io/ipfs/QmbvzMxPitEeVvPfu5BYJNhPPQ6NpYg2hPGprcUBXYRL76/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/87	BfBokuitRZSx4wf5v4jBLAp5AGmp6rfS55STzw3UzGJJ	968226679963148318	jeffdukes1	f	\N	\N	\N	\N	\N	\N	Dark green	t
150	8A46TeBaifevA1ovsSy7c3PyYeHqM8RafQ7MVxD4yHx4	CannaSolz #170	CNSZ	https://gateway.pinit.io/ipfs/QmWaqbhJBPdNGVPffArcmUvG23iNZN8WVpUS7F237SeqfT/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/169	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Dark green	t
588	BQuwAyKyHFf2Qc2XL8NwAuRzXkTRU4Nuc1qmTjnPzcE3	NFT #5	seedling_purple	\N	\N	\N	https://we-assets.pinit.io/FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha/428ba47f-02bf-4f40-b2f1-cc651d26f9fb/5	CCACZDCrttZiEwdVQus6BtMWHn6PWsnkqKw77xy7mLj9	392070555102085130	gaeaphile	f	\N	\N	\N	\N	\N	\N	\N	f
124	A4QSfBsgbhYrFbgBKCSvM9m9zjGWPAWmaP52yRY82G84	CannaSolz #256	CNSZ	https://gateway.pinit.io/ipfs/QmNSo1PmVXaWPQrAAgrpApaDTU2a16YSecsYH2e6XBsUkG/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/255	4upHKXZP8996fZgAJERudoMhiDrsCojfjZpAgG6YrQqW	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
10	HbLfyWmVGzTRiQPzgCfswGkV2ApQSNnKnkAH3MZcyUHd	CannaSolz #162	CNSZ	https://gateway.pinit.io/ipfs/QmPdW1ty9RBthjXNoarFNXhLHzgfJeUthtPMKJ7KoxeDpD/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/161	Cnu7PM1S9iszcd4LV13aY2FwBeTxwKW6YtsNZCsJfwxZ	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
127	9r2doA26amWuKzdY1mHfKFShvhVnDVj4Y3C3UW84ZqKA	CannaSolz #117	CNSZ	https://gateway.pinit.io/ipfs/QmfYVNzs3w5y8nx52rxeZucyAxmmQZxZurRVKA4HP1Y8Eh/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/116	AHb75NRwSuvDEXqwsDN8kg277taq1iHhzohWUZF9G4P5	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
129	9csGbKWFT5YKgT6gko3mEjMMpRu6ExWoYKognL19SCLZ	CannaSolz #35	CNSZ	https://gateway.pinit.io/ipfs/Qmd6nuToqAE1L3HF3gSMEqLA2RSyYt8YhK9hf45xidFPpt/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/34	B5ZCWUT9xb7FgKe2mmesMc7rEEaxUZ5ShTRnYUz6udZA	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
61	EnUKgRi6RANnxz8zataXWaTGqhxNNt5yGiNubPQUFqU4	CannaSolz #186	CNSZ	https://gateway.pinit.io/ipfs/QmWi8U95My86wcJJDLhaCqJ1pfDEXKPVwsbnQnTWnLWHNM/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/185	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Light green	t
235	ycJocuKb6qUQ7jPnyMXi9PqDy6nmG1brmJMpHfYzQjR	CannaSolz #184	CNSZ	https://gateway.pinit.io/ipfs/QmQLvKU1gM1LStRk3vqFzvboW8n3TsuNgNetndTu3cciba/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/183	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Light green	t
125	9zszmFG84jB8obUy8AgW4Tt9FnaQJuB9Gm68vATqAg8A	CannaSolz #173	CNSZ	https://gateway.pinit.io/ipfs/QmarGnY7NM2fUiuWoVjTekDG7Y6e7xZHCk7T5taxAaQMd7/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/172	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Dark green	t
67	ENArRzZ2pqwEris2Gr4Fn1Hy4APadgodtpc5xZoygTjD	CannaSolz #172	CNSZ	https://gateway.pinit.io/ipfs/QmXutWmULAiRFqugezdNhqYHq2FE9ZvTLT22k4wfoR9fbu/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/171	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Light green	t
134	9KurGd7xtArPcBtvkNKfWgZc9pupiVrCiuPSx8gUL4TG	CannaSolz #224	CNSZ	https://gateway.pinit.io/ipfs/QmVwVJXeY9nEHi8y4V3PwxRFPFLDsEvZpXgMAG2ULXmkbi/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/223	CDFQARAF9a4H7x1qMQYKqv8jA1Csaj3c11P3srGAfivQ	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
33	GGjneuRLa3gTWU3zv2XoBTsgnWN1RGHdXP2Gj3NNeRRR	CannaSolz #196	CNSZ	https://gateway.pinit.io/ipfs/QmYSx2i9YqMPRHKJhbK5A3nRM9YQGwWzr1WvX8jEBDvtGe/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/195	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Purple	t
74	Dr28eVj5kUYZK5YohBCYDygUeNxE7H5hVwcJ8pMqFDiJ	CannaSolz #185	CNSZ	https://gateway.pinit.io/ipfs/QmYZof4KPX82Fra7QKDWLgmPCno9jWg1wcSzhjLQEyiupz/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/184	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Dark green	t
72	DyaQh1sdSvRJoL64hdqNRzB8yu1DPq8RwaeMM8MeZ8N6	CannaSolz #168	CNSZ	https://gateway.pinit.io/ipfs/QmVpXE8L7rdGhdVqUHKbsurvCpjzqB2Ee7tWj65iWaSKjL/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/167	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Light green	t
123	A5Uy7esK6nw5mhmdntxhRL7n8rU5yqYiu9Lp57AVkeDH	CannaSolz #179	CNSZ	https://gateway.pinit.io/ipfs/QmW7KGM3D2icqtnnzR8VmkCUfFQYMySVJ53yFnTqwyrz7K/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/178	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Silver	t
140	8u3ZZNTYmvDo8jkwViHMwr35AZS2VvCxcyB9ttAzbuEb	CannaSolz #220	CNSZ	https://gateway.pinit.io/ipfs/QmeVwEbTGBXVc6m33QugmgTyW9YjFp9JTEBcG8GMR88TjP/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/219	66EMDQEr8uGn28fXKgfmA8noN1qr3su1VpNzM9DEUC7o	\N	\N	f	\N	0.167030309	\N	\N	\N	\N	Silver	t
135	9DVUsYMnWfrftmF32Lw2BG8ohDNNBRULoFdijRPD7N1N	CannaSolz #74	CNSZ	https://gateway.pinit.io/ipfs/QmYnNauw49Xc5Vwo3N6WMdwBgZLa1zK1pAQ2xRTTfKGJrR/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/73	BEytQkVa6yoo5moNsnCfBEekY191FQKEZc1ho6KguGS1	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
138	8yvVhTRDa1R8ZkGr9ri3uRbG2Xs9vLEReezBeVph9WJA	CannaSolz #237	CNSZ	https://gateway.pinit.io/ipfs/QmRjVp5L6ZZPJRKKF36cv1oYouxMic8mYEkhPKUb1ygn5d/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/236	EbB1BrhiUf1r9NG15254n4Yfgn4TX1aZEvi2FQ3vuMxc	\N	\N	f	\N	\N	\N	\N	\N	\N	Purple	t
137	94V3g4921Jpbggg4xnnErpsdQJgyGvPPq62GQTXdnshy	CannaSolz #141	CNSZ	https://gateway.pinit.io/ipfs/QmaT7tjL6fpGCF9HT9Hk5toD5dcj9auvCSr4bLhQhRwCJJ/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/140	9ckRqNxeCmvezNjQdPyYnAaDvJTfbku2Gn4J4sVqFF6o	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
132	9QTjx8b3gTFnjR3ayyZ1EFsaLhd97aYJLQ42ppjxM3Bu	CannaSolz #157	CNSZ	https://gateway.pinit.io/ipfs/QmRGw8xh2zvGK6wKbBvoH3ubP8Qg9RoULnkD7D8T9vtxtm/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/156	5hPtBzn75mq5kJfTRHb5oT17hJxdSqQg4MS6meoy8dVD	\N	\N	f	\N	\N	\N	\N	\N	\N	Gold	t
143	8kKDvSwNKR7HewSMF5umx2fUhq6vZED4egJUjbDV63Yc	CannaSolz #217	CNSZ	https://gateway.pinit.io/ipfs/QmZhz1CPK3HvfWLSB3A9fAM8kahQcCwbwaVgtBjGtyDMxB/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/216	66EMDQEr8uGn28fXKgfmA8noN1qr3su1VpNzM9DEUC7o	\N	\N	f	\N	0.167030309	\N	\N	\N	\N	Purple	t
145	8XAXGLvwo19rY5NLU7nNiZsDRtXVPiJxZxk3B1ohJTH7	CannaSolz #274	CNSZ	https://gateway.pinit.io/ipfs/QmdNacqYjrYrnjA5v7u9RzucxnEVP8CCoxwoL9WySmfRMh/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/273	BSzvE7ocP4NQCbrYzE1XsAXWdiTn8ey4JbaPKwtSLbTd	\N	\N	f	\N	0.164754240	\N	\N	\N	\N	Silver	t
90	CWu5FK9YWLv2nA7EQrzXMFc3ZFnpdHEA6BRAdj4iomGs	CannaSolz #182	CNSZ	https://gateway.pinit.io/ipfs/QmVQeR75iNPoYA74WDswCYdFQvuVeTe6TyyUubp6qMc9TT/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/181	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Gold	t
202	4cAdiBXxx7h2ruKWr89yg2uzwgDiuakaR9m2Y3fQLUps	CannaSolz #197	CNSZ	https://gateway.pinit.io/ipfs/QmQFrxAtMWucXAZ8C6CiJ9cusVGfvkkBhRD3637AhkBEwX/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/196	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Gold	t
87	CnEwLxyjc6xaJUCtzAhJWSqJwJcBoWDfZFgTwaTgRiuF	CannaSolz #156	CNSZ	https://gateway.pinit.io/ipfs/QmbP77nvY1iq7V2jjjM84aU4B8zzoXozNN1YWhe5nvgh3c/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/155	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Light green	t
148	8MV1QQdysn394b79oMxgUJW6CWmmbkJTuJFLz68NZu55	CannaSolz #160	CNSZ	https://gateway.pinit.io/ipfs/QmRShGbViLdoypnbc89cBAerQEDmcTg2GFeD1HkR9zqH15/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/159	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Light green	t
210	3tmkpLoNrrz1Qun113Nbw2rA9fj7fJr6tFFVsk6uTERR	CannaSolz #200	CNSZ	https://gateway.pinit.io/ipfs/QmZZQfgEZnRWEsHpnLq4wXWES4zhAoQMttHyYaG6uwWDem/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/199	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Light green	t
142	8kXn3mn9VcxhM32bBn1RrEc69ucQZkt6udJS9VXaKaUv	CannaSolz #149	CNSZ	https://gateway.pinit.io/ipfs/QmPrbwQzyVMc7PrEUWAqSv8D9NuQx4Jdd6Cq9rH52WmE3Y/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/148	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Light green	t
224	2jLsEtWA6WKXpRguXfmhGchUotbpK3jduHL3f3rPyRTi	CannaSolz #155	CNSZ	https://gateway.pinit.io/ipfs/QmS4aFC5mJkGjiquWf5ahRcfpwD52EjkQA6NaWCk8a2Vtq/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/154	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Light green	t
157	7q4iqdatmGTw6yqz3EcXBWV6k5pbZHCqP9pPq8GiLGMb	CannaSolz #206	CNSZ	https://gateway.pinit.io/ipfs/QmSaiCH7RMw9Hztp3HNoaFCDJcNaNiNTByBKQgSkde3wM3/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/205	66EMDQEr8uGn28fXKgfmA8noN1qr3su1VpNzM9DEUC7o	\N	\N	f	\N	0.167048880	\N	\N	\N	\N	Dark green	t
154	81qRMzqj3m9nx6sz5TkPdG41QEtJhTFncwtz7mz1TNo7	CannaSolz #236	CNSZ	https://gateway.pinit.io/ipfs/QmS83y98z8LvP6zsYZdVPUCGC6FxNwyLCyZjKSVshbC2WV/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/235	66EMDQEr8uGn28fXKgfmA8noN1qr3su1VpNzM9DEUC7o	\N	\N	f	\N	0.166981380	\N	\N	\N	\N	Purple	t
152	83sDTrrcfPXfu9U2QCzb4Kx25uk8XEMMvUGu7TZjpe3H	CannaSolz #249	CNSZ	https://gateway.pinit.io/ipfs/QmRMqYJ3PLVzRKekQGN1oGPBFm9jE1Yy8fUyi8Gs5WyWHB/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/248	BgHcACwthQhFrgfb8KpyTMDFomWcSaQ7zzHQHyyXsZdA	\N	\N	f	\N	0.166909880	\N	\N	\N	\N	Light green	t
228	2MyVDPuNrYjwPoXwQbRJGT13AJMeQR26gBwe1j8J4c98	CannaSolz #189	CNSZ	https://gateway.pinit.io/ipfs/QmZsbMrJViWsWVeZ43HXwwf8ftEcJreTmeyMFHF5iYjwVz/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/188	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Light green	t
165	77tMJoLMh9NUbGwUhaJtmRkZPKBwkHcbCvh2qwBEt1H8	CannaSolz #26	CNSZ	https://gateway.pinit.io/ipfs/QmY8znFQXSDpBqAfYQfnfzJQGiEoBtxjM3ijuDQbiexkNL/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/25	HKN4zACpPLhE6CBQtarSfk2Dn45NVVWTKU2RLrtCLdwA	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
166	6w78TLPEqSMK9qNRtZ3RrPCvrKBA4iD8ruq9nbgW5xcs	CannaSolz #121	CNSZ	https://gateway.pinit.io/ipfs/QmTnmBQLAHioskGJoRtQTRbAia2wQ5pwJbiwKrbLKSQcFo/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/120	GZX1WdQrNMTk13XdSSWyL1BZFEAzXLkVmKimprpMwM7r	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
204	4aGrRxpfJMnY8BnhjjzJeChBCnVwRiH94VJDDQMw2C3t	CannaSolz #174	CNSZ	https://gateway.pinit.io/ipfs/QmbD8B2LEg5h9YhoEPasrDTQZSZGjQYFmT2K9ojLTM2Az7/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/173	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Purple	t
163	7SyxGrauNPfyLKxMgTzQ3eycjMeVbRrFJVeP5hzwUap3	CannaSolz #216	CNSZ	https://gateway.pinit.io/ipfs/QmbVGHSvX6zyVkMetfv8EmV3RXJ1CvUpgT8qVaqCJhuxVo/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/215	CDFQARAF9a4H7x1qMQYKqv8jA1Csaj3c11P3srGAfivQ	\N	\N	f	\N	\N	\N	\N	\N	\N	Purple	t
162	7anfxq5Sp6ovNDhjwKSLSfcQZGMVvweXzUTRfMW827F5	CannaSolz #38	CNSZ	https://gateway.pinit.io/ipfs/QmTBRo9tSvBHZrhdPzspcenYbWpARW9XrpxHiz1eaKy9gw/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/37	B5ZCWUT9xb7FgKe2mmesMc7rEEaxUZ5ShTRnYUz6udZA	\N	\N	f	\N	\N	\N	\N	\N	\N	Silver	t
174	6MKstcpqyJWiXqvW3L5L97YutnktmXQ4SiJ93zu9aS5V	CannaSolz #140	CNSZ	https://gateway.pinit.io/ipfs/QmPtfGxnaXz1NpCKmvVqaTMFn4WJGfHcw4bLt4W9pTDrZq/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/139	9ckRqNxeCmvezNjQdPyYnAaDvJTfbku2Gn4J4sVqFF6o	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
172	6mj42RNMwEmrDxHzDJcXk5MXH4Wjnvb2zXqAXEUwqRvr	CannaSolz #188	CNSZ	https://gateway.pinit.io/ipfs/Qmapgoiiwr1nD2hhDT5BfkWmh1xvNfP9w96oZe25b3bkBh/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/187	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Dark green	t
98	CBifGf9hvhbi3SJYnvxaTjZpiJgUV4ErHAZkstiyuWnn	CannaSolz #116	CNSZ	https://gateway.pinit.io/ipfs/QmY4d6LkcaPLtbDXY7kUeNv7G4w2pJ1hhC5jom34aAm4fL/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/115	1BWutmTvYPwDtmw9abTkS4Ssr8no61spGAvW1X6NDix	\N	\N	t	1.062000000	1.000000000	MagicEden	\N	AHb75NRwSuvDEXqwsDN8kg277taq1iHhzohWUZF9G4P5	\N	Purple	t
214	3TWYHkydYBqM8aD1CZpRypvsMjkVsvUrtJwPZ68cZSZs	CannaSolz #199	CNSZ	https://gateway.pinit.io/ipfs/QmVG9r8m4L3gXMXwpDiPfhnFzGkkyaAyJ17NjfvWnLZdqs/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/198	B5ZCWUT9xb7FgKe2mmesMc7rEEaxUZ5ShTRnYUz6udZA	\N	\N	f	\N	\N	\N	\N	\N	\N	Purple	t
175	6LvmK4zuspkYA25JYVp2MY6Xmn5KF8pcNB3fgmDisLmX	CannaSolz #225	CNSZ	https://gateway.pinit.io/ipfs/QmcTMQMzm2CGx7sXC9EUsn4pWaVYKnWg19RpK7sGujgRfB/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/224	AYsfPAsDyiw1GQpDFYEQBmd6q1QQ28A9pUMq9GNbNBYo	\N	\N	f	\N	0.168036280	\N	\N	\N	\N	Light green	t
237	wqKxynrPnwtgjLSNFFz8LVuiUu9eKPZyAxa3vNFFQ7Y	CannaSolz #177	CNSZ	https://gateway.pinit.io/ipfs/QmQWb1ZpuUXqCwurdwY4TucAi8zChdNRAgWP8auj2kjMts/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/176	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Purple	t
208	43TUYGw2LAV6bJJJMXj1FJfu2vAcmnKMqUJxz1Pubdpn	CannaSolz #180	CNSZ	https://gateway.pinit.io/ipfs/QmaGUUqMrdBBDT1eX8SYEQmS9yVAfU1dU4wZRU7kQwt2fQ/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/179	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Silver	t
180	5y178PHV5QUkFmGPxnx6rq8GXBvHU9UZU9Rm5kD3DXNi	CannaSolz #43	CNSZ	https://gateway.pinit.io/ipfs/QmWJqBoeL3W5kTvA8B5q2nz9PsjXypGTmXriqNskT4syhH/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/42	HKN4zACpPLhE6CBQtarSfk2Dn45NVVWTKU2RLrtCLdwA	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
246	ZvxMLpA4pCtXW85njCfZgFGTUj1Ejtw39o1GTGxZDKT	CannaSolz #181	CNSZ	https://gateway.pinit.io/ipfs/QmW1SH5Mp2FQj5ACTGNBwGgsUyCxYpx4g2vKPyrNy7Sd2V/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/180	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Light green	t
244	jEPi5a7crYzw431TjWBP9qy8gq2tckVG3TyC7fY9kaE	CannaSolz #193	CNSZ	https://gateway.pinit.io/ipfs/QmP5jADtxWeyneA1hK3SWSZ62Rfvq7Vx3Gms4TQqMoFPoR/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/192	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Gold	t
11	HadYqxSuY5yMkfvfSusEvxmaE6TnzJnUcaUARjy8MWKh	CannaSolz #159	CNSZ	https://gateway.pinit.io/ipfs/QmRs34r93iCsZk8fQJ8ppAgKS3vP71HYwcnDwRAd8ht91r/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/158	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Silver	t
171	6oJmwkVinm89TbzyPuUL4h3cTNHPsiqLFvs6z22Fmt2C	CannaSolz #107	CNSZ	https://gateway.pinit.io/ipfs/QmPKMwfMEx9CQtawWGshdyfuwP5D8GBUBjYa5jJz4mpvYe/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/106	BfBokuitRZSx4wf5v4jBLAp5AGmp6rfS55STzw3UzGJJ	968226679963148318	jeffdukes1	f	\N	\N	\N	\N	\N	\N	Purple	t
248	Tknoc1UokySEzXCew2gdMu7xzGJCFeviBiXWmGBPfB2	CannaSolz #203	CNSZ	https://gateway.pinit.io/ipfs/QmUnaufsjMMRdNa8YY8uZXihRG1Tae1EK6ghc96PydE5pJ/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/202	66EMDQEr8uGn28fXKgfmA8noN1qr3su1VpNzM9DEUC7o	\N	\N	f	\N	0.168004759	\N	\N	\N	\N	Purple	t
187	5bQGoJDcKHNMuQ82SoWjBpqpJ4ZC2vjU3HDEYw3rAbgX	CannaSolz #128	CNSZ	https://gateway.pinit.io/ipfs/QmRC6Sj19z9cgFb2TNJttmu5sigjNJuzyuZQD5cr6FoaKH/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/127	Dxmt3kvYbecfWhUL2W1SbR9xLUtukGStyi5z9R4zVEV	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
185	5fSNDh6g1wyD1d4ocEPDoHi6rfnwkLDtEw4LsskmuueN	CannaSolz #89	CNSZ	https://gateway.pinit.io/ipfs/QmbBZ5Rwr1fwVdtvJtgC4K3duaGYKoWhKgG1QrBGGxmeKp/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/88	HKN4zACpPLhE6CBQtarSfk2Dn45NVVWTKU2RLrtCLdwA	\N	\N	f	\N	\N	\N	\N	\N	\N	Gold	t
84	D2RuN1iZYFe7JHf4KD4q2xCmLyjjvG4aJc9GBdrh6w2x	CannaSolz #151	CNSZ	https://gateway.pinit.io/ipfs/Qmb1zMmfS4rJDcmWvh8EtxYEHu7gosb2TrVy1ShPPpspi5/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/150	Aa5xb9Ri7UwmYLvtRsqbVTSiwVvj5AoyQ4Ru31wGPLFW	\N	\N	f	\N	\N	\N	\N	\N	\N	Purple	t
113	AmCvoSRmhr1UUHnMWF3HTtBGZpqc7TMqaDXsPdzS8aWh	CannaSolz #31	CNSZ	https://gateway.pinit.io/ipfs/QmS9cpA3dYuEZW4pt9LskFTf2H8HCmQBT4GanwgcNaD1CB/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/30	BEytQkVa6yoo5moNsnCfBEekY191FQKEZc1ho6KguGS1	\N	\N	f	\N	\N	\N	\N	\N	\N	Purple	t
231	2GdMY9WdtuhwFQxA8Pn8RF1hZ8LHxoJ5FcXugXDiF8JY	CannaSolz #194	CNSZ	https://gateway.pinit.io/ipfs/QmZp3UuwBjDCUvoHfnXrJUhBZB2ro8xfLu5m3PAAp7Mrd7/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/193	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Purple	t
193	5FrpnSoa8oxcLU3yjgxK232AfpaCpuyJWcfW5foQMz7R	CannaSolz #24	CNSZ	https://gateway.pinit.io/ipfs/QmR1gXsmG3mf11rJNwajFKa2FnZBaQZ8eJ1YRe87ogErBz/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/23	HKN4zACpPLhE6CBQtarSfk2Dn45NVVWTKU2RLrtCLdwA	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
198	4nac6FjkyVfKxhXWHswPq6NciSn4npiEd4MsvoMT3wR8	CannaSolz #58	CNSZ	https://gateway.pinit.io/ipfs/QmYR5Nf4kb8CTwC7dWr2NHXCGqqmQtzCfkwYgseXfjQePG/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/57	BgEtfZdZ3kSDEYr5GqCCh3HpXwPqV8UShdMzrYkSmEKU	\N	\N	f	\N	\N	\N	\N	\N	\N	Gold	t
203	4aeSQeehL81LvW8NmFoyvkr3qERrf5m2SdP2VmFzpjAR	CannaSolz #262	CNSZ	https://gateway.pinit.io/ipfs/QmfTVmsb8ADfYZkobaVGXPU3eAuCWASi1rLUG2vEsZ6in1/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/261	AJMMYDyBfnCkNZPrgz5E4QJwoyphVfc6ipiUR8koE6DW	\N	\N	f	\N	0.165404240	\N	\N	\N	\N	Dark green	t
206	4MEknSbdTxMQSq62trDbaXCNUc8KRpqfe7KD4hM8apBC	CannaSolz #131	CNSZ	https://gateway.pinit.io/ipfs/QmdpDZeaz8SmwAyrrR6YiKjLsjFg4DRdKJ4jhVjx3PFFqD/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/130	Dxmt3kvYbecfWhUL2W1SbR9xLUtukGStyi5z9R4zVEV	\N	\N	f	\N	\N	\N	\N	\N	\N	Purple	t
92	CRrz2ZHiTdRmk92g3YJzs6PDGhoVdPNrsEgScpTVvNgx	CannaSolz #266	CNSZ	https://gateway.pinit.io/ipfs/QmP8DxQZbrczgF8NNFcaQ8E5L7n3bUaaRPnADesU5XqGaM/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/265	A1hb6VgugqDRKT6xmgx5fG36F2vZF8fJtWorUKKjTKTn	\N	\N	f	\N	\N	\N	\N	\N	\N	Purple	t
213	3iSdq2r3ZNBNwfLHod7oaXejf57kCun3Zpza3XUDjjzA	CannaSolz #54	CNSZ	https://gateway.pinit.io/ipfs/QmW9HPcmZtSKMeGZugtcvGDVgHxDieMRiWpBhomGRDoydk/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/53	BgEtfZdZ3kSDEYr5GqCCh3HpXwPqV8UShdMzrYkSmEKU	\N	\N	f	\N	\N	\N	\N	\N	\N	Purple	t
218	3AccmDLXfJk3aLMfRJN4SWbispWTEUGvVcaPk1rVGtxG	CannaSolz #53	CNSZ	https://gateway.pinit.io/ipfs/QmZtLsL5daCxVJ2TYJPRu2C9Z97cGK8aBN4yYjoieYtQYY/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/52	BgEtfZdZ3kSDEYr5GqCCh3HpXwPqV8UShdMzrYkSmEKU	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
219	36iqrzCDgEGiABhYqg9i5tA5WjXtqm8uYz3MHvZVXUGX	CannaSolz #271	CNSZ	https://gateway.pinit.io/ipfs/QmcRCCfoST3dHHbqgmdUdgQSXtuUSJ3nCAErt5vAAw5Txc/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/270	8ubjoYXBmTStyr7mnTGtPtV2rWShG6K1goHHiVEk7fp3	\N	\N	f	\N	0.166118640	\N	\N	\N	\N	Dark green	t
91	CUCy7GRAbEJBeZyFcm9wZsNL813n8di6eiY65PvFYEnL	CannaSolz #146	CNSZ	https://gateway.pinit.io/ipfs/QmUcyK4ya2nMRD6XWQam9SWHoEpeocUTRid86oBPKWzDDY/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/145	9ckRqNxeCmvezNjQdPyYnAaDvJTfbku2Gn4J4sVqFF6o	\N	\N	f	\N	\N	\N	\N	\N	\N	Purple	t
86	CrCkrrkArN3Y8rqSDhSAZ93ohb3S6u3BEavFqVDo7L3A	CannaSolz #246	CNSZ	https://gateway.pinit.io/ipfs/QmQac5TfzT9wdXsQuJxiZPY9gPahy8JHFPxgMjDFv5E59c/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/245	C9xiFhke9pTU89YdNoLskuA64YNScWF42dmCJach13yh	\N	\N	f	\N	0.167895162	\N	\N	\N	\N	Purple	t
212	3pSKhzqU8i1N6AtuNF1RYdoyNYm8sPc9SyisL8QMw6nC	CannaSolz #191	CNSZ	https://gateway.pinit.io/ipfs/QmPixuxMhdyjeHHy1GFBQYiWffE4L7QwyXL8hKdhe74hcv/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/190	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Light green	t
112	ApYDzRHzPrZa2sTiUpWijJKodVR7b8xeJjjP4NK38L13	CannaSolz #231	CNSZ	https://gateway.pinit.io/ipfs/QmR2ip1KRP4b3LEg2Fq3A17xfdRWFHL6DPoeqwZs5D9a2x/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/230	FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha	1082504606690582601	snoopdfox	f	\N	0.105700000	\N	\N	\N	\N	Purple	t
41	FthxEJEG6jHpewceoSLWQG6zNvbNy4Leh3Gp9ts9XyJj	CannaSolz #195	CNSZ	https://gateway.pinit.io/ipfs/QmfDJoY3cpemWdeZvLXuB3xq68s1ZvAtkhTtFj2j2eWZG8/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/194	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Light green	t
236	xAkYYdaZLi1GwY7ZVbC3wkpQLJwJ92ur3U8Rc3wiUEi	CannaSolz #235	CNSZ	https://gateway.pinit.io/ipfs/QmY1FccMLmYdXWPYJ7MAqyv1ZTBFwHcXAQzhL5NZd8imja/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/234	A1hb6VgugqDRKT6xmgx5fG36F2vZF8fJtWorUKKjTKTn	\N	\N	f	\N	0.166968406	\N	\N	\N	\N	Dark green	t
230	2HCgiGvzKKa41p8m9fN8xbiDUC84BkdKwDTpQc33osoh	CannaSolz #150	CNSZ	https://gateway.pinit.io/ipfs/QmPDac5xW25kyzfBaqdYyR73DC4HWpfn7r8VZVLWpS7wR1/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/149	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Light green	t
232	27NqSLQU8EqmS5Zt9EzkAghnyn946kLgwjjzY6knKART	CannaSolz #25	CNSZ	https://gateway.pinit.io/ipfs/QmSkDYVwfz9TBdA74YyD5zAgirxSWyMyqPbbkGVcf67rhG/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/24	HKN4zACpPLhE6CBQtarSfk2Dn45NVVWTKU2RLrtCLdwA	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
243	khXmBfkAMAqu8vK3dnZswQHGn7zoKCH8B7SGrqyGYaG	CannaSolz #36	CNSZ	https://gateway.pinit.io/ipfs/QmXFRjCema79dZVaZmnQEGAT2vTAEm8zKC2bcM2irSTzrr/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/35	B5ZCWUT9xb7FgKe2mmesMc7rEEaxUZ5ShTRnYUz6udZA	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
250	JuGmbQ2xhqKqQw1RTByapGPrFr6MxPMHgLFUBiEWBYA	CannaSolz #77	CNSZ	https://gateway.pinit.io/ipfs/QmYLH9F1oELm8YKyJCzwg4TnoB24NZRm7Eh2QsGyTDf5Me/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/76	43GbnpZ8WtFf1Me78CXCgvtBjkMW7Wt5qBHtxW6dg6yP	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
242	nD5nmFPtHH9yMQg4rB7HSuvc6wBLPvHr2jLrJEpxnux	CannaSolz #42	CNSZ	https://gateway.pinit.io/ipfs/Qme9tPNuQHxSiri89PXLE9WPBheYc6cDPnDdW4g5gisabn/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/41	HKN4zACpPLhE6CBQtarSfk2Dn45NVVWTKU2RLrtCLdwA	\N	\N	f	\N	\N	\N	\N	\N	\N	Purple	t
222	2srpci3Jnk6rvHTGR1CeK59LySZTY2ebDev3nS7SGVE4	CannaSolz #105	CNSZ	https://gateway.pinit.io/ipfs/QmaDpfBEhLnABN8JvwHpuzqbNskJFEKQvjDhFKHEeK1yAY/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/104	BfBokuitRZSx4wf5v4jBLAp5AGmp6rfS55STzw3UzGJJ	968226679963148318	jeffdukes1	f	\N	\N	\N	\N	\N	\N	Light green	t
233	25QvhKzjyKLMkVczLbEzr8nAJHF9yE5JZiNhhAJQVvGg	CannaSolz #134	CNSZ	https://gateway.pinit.io/ipfs/QmYreLPyjtpvMyqdxr6qsuVv7gfrRcEySg5QhVg29ndsNf/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/133	BfBokuitRZSx4wf5v4jBLAp5AGmp6rfS55STzw3UzGJJ	968226679963148318	jeffdukes1	f	\N	\N	\N	\N	\N	\N	Purple	t
247	Yhdsbsnuw6ZKu6Tsiym6oGvVy9G6veoVivM8df2PJiz	CannaSolz #247	CNSZ	https://gateway.pinit.io/ipfs/QmcufMAZo4QNiMwUt4zQ7bW7tXTofSp65SdrcMhb2iDUWW/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/246	C9xiFhke9pTU89YdNoLskuA64YNScWF42dmCJach13yh	\N	\N	f	\N	0.166916382	\N	\N	\N	\N	Light green	t
253	6eskPaDEPmSm7Zzrm5GDU7AZAg7SRkeuiuw28TCvUV2	CannaSolz #223	CNSZ	https://gateway.pinit.io/ipfs/QmVXhfrrhG4YQqynHUvhhqWTQio2ZLpBwoiwzHdL3Y2jgS/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/222	CDFQARAF9a4H7x1qMQYKqv8jA1Csaj3c11P3srGAfivQ	\N	\N	f	\N	0.168031472	\N	\N	\N	\N	Light green	t
255	51PJZZgsBYvhchKiwRG2WEPqsjDuZ484AzUZg3TGQV3	CannaSolz #233	CNSZ	https://gateway.pinit.io/ipfs/QmNoU6Qrno3H99v3LKuwbaMircjijm8EMsyjcbpb4msYPi/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/232	66EMDQEr8uGn28fXKgfmA8noN1qr3su1VpNzM9DEUC7o	\N	\N	f	\N	0.166955705	\N	\N	\N	\N	Light green	t
51	FQj3W2vEbFjxHFQS46LNZG16xeAxAocSCViyTAjyBcex	CannaSolz #244	CNSZ	https://gateway.pinit.io/ipfs/QmNzCAg43WfoTeWHLSEDZozTXH9Befvj9D69GCApunwHZb/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/243	A1hb6VgugqDRKT6xmgx5fG36F2vZF8fJtWorUKKjTKTn	\N	\N	f	\N	\N	\N	\N	\N	\N	Purple	t
71	E9a3pVuGzkNDzXKQ4LrAfmRNDSGiuQpw15XrYFWp9Vv1	CannaSolz #273	CNSZ	https://gateway.pinit.io/ipfs/QmReaBtmiBtV6Wd6mBco9gxzTaobXcp5Cec4qDd9qLaPDC/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/272	BSzvE7ocP4NQCbrYzE1XsAXWdiTn8ey4JbaPKwtSLbTd	\N	\N	f	\N	0.164754240	\N	\N	\N	\N	Light green	t
141	8ptV3Cjfun2JGRfwZ7Vw76TpFSmKzRwPhiUiiH3jWxRP	CannaSolz #123	CNSZ	https://gateway.pinit.io/ipfs/QmSeLnPyeBACVqSxSwMMrpeyaYWsCqNFL1WLzwJbBiNUM2/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/122	CJD7gXVNgXpyN8dqx3VMDp843Nc4MFEQAymjEZuSZzX7	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
151	84Jzkz7XoQBLY6v7S9dhfzPdiEXmAHnKnPKqW88rQ1f1	CannaSolz #209	CNSZ	https://gateway.pinit.io/ipfs/QmeELffDzTMFVk22MujbFpvJE2hLmn8GGujo1KwvXkYKx6/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/208	BZ449ifq2FvMDm8MPwkwtxviFXwQsWsX4WmSMNUBoj1Z	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
161	7cbPLS9xDC1mokagzRzdmApXSFajdpg4EVpr1sSzzncy	CannaSolz #76	CNSZ	https://gateway.pinit.io/ipfs/QmWVPH2XQwJwMPs6nKNpBkFnqL8kVE2pLeYcmDbM4KCLzq/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/75	43GbnpZ8WtFf1Me78CXCgvtBjkMW7Wt5qBHtxW6dg6yP	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
181	5w6kuPpoZ87sKG1AwrxXg23UHg4xrkXJRXUSWLurw71R	CannaSolz #239	CNSZ	https://gateway.pinit.io/ipfs/QmaXvQydmZ7whjmDpJDiJKnaQALEV6BycaSzbUPKNn3KDb/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/238	HKN4zACpPLhE6CBQtarSfk2Dn45NVVWTKU2RLrtCLdwA	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
211	3sTKAZkxAyYww7VSJg24H3efgV7oT546z4ypkjQenc4P	CannaSolz #248	CNSZ	https://gateway.pinit.io/ipfs/QmW5UM6JUnwcwwAdSZEkpSQRCfGp7yKk5nUpsFvL9kYEwK/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/247	C9xiFhke9pTU89YdNoLskuA64YNScWF42dmCJach13yh	\N	\N	f	\N	0.166910820	\N	\N	\N	\N	Light green	t
241	o3uNg8nMpNMdeZTv4xWzzzbMbFgQTJeiWv1qRAGrnf8	CannaSolz #56	CNSZ	https://gateway.pinit.io/ipfs/QmdhkyHaRQJufBNW7SZLYKqWTRTtVnmw4LBUNmbusEEjGo/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/55	BgEtfZdZ3kSDEYr5GqCCh3HpXwPqV8UShdMzrYkSmEKU	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
217	3KHtJBBSmkg1NRwz13gZQzBwuxFsLSTav4oAKU4yXYyj	CannaSolz #109	CNSZ	https://gateway.pinit.io/ipfs/Qma7t51psC2ZYdLA2gsVAwsQzkP3h18zU43chhtHF9gKAh/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/108	1BWutmTvYPwDtmw9abTkS4Ssr8no61spGAvW1X6NDix	\N	\N	t	1.062000000	1.000000000	MagicEden	\N	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	\N	Purple	t
251	D32w8BqX2sYKRTDc1yq9HjUHNft9k4NyqCiMgVLVX2j	CannaSolz #5	CNSZ	https://gateway.pinit.io/ipfs/QmVseKAi22ttuf4PFPa6ooQStaV8yK4yDMiZ5ZeJhPDxoq/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/4	HKN4zACpPLhE6CBQtarSfk2Dn45NVVWTKU2RLrtCLdwA	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
81	DCf9K3ydJoLND8DoQks91mcxsMFqUDyHXsegHdx3sffg	CannaSolz #16	CNSZ	https://gateway.pinit.io/ipfs/QmWCtpqPzBipWnVx7KnBpM8T5HofUKrZYJnxR1UZCFP6xy/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/15	1BWutmTvYPwDtmw9abTkS4Ssr8no61spGAvW1X6NDix	\N	\N	t	1.062000000	1.000000000	MagicEden	\N	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	\N	Purple	t
168	6sggS9Yk9ANGji2DiRti8p1Gm3syy3Y4cs4GqphnfEda	CannaSolz #190	CNSZ	https://gateway.pinit.io/ipfs/QmYNzU4xyoddtTeGQ2t9RkXs5jyFj21GLwsEVUzuHNP9Ax/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/189	1BWutmTvYPwDtmw9abTkS4Ssr8no61spGAvW1X6NDix	\N	\N	t	0.988000000	0.930000000	MagicEden	\N	ALjeziYtV5DDviMXi4uA94ehSwbcvdxMnCSibCP4bNt5	\N	Light green	t
128	9eDCBDQhZkLbCigUL9an7iNGHCxULYJes7UDGL22xxWK	CannaSolz #232	CNSZ	https://gateway.pinit.io/ipfs/QmcfJ3cYZUeor59BoZovLuSjt7C7FTmDomEHNonzVFpYBX/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/231	CDFQARAF9a4H7x1qMQYKqv8jA1Csaj3c11P3srGAfivQ	\N	\N	f	\N	0.167146380	\N	\N	\N	\N	Silver	t
188	5aPwws5jX67BB5i2XFU28obp4GLKeCF9AhhLMgts7X8y	CannaSolz #259	CNSZ	https://gateway.pinit.io/ipfs/QmbYgYYsKeVosJBfLjgAYWjGSWGzugADVqeX5EXFMDjAqV/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/258	6SMH9uvR3UEo2XUTUGJ8x1FXwDX1SCF6t7d1FK3pZuN2	\N	\N	f	\N	0.166183641	\N	\N	\N	\N	Silver	t
209	3uGW79C9PDu8Yf9ByChYBYbM8YTMuGFqUBG6eYyen7nb	CannaSolz #272	CNSZ	https://gateway.pinit.io/ipfs/Qmb9Xz3YicmfReenimxTdTq4A1V9MBdcGC1KkCWDFAGkX4/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/271	BSzvE7ocP4NQCbrYzE1XsAXWdiTn8ey4JbaPKwtSLbTd	\N	\N	f	\N	0.165728640	\N	\N	\N	\N	Silver	t
131	9ScNbbCqTNaV9WmuQwTHuLR47bGHW78xxA9WJuVFLdvF	CannaSolz #114	CNSZ	https://gateway.pinit.io/ipfs/QmTj4sKS8ZT2oeKLiAGUSRCa8EqZoBsVfAyTDy7Ct6cDwM/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/113	1BWutmTvYPwDtmw9abTkS4Ssr8no61spGAvW1X6NDix	\N	\N	t	1.040800000	0.980000000	MagicEden	\N	C7AQvB2d1GAJXQVwMCDcTATbcxs92J76uzVuMCeSaEfh	\N	Light green	t
13	HSQGfR9qjYwjVyFaDuff9ehhqouUHK2t9H7Uop8thr6b	CannaSolz #138	CNSZ	https://gateway.pinit.io/ipfs/QmU4GhxUDdAJpH5eATaT6FJ7cPkJvQJXNQDxxyd4MppLnd/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/137	9ckRqNxeCmvezNjQdPyYnAaDvJTfbku2Gn4J4sVqFF6o	\N	\N	f	\N	\N	\N	\N	\N	\N	Purple	t
110	AynEfzomPCVWV7uTVnScVL9y1w15rTDwQMscL9wHbudR	CannaSolz #166	CNSZ	https://gateway.pinit.io/ipfs/QmSsmFMSHmErw5EKDxq8aVt9DyvkHWVwUVJiKbcZvEk95e/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/165	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	1082504606690582601	snoopdfox	f	\N	\N	\N	\N	\N	\N	Silver	t
18	H3RHMaYifV2UhFzGHmLKbW8uJu5DyQ8KZ4mLuBxG9P9b	CannaSolz #213	CNSZ	https://gateway.pinit.io/ipfs/QmPVQGCBiGcaNiAQy7zp1KcNr9dtFvfWL3HLrdiUL8tJMw/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/212	BUB21Fe2ttCid3Y9Bka12VKPfRzhD5cpCmiBHmdDY41r	\N	\N	f	\N	0.167030359	\N	\N	\N	\N	Purple	t
24	Gtt17K1iAM43GwCjXoFwpGaBXX6wNosJvDWrZRmi3hCF	CannaSolz #163	CNSZ	https://gateway.pinit.io/ipfs/Qme3twQ3WbSV2qXZiSgdfFn5BXbvjK9CtUZoGesqHUHo6w/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/162	4b4k45wHHyJwiURGJp1Pvo7fCpQ2ccrHs9sCeZ8sLjPh	\N	\N	f	\N	0.000000000	\N	\N	\N	\N	Dark green	t
25	Gk1UtjF53psbmb6GfQXPuXcj6ZhQ99YCGHHCQiJrQ2Vu	CannaSolz #72	CNSZ	https://gateway.pinit.io/ipfs/QmNk8u4DwbZc4aHbh55fp5KDNMeMb1vfgUa8LSbf95J7XV/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/71	BEytQkVa6yoo5moNsnCfBEekY191FQKEZc1ho6KguGS1	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
29	GPdgXy5UfTP8DicvcDKQohajakPmHUfsWBXB22CSvXMa	CannaSolz #144	CNSZ	https://gateway.pinit.io/ipfs/QmSFbZejky8EVE1BX5vekiDLwtbrChU5Sckhx92tzXv2Z2/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/143	9ckRqNxeCmvezNjQdPyYnAaDvJTfbku2Gn4J4sVqFF6o	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
54	FDi8bNgTPBdGV2Ti8YYCRrhqLN5fYk6twjsZdY16ZX59	CannaSolz #222	CNSZ	https://gateway.pinit.io/ipfs/QmWyMkpRyhNabNVfpTysTAv8EndXz82gdgFyj3HceURZbg/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/221	66EMDQEr8uGn28fXKgfmA8noN1qr3su1VpNzM9DEUC7o	\N	\N	f	\N	0.167048880	\N	\N	\N	\N	Dark green	t
107	BgEQa5ApLM8ktBMnu2be1VWL5Eb2LjmeUMdqBw2VURzq	CannaSolz #255	CNSZ	https://gateway.pinit.io/ipfs/Qme4W53hdfoxvNDm29rqKrNfsc6uXBpFrtu2gDQub5RPtH/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/254	4upHKXZP8996fZgAJERudoMhiDrsCojfjZpAgG6YrQqW	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
178	68L9iBrpEC3m5FB2uFcEXtx2SkKSAS1mqD6wKiwTFXjs	CannaSolz #183	CNSZ	https://gateway.pinit.io/ipfs/Qma1wH11F3YrvSZe8owhB1XSMtt2fbGFUf9XEK5E3nmPj3/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/182	ERTZNDL9g5UFo3M7mAUCbqfsQ5NA89j8h3gvW1obyC1L	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
197	4wcLDfA3K5cKYde55kD6YeWam7wtyzHawetnTPSt161e	CannaSolz #6	CNSZ	https://gateway.pinit.io/ipfs/QmZdr8tpBA38aCEdD9xHVr1jLcBuHw1RYoq9fRCFdumhKv/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/5	HKN4zACpPLhE6CBQtarSfk2Dn45NVVWTKU2RLrtCLdwA	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
7	HhChGBFNGmFYziiQWE71psbSsZX8mEJRm9uhMxfSz6Bt	CannaSolz #142	CNSZ	https://gateway.pinit.io/ipfs/Qmeu9W4NGfAFruiu929mA9TtAAA96GcGr4nNEjedmQwskE/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/141	9ckRqNxeCmvezNjQdPyYnAaDvJTfbku2Gn4J4sVqFF6o	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
8	HgtTMtpHfgziu8Zx4dtejarvQ2ogQiqj2oC6V6kkRhUR	CannaSolz #250	CNSZ	https://gateway.pinit.io/ipfs/QmPF8rW4jVyehuD2ebkEuKvrFFEXQddpqpUKLcVdmDbP52/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/249	BgHcACwthQhFrgfb8KpyTMDFomWcSaQ7zzHQHyyXsZdA	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
50	FQqgCeApT2qiCMmcwrUafoBNhD2k8KLCcUoD6fuv3xoR	CannaSolz #251	CNSZ	https://gateway.pinit.io/ipfs/QmTawYMHCo7cKeZKEKcGCPL7a3coeWdExQS9NJ4YGDkS6j/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/250	7Q3PX3i4pYWkq4UadXie5jkdkdX6f2UKFxpbVZnzeMr2	\N	\N	f	\N	0.166909880	\N	\N	\N	\N	Light green	t
97	CCWENurrUvMrbB8joUY9MWtkc2y86mTSozheUxSiyJbM	CannaSolz #253	CNSZ	https://gateway.pinit.io/ipfs/QmSJVdcaNB65GXVHo2zVRbo1GumfgTP9U2smd2B2W3VWY9/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/252	AJMMYDyBfnCkNZPrgz5E4QJwoyphVfc6ipiUR8koE6DW	\N	\N	f	\N	0.167533881	\N	\N	\N	\N	Light green	t
115	AbLFik24BapsMwbUD6yNQ311bPSMLoLRC1agPbxhMedX	CannaSolz #234	CNSZ	https://gateway.pinit.io/ipfs/QmNssKn8zq5p2uuFHCCjL7osRf8q9hHo5rASfjPRqew4vg/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/233	A1hb6VgugqDRKT6xmgx5fG36F2vZF8fJtWorUKKjTKTn	\N	\N	f	\N	0.166968406	\N	\N	\N	\N	Light green	t
117	AHxSzDCLA7JppFjvKk81mDec4eTsUZ9RWedrFqnoL17Z	CannaSolz #204	CNSZ	https://gateway.pinit.io/ipfs/QmZa7fQihR8bRX3Vo2r42PfMM4VNcX6Ke53UbEJVNhBAdM/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/203	66EMDQEr8uGn28fXKgfmA8noN1qr3su1VpNzM9DEUC7o	\N	\N	f	\N	0.167034599	\N	\N	\N	\N	Light green	t
130	9TBVLoTJWKcUUhkV4oZq3hZzu9oZggwtkqaecpGGAWGm	CannaSolz #243	CNSZ	https://gateway.pinit.io/ipfs/QmVD8ca4hvWKcVXmSdAonSkxMEABYXwh57fHFxUsZCNDtM/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/242	AJMMYDyBfnCkNZPrgz5E4QJwoyphVfc6ipiUR8koE6DW	\N	\N	f	\N	0.167902856	\N	\N	\N	\N	Light green	t
146	8PczTB399wDgED3T1D3QcxmLsJYATAmAi37Wo9XpfLaZ	CannaSolz #153	CNSZ	https://gateway.pinit.io/ipfs/Qmb6a5Xz31q4QNzEBzAkmCKFkwAZ8YBBoN8HDTfVjRjhW5/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/152	Ax6hgN8eZ6Y4RKzhVocU2n15DnZMttvkSyPXi6mdeFuB	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
149	8HVTf5Lj8gf6kTCKhCFznZEP9nhvdXaTrUxNWUsTsqk3	CannaSolz #242	CNSZ	https://gateway.pinit.io/ipfs/QmRdh33pojSSzUuTGVUfZ8evjNg3Bfa5PBBjE3eHd5Rgxo/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/241	66EMDQEr8uGn28fXKgfmA8noN1qr3su1VpNzM9DEUC7o	\N	\N	f	\N	0.166909880	\N	\N	\N	\N	Light green	t
155	7trJkmf1P2hbixzima8mrAop7stswwWSLPWisvFvCLWM	CannaSolz #4	CNSZ	https://gateway.pinit.io/ipfs/QmXHiEGSGQ7WvngWHb85qUGH9XffcP84e92yEEhWpKWSXp/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/3	HKN4zACpPLhE6CBQtarSfk2Dn45NVVWTKU2RLrtCLdwA	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
156	7sSw6yy5bR5X7w5DeoAeCZpYKiYtnZQGEMNQFeCb5vFz	CannaSolz #218	CNSZ	https://gateway.pinit.io/ipfs/QmXXVasFwyX1319Kb19PtC8P7j4k3gidZj12LQ4EBMVJAC/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/217	66EMDQEr8uGn28fXKgfmA8noN1qr3su1VpNzM9DEUC7o	\N	\N	f	\N	0.167030309	\N	\N	\N	\N	Light green	t
160	7hDrQ3dPM2Jv47AwzkF8xKe6NPkyyV2VuRoNHooVZGZJ	CannaSolz #137	CNSZ	https://gateway.pinit.io/ipfs/QmdS3HwZokUMiLof7Q8ohdY4HXzyskQWq5HpgXgTk69RGd/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/136	9ckRqNxeCmvezNjQdPyYnAaDvJTfbku2Gn4J4sVqFF6o	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
200	4dLS1J7EtKvDe9nVZJLF2xsgtZ5KyNocAkoqa4ffikqu	CannaSolz #211	CNSZ	https://gateway.pinit.io/ipfs/QmZ22Zqpx4r6Rj53fbrW12nh8qgC6znuzVVJwJqNdbsy38/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/210	CDFQARAF9a4H7x1qMQYKqv8jA1Csaj3c11P3srGAfivQ	\N	\N	f	\N	0.168023280	\N	\N	\N	\N	Light green	t
215	3SPGqXoT5nR1QooRvkz6GPvUbfjXHbsT2m23ski73tnm	CannaSolz #214	CNSZ	https://gateway.pinit.io/ipfs/QmbjNEJ8eVa4evCxQPAQJqS8ocjq6qRB9RVNB7EMtSVcGw/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/213	CDFQARAF9a4H7x1qMQYKqv8jA1Csaj3c11P3srGAfivQ	\N	\N	f	\N	0.167061880	\N	\N	\N	\N	Light green	t
216	3RPvwQrmCi2aMBZ16S4wGsjYasAbpqDmk6T55vwSp8NX	CannaSolz #171	CNSZ	https://gateway.pinit.io/ipfs/QmfYCz11PPejse23qiidiEh5wJPTYBZQLzFD6uYepCbU6i/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/170	monFzzwmrKieeVwrVXHiyoi7eCB7uHqkmmPNB9YaVM6	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
223	2jn4SwVLi9aCm3LaA6wj86ejdsUSkVfuFkc7XTQckc2N	CannaSolz #103	CNSZ	https://gateway.pinit.io/ipfs/QmVDjHDdtRbCjMrtP1MsaK9y2Z6f5tHZepe3jtnfaREiSt/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/102	E28hBxZSjPFPZX4fMNnj2sfU2ENM6cJHyDAWJhNPVu7V	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
226	2h27JdQGGHV5NJRPa8NjspsYFNgPdsbSHEZeJXCBWGxY	CannaSolz #229	CNSZ	https://gateway.pinit.io/ipfs/QmTATguDTWtJ9kdBvxJTnnei5dfGKY3nDg8XNfxGEWqEb1/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/228	CDFQARAF9a4H7x1qMQYKqv8jA1Csaj3c11P3srGAfivQ	\N	\N	f	\N	0.167048908	\N	\N	\N	\N	Light green	t
227	2QhKuYMcHnbhctCaok9HAi1v7LvrLLyGYmRfQp2CCkq5	CannaSolz #122	CNSZ	https://gateway.pinit.io/ipfs/QmP4m1EVKQKTXv7xKgoMbHYCqLtZQodQDwvTiMdCxmVLCU/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/121	CJD7gXVNgXpyN8dqx3VMDp843Nc4MFEQAymjEZuSZzX7	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
229	2MA8eJpCrxqQ75tueqUc3APaZqfZRBFpqktMuNs7g2Qa	CannaSolz #258	CNSZ	https://gateway.pinit.io/ipfs/QmQFbFFRErS8y547gnPCb9mzhNaKdeYZZgUEc5mpN6ySon/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/257	8ZeV5hbixYiexMAN1P1D1CK5nE3ZskU9wQfFMsCc69H3	\N	\N	f	\N	0.166183641	\N	\N	\N	\N	Light green	t
234	23gurxQxXAqiurn4pzLHPW1MzDmsdEvccMMXurPcH8cY	CannaSolz #75	CNSZ	https://gateway.pinit.io/ipfs/QmVrJVoBKZVJCEGjhxd4DmeqWKnScSLnaH5YaWx2uWU3HE/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/74	43GbnpZ8WtFf1Me78CXCgvtBjkMW7Wt5qBHtxW6dg6yP	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
256	13LJCkigx6pMBBo9EZi6Pn9gwkrE366DrD7DiztrvT9D	CannaSolz #178	CNSZ	https://gateway.pinit.io/ipfs/QmYiKQEQRcEAWcFzrHamDj1L9qWXXRYjaw3rP8vbafHWan/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/177	3GUyKaU3GNnYdrJYyJmzEki4nRsLXEkKPhF7jcFG1d6z	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
101	C9Acc7hAcaTUfw34e9vWtcimxK1xm5Fe6F3Hk1E7YwHy	CannaSolz #130	CNSZ	https://gateway.pinit.io/ipfs/QmSXLwNtBUJu72Y6vJ3BAtRqZKm7usRGmFzGBsuZFvqaun/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/129	Dxmt3kvYbecfWhUL2W1SbR9xLUtukGStyi5z9R4zVEV	\N	\N	f	\N	\N	\N	\N	\N	\N	Light green	t
111	AwyGRRpmmaqoRXMHvRtb6gZyceP33oTS4wap1danFYdT	CannaSolz #240	CNSZ	https://gateway.pinit.io/ipfs/QmX8dCCKrcrgM1MKtzAKzv94WtJqBcmEeDG5VLy4Xda818/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/239	HKN4zACpPLhE6CBQtarSfk2Dn45NVVWTKU2RLrtCLdwA	\N	\N	f	\N	0.167143711	\N	\N	\N	\N	Light green	t
136	99wiYgBmVzBz4VeQ5KasG6eiXJ1tKqxqS4WTEwEht1dP	CannaSolz #23	CNSZ	https://gateway.pinit.io/ipfs/QmVC79BTMW7ru4fpfR6JztbL2dcfKAjCbzu4fycEtzhvjC/0	[{"share": 0, "address": "3LoQA5MUh6ziqYXzdrTmipXH5C9ip5pc2ppXgsUXa5rH", "verified": true}, {"share": 40, "address": "FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha", "verified": false}, {"share": 40, "address": "SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq", "verified": false}, {"share": 20, "address": "6LiJZQwjLDwaJ2EeBZ8FKWx1VYHBLdNZARrgmkeMgGFw", "verified": false}]	\N	https://cdn.helius-rpc.com/cdn-cgi/image//https://nftstorage.link/ipfs/bafybeideg2bmlwcbs554kwzd4dspvlpi4f2qpj6rh7zkeb2fi5cbrzid5e/22	E9ebZxevDUpsDWWs8TdVRaAjxWKiXs5MKGogBzaLRqnt	\N	\N	f	\N	\N	\N	\N	\N	\N	Dark green	t
\.


--
-- TOC entry 3514 (class 0 OID 16625)
-- Dependencies: 227
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.roles (id, name, type, collection, threshold, discord_role_id, created_at, updated_at, display_name, color, emoji_url) FROM stdin;
1	holder_gold	holder	CNSZ	1	1031946884262141992	2025-11-16 02:18:05.774842	2025-11-16 02:18:05.774842	🟨Holder🟨	#d5ba46	\N
2	holder_silver	holder	CNSZ	1	1034004776326791208	2025-11-16 02:18:05.774842	2025-11-16 02:18:05.774842	⬜Holder⬜	#9aaaaa	\N
3	holder_purple	holder	CNSZ	1	1034024392881098772	2025-11-16 02:18:05.774842	2025-11-16 02:18:05.774842	🟪Holder🟪	#9b59b6	\N
4	holder_dark_green	holder	CNSZ	1	1034024577673728080	2025-11-16 02:18:05.774842	2025-11-16 02:18:05.774842	📗Holder📗	#004a1f	\N
5	holder_light_green	holder	CNSZ	1	1034024705562255410	2025-11-16 02:18:05.774842	2025-11-16 02:18:05.774842	🟩Holder🟩	#6bfb7d	\N
6	potter_any	holder	CNSZ	1	1216823615148916796	2025-11-16 02:18:05.774842	2025-11-16 02:18:05.774842	POTTER🪴	#725503	\N
7	token_holder_1	token	CNSZ	1	1050104439811358731	2025-11-17 02:29:52.491462	2025-11-17 02:29:52.491462	CannaSolz420 Token Holder	#fee88f	\N
8	token_holder_1k	token	CNSZ	1000	1050106965461839962	2025-11-17 02:29:52.491462	2025-11-17 02:29:52.491462	CannaSolz420 Token (1k+)	#fee88f	\N
9	token_holder_5k	token	CNSZ	5000	1050107832793571390	2025-11-17 02:29:52.491462	2025-11-17 02:29:52.491462	CannaSolz420 Token (5k+)	#fee88f	\N
10	token_holder_10k	token	CNSZ	10000	1247550426501615666	2025-11-17 02:29:52.491462	2025-11-17 02:29:52.491462	CannaSolz420 Token (10k+)	#fee88f	\N
11	token_holder_25k	token	CNSZ	25000	1247662904564514846	2025-11-17 02:29:52.491462	2025-11-17 02:29:52.491462	CannaSolz420 Token (25k+)	#fee88f	\N
12	og420	holder	CNSZ	1	1215479808599793684	2025-11-17 03:01:30.536928	2025-11-17 03:01:30.536928	OG420	#2ecc71	\N
18	HARVESTER Gold	holder	seedling_gold	1	1260017043005112330	2025-11-17 17:20:08.781755	2025-11-17 17:20:08.781755	HARVESTER Gold	#d5ba46	\N
19	HARVESTER Silver	holder	seedling_silver	1	1260016966324846592	2025-11-17 17:20:08.932693	2025-11-17 17:20:08.932693	HARVESTER Silver	#9aaaaa	\N
20	HARVESTER Purple	holder	seedling_purple	1	1260016886587068556	2025-11-17 17:20:09.037583	2025-11-17 17:20:09.037583	HARVESTER Purple	#9b59b6	\N
21	HARVESTER Dark Green	holder	seedling_dark_green	1	1260016258087387297	2025-11-17 17:20:09.132835	2025-11-17 17:20:09.132835	HARVESTER Dark Green	#004a1f	\N
22	HARVESTER Light Green	holder	seedling_light_green	1	1248728576770048140	2025-11-17 17:20:09.228084	2025-11-17 17:20:09.228084	HARVESTER Light Green	#6bfb7d	\N
28	collector	special	CNSZ	1	1247188594431361146	2025-11-20 09:48:01.740511	2025-11-20 09:48:01.740511	COLLECTOR	#9aafb6	\N
29	level_1_toasted	level	CNSZ	1	1246625923374125227	2025-11-20 09:48:01.740511	2025-11-20 09:48:01.740511	LEVEL 1: TOASTED (1+)	#c9e9fd	\N
30	level_2_baked	level	CNSZ	3	1246626103574134805	2025-11-20 09:48:01.740511	2025-11-20 09:48:01.740511	LEVEL 2: BAKED (3+)	#a5dcff	\N
31	level_3_roasted	level	CNSZ	5	1246626280057733121	2025-11-20 09:48:01.740511	2025-11-20 09:48:01.740511	LEVEL 3: ROASTED (5+)	#7bccff	\N
32	level_4_fried	level	CNSZ	7	1246627243053285529	2025-11-20 09:48:01.740511	2025-11-20 09:48:01.740511	LEVEL 4: FRIED (7+)	#5dbfff	\N
33	level_5_cracked	level	CNSZ	10	1246627404966002851	2025-11-20 09:48:01.740511	2025-11-20 09:48:01.740511	LEVEL 5: CRACKED (10+)	#42b5ff	\N
34	level_6_couch_coma	level	CNSZ	15	1246627720943632455	2025-11-20 09:48:01.740511	2025-11-20 09:48:01.740511	LEVEL 6: COUCH COMA(15+)	#2b87ff	\N
35	level_7_mashed	level	CNSZ	20	1246627805454929960	2025-11-20 09:48:01.740511	2025-11-20 09:48:01.740511	LEVEL 7: MASHED (20+)	#2967ff	\N
\.


--
-- TOC entry 3516 (class 0 OID 16635)
-- Dependencies: 229
-- Data for Name: session; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.session (sid, sess, expire) FROM stdin;
\.


--
-- TOC entry 3505 (class 0 OID 16518)
-- Dependencies: 217
-- Data for Name: token_holders; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.token_holders (wallet_address, balance, owner_discord_id, owner_name, last_updated, is_exempt) FROM stdin;
BpC4m1fzXSbTpgaZfbf2Tusjp4si9vPAVVYN67YL3nxc	200.000000000	\N	\N	2025-11-20 09:53:58.352135	f
5rmnix8Y4jEDV4CqSMmg4nkqNdRACmd3crAfdPJ7gGke	600.000000000	\N	\N	2025-11-20 09:53:58.352135	f
G4KnzkwCkK2dNxeazGbxnTtkwnwC1QWg6ey6LEVEWpCZ	200.000000000	\N	\N	2025-11-20 09:53:58.352135	f
Ccx1sBDNtffAQ2DQgJi22Qru6ddHv2dtutZUJPk5YqWF	9700945.000000000	\N	\N	2025-11-20 09:53:58.352135	f
CSzTMwguz6jhTXDCEhawUFfMbFdk2nVMvDFfzrn1Hb7t	409997950.000000000	\N	\N	2025-11-20 09:53:58.352135	f
AcWwsEwgcEHz6rzUTXcnSksFZbETtc2JhA4jF7PKjp9T	6.000000000	\N	\N	2025-11-20 09:53:58.352135	f
2HW4BLmC1m59NgYaYKz6NNAwNem5Jxo86FM8qiGdQBMG	200.000000000	\N	\N	2025-11-20 09:53:58.352135	f
ALjeziYtV5DDviMXi4uA94ehSwbcvdxMnCSibCP4bNt5	325.000000000	\N	\N	2025-11-20 09:53:58.352135	f
719rDdThg3vX45ZEfJ6UgAEGQd53JDYa19Vx3BmG7nyT	200.000000000	\N	\N	2025-11-20 09:53:58.352135	f
2E9TCq1x5XrEaKgFrvTurzkErAUeS1tNQ5ZKV5zQSg2G	500.000000000	\N	\N	2025-11-20 09:53:58.352135	f
3ernPawEh2g6TxNfCpnrvTT17rX5wEsLsbCm7kEKHiBq	400.000000000	\N	\N	2025-11-20 09:53:58.352135	f
F86PktBTrbApZ5GiibkxhRbZRdsYSpeyniykza6LEp4R	200000.000000000	\N	\N	2025-11-20 09:53:58.352135	f
CSzPgT4M23gQC3KRvWH2ZRG3SbNKdEZJtqkUUeZhZccN	400.000000000	\N	\N	2025-11-20 09:53:58.352135	f
GMEqdwKtKFTosRk6WEv51YVC56raKNEzXf56kzySmWV4	100.000000000	\N	\N	2025-11-20 09:53:58.352135	f
Fk5EQPbeg9Vkp7gjnMThAueuzy8dLqFNAzB1Bd2Rfix1	350.000000000	\N	\N	2025-11-20 09:53:58.352135	f
D6NdBATavTnzPThqYYnjZ7ZVfT9LnfN4qBoX9ZtmF4VC	200.000000000	\N	\N	2025-11-20 09:53:58.352135	f
1485H19EQYqn2UnWxkhspqYP2GspV3PADaye7gAMrfd7	200.000000000	\N	\N	2025-11-20 09:53:58.352135	f
5mJNExJ2Go9hiH56Pm7kTuZik7VNv1asn6WYCH8UxnBm	200.000000000	\N	\N	2025-11-20 09:53:58.352135	f
9q1erGjr86LGeo1GhzGR83oS6qbtSE5mHPpyWCwkGtrQ	200.000000000	\N	\N	2025-11-20 09:53:58.352135	f
5niy7uGdD2r31dRUk2SbD3pv7qRpigwGoekho6T8GRxg	200.000000000	\N	\N	2025-11-20 09:53:58.352135	f
HQ18MNmTpTdcRMhGJWVjZHKCq99dShsmLD2LXypCzvd7	200.000000000	\N	\N	2025-11-20 09:53:58.352135	f
AYsfPAsDyiw1GQpDFYEQBmd6q1QQ28A9pUMq9GNbNBYo	999.000000000	\N	\N	2025-11-20 09:53:58.352135	f
7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	26045.000000000	\N	\N	2025-11-20 09:53:58.352135	f
22Ams7vKn4ogFL44DUGMZYEU6kknJu2j732EXuF26t8W	200.000000000	\N	\N	2025-11-20 09:53:58.352135	f
A1hb6VgugqDRKT6xmgx5fG36F2vZF8fJtWorUKKjTKTn	200.000000000	\N	\N	2025-11-20 09:53:58.352135	f
SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	46000.000000000	\N	\N	2025-11-20 09:53:58.352135	f
HKSfqJb9BhuMcWMCAiuDc3g81DYMwia2r92DVxc8PgEQ	200.000000000	\N	\N	2025-11-20 09:53:58.352135	f
DSfAWGkMcpeN18vXioNkGWGKywYTKFH4DXdLsVav6Bqa	200.000000000	\N	\N	2025-11-20 09:53:58.352135	f
CSHkfzwZYoNWJsMuKvmq42pN4ZG82vsHDzFz1c1yC2Td	350.000000000	\N	\N	2025-11-20 09:53:58.352135	f
CDFQARAF9a4H7x1qMQYKqv8jA1Csaj3c11P3srGAfivQ	14410.000000000	\N	\N	2025-11-20 09:53:58.352135	f
AfVXtsmsbmeVDuYSTdEQdiJsYKsi8EKZEdzoTmRb8mQ	200.000000000	\N	\N	2025-11-20 09:53:58.352135	f
HQfvwqkDxp5R1q6pXZ6h3pcHRAk5beBHpMSCkoL7QAqd	760.000000000	\N	\N	2025-11-20 09:53:58.352135	f
\.


--
-- TOC entry 3517 (class 0 OID 16654)
-- Dependencies: 230
-- Data for Name: user_roles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_roles (discord_id, discord_name, last_updated, roles, harvester_gold, harvester_silver, harvester_purple, harvester_dark_green, harvester_light_green) FROM stdin;
931160720261939230	Tom [SLOTTO]	2025-11-20 09:54:37.825043	[{"id": "1034024577673728080", "name": "holder_dark_green", "type": "holder", "color": "#004a1f", "emoji_url": null, "collection": "CNSZ", "display_name": "📗Holder📗"}, {"id": "1216823615148916796", "name": "potter_any", "type": "holder", "color": "#725503", "emoji_url": null, "collection": "CNSZ", "display_name": "POTTER🪴"}, {"id": "1050104439811358731", "name": "token_holder_1", "type": "token", "color": "#fee88f", "emoji_url": null, "collection": "CNSZ", "display_name": "CannaSolz420 Token Holder"}, {"id": "1215479808599793684", "name": "og420", "type": "holder", "color": "#2ecc71", "emoji_url": null, "collection": "CNSZ", "display_name": "OG420"}, {"id": "1246625923374125227", "name": "level_1_toasted", "type": "level", "color": "#c9e9fd", "emoji_url": null, "collection": "CNSZ", "display_name": "LEVEL 1: TOASTED (1+)"}]	f	f	f	f	f
734542056390787112	Professor	\N	\N	f	f	f	f	f
290531269970755587	Gob1	2025-11-20 09:54:17.400154	[{"id": "1031946884262141992", "name": "holder_gold", "type": "holder", "color": "#d5ba46", "emoji_url": null, "collection": "CNSZ", "display_name": "🟨Holder🟨"}, {"id": "1034024392881098772", "name": "holder_purple", "type": "holder", "color": "#9b59b6", "emoji_url": null, "collection": "CNSZ", "display_name": "🟪Holder🟪"}, {"id": "1034024705562255410", "name": "holder_light_green", "type": "holder", "color": "#6bfb7d", "emoji_url": null, "collection": "CNSZ", "display_name": "🟩Holder🟩"}, {"id": "1216823615148916796", "name": "potter_any", "type": "holder", "color": "#725503", "emoji_url": null, "collection": "CNSZ", "display_name": "POTTER🪴"}, {"id": "1050104439811358731", "name": "token_holder_1", "type": "token", "color": "#fee88f", "emoji_url": null, "collection": "CNSZ", "display_name": "CannaSolz420 Token Holder"}, {"id": "1215479808599793684", "name": "og420", "type": "holder", "color": "#2ecc71", "emoji_url": null, "collection": "CNSZ", "display_name": "OG420"}, {"id": "1260017043005112330", "name": "HARVESTER Gold", "type": "holder", "color": "#d5ba46", "emoji_url": null, "collection": "seedling_gold", "display_name": "HARVESTER Gold"}, {"id": "1260016966324846592", "name": "HARVESTER Silver", "type": "holder", "color": "#9aaaaa", "emoji_url": null, "collection": "seedling_silver", "display_name": "HARVESTER Silver"}, {"id": "1260016886587068556", "name": "HARVESTER Purple", "type": "holder", "color": "#9b59b6", "emoji_url": null, "collection": "seedling_purple", "display_name": "HARVESTER Purple"}, {"id": "1260016258087387297", "name": "HARVESTER Dark Green", "type": "holder", "color": "#004a1f", "emoji_url": null, "collection": "seedling_dark_green", "display_name": "HARVESTER Dark Green"}, {"id": "1248728576770048140", "name": "HARVESTER Light Green", "type": "holder", "color": "#6bfb7d", "emoji_url": null, "collection": "seedling_light_green", "display_name": "HARVESTER Light Green"}, {"id": "1246626103574134805", "name": "level_2_baked", "type": "level", "color": "#a5dcff", "emoji_url": null, "collection": "CNSZ", "display_name": "LEVEL 2: BAKED (3+)"}]	t	t	t	t	t
968226679963148318	jeffdukes1 $BETSKI	2025-11-20 09:54:17.180352	[{"id": "1034004776326791208", "name": "holder_silver", "type": "holder", "color": "#9aaaaa", "emoji_url": null, "collection": "CNSZ", "display_name": "⬜Holder⬜"}, {"id": "1034024392881098772", "name": "holder_purple", "type": "holder", "color": "#9b59b6", "emoji_url": null, "collection": "CNSZ", "display_name": "🟪Holder🟪"}, {"id": "1034024577673728080", "name": "holder_dark_green", "type": "holder", "color": "#004a1f", "emoji_url": null, "collection": "CNSZ", "display_name": "📗Holder📗"}, {"id": "1034024705562255410", "name": "holder_light_green", "type": "holder", "color": "#6bfb7d", "emoji_url": null, "collection": "CNSZ", "display_name": "🟩Holder🟩"}, {"id": "1216823615148916796", "name": "potter_any", "type": "holder", "color": "#725503", "emoji_url": null, "collection": "CNSZ", "display_name": "POTTER🪴"}, {"id": "1215479808599793684", "name": "og420", "type": "holder", "color": "#2ecc71", "emoji_url": null, "collection": "CNSZ", "display_name": "OG420"}, {"id": "1246626280057733121", "name": "level_3_roasted", "type": "level", "color": "#7bccff", "emoji_url": null, "collection": "CNSZ", "display_name": "LEVEL 3: ROASTED (5+)"}]	f	f	f	f	f
890398220600115271	Snoop D Fox	2025-11-20 09:54:17.409549	[{"id": "1031946884262141992", "name": "holder_gold", "type": "holder", "color": "#d5ba46", "emoji_url": null, "collection": "CNSZ", "display_name": "🟨Holder🟨"}, {"id": "1034004776326791208", "name": "holder_silver", "type": "holder", "color": "#9aaaaa", "emoji_url": null, "collection": "CNSZ", "display_name": "⬜Holder⬜"}, {"id": "1034024392881098772", "name": "holder_purple", "type": "holder", "color": "#9b59b6", "emoji_url": null, "collection": "CNSZ", "display_name": "🟪Holder🟪"}, {"id": "1034024577673728080", "name": "holder_dark_green", "type": "holder", "color": "#004a1f", "emoji_url": null, "collection": "CNSZ", "display_name": "📗Holder📗"}, {"id": "1034024705562255410", "name": "holder_light_green", "type": "holder", "color": "#6bfb7d", "emoji_url": null, "collection": "CNSZ", "display_name": "🟩Holder🟩"}, {"id": "1216823615148916796", "name": "potter_any", "type": "holder", "color": "#725503", "emoji_url": null, "collection": "CNSZ", "display_name": "POTTER🪴"}, {"id": "1050104439811358731", "name": "token_holder_1", "type": "token", "color": "#fee88f", "emoji_url": null, "collection": "CNSZ", "display_name": "CannaSolz420 Token Holder"}, {"id": "1050106965461839962", "name": "token_holder_1k", "type": "token", "color": "#fee88f", "emoji_url": null, "collection": "CNSZ", "display_name": "CannaSolz420 Token (1k+)"}, {"id": "1050107832793571390", "name": "token_holder_5k", "type": "token", "color": "#fee88f", "emoji_url": null, "collection": "CNSZ", "display_name": "CannaSolz420 Token (5k+)"}, {"id": "1247550426501615666", "name": "token_holder_10k", "type": "token", "color": "#fee88f", "emoji_url": null, "collection": "CNSZ", "display_name": "CannaSolz420 Token (10k+)"}, {"id": "1247662904564514846", "name": "token_holder_25k", "type": "token", "color": "#fee88f", "emoji_url": null, "collection": "CNSZ", "display_name": "CannaSolz420 Token (25k+)"}, {"id": "1215479808599793684", "name": "og420", "type": "holder", "color": "#2ecc71", "emoji_url": null, "collection": "CNSZ", "display_name": "OG420"}, {"id": "1260017043005112330", "name": "HARVESTER Gold", "type": "holder", "color": "#d5ba46", "emoji_url": null, "collection": "seedling_gold", "display_name": "HARVESTER Gold"}, {"id": "1260016966324846592", "name": "HARVESTER Silver", "type": "holder", "color": "#9aaaaa", "emoji_url": null, "collection": "seedling_silver", "display_name": "HARVESTER Silver"}, {"id": "1260016886587068556", "name": "HARVESTER Purple", "type": "holder", "color": "#9b59b6", "emoji_url": null, "collection": "seedling_purple", "display_name": "HARVESTER Purple"}, {"id": "1260016258087387297", "name": "HARVESTER Dark Green", "type": "holder", "color": "#004a1f", "emoji_url": null, "collection": "seedling_dark_green", "display_name": "HARVESTER Dark Green"}, {"id": "1248728576770048140", "name": "HARVESTER Light Green", "type": "holder", "color": "#6bfb7d", "emoji_url": null, "collection": "seedling_light_green", "display_name": "HARVESTER Light Green"}, {"id": "1247188594431361146", "name": "collector", "type": "special", "color": "#9aafb6", "emoji_url": null, "collection": "CNSZ", "display_name": "COLLECTOR"}, {"id": "1246627805454929960", "name": "level_7_mashed", "type": "level", "color": "#2967ff", "emoji_url": null, "collection": "CNSZ", "display_name": "LEVEL 7: MASHED (20+)"}]	t	t	t	t	t
392070555102085130	Gaeaphile | tD P4L	2025-11-20 09:54:17.404926	[{"id": "1260016966324846592", "name": "HARVESTER Silver", "type": "holder", "color": "#9aaaaa", "emoji_url": null, "collection": "seedling_silver", "display_name": "HARVESTER Silver"}, {"id": "1260016886587068556", "name": "HARVESTER Purple", "type": "holder", "color": "#9b59b6", "emoji_url": null, "collection": "seedling_purple", "display_name": "HARVESTER Purple"}, {"id": "1260016258087387297", "name": "HARVESTER Dark Green", "type": "holder", "color": "#004a1f", "emoji_url": null, "collection": "seedling_dark_green", "display_name": "HARVESTER Dark Green"}, {"id": "1248728576770048140", "name": "HARVESTER Light Green", "type": "holder", "color": "#6bfb7d", "emoji_url": null, "collection": "seedling_light_green", "display_name": "HARVESTER Light Green"}]	f	t	t	t	t
1082504606690582601	CannaSolz420	2025-11-20 09:54:38.214065	[{"id": "1031946884262141992", "name": "holder_gold", "type": "holder", "color": "#d5ba46", "emoji_url": null, "collection": "CNSZ", "display_name": "🟨Holder🟨"}, {"id": "1034004776326791208", "name": "holder_silver", "type": "holder", "color": "#9aaaaa", "emoji_url": null, "collection": "CNSZ", "display_name": "⬜Holder⬜"}, {"id": "1034024392881098772", "name": "holder_purple", "type": "holder", "color": "#9b59b6", "emoji_url": null, "collection": "CNSZ", "display_name": "🟪Holder🟪"}, {"id": "1034024577673728080", "name": "holder_dark_green", "type": "holder", "color": "#004a1f", "emoji_url": null, "collection": "CNSZ", "display_name": "📗Holder📗"}, {"id": "1034024705562255410", "name": "holder_light_green", "type": "holder", "color": "#6bfb7d", "emoji_url": null, "collection": "CNSZ", "display_name": "🟩Holder🟩"}, {"id": "1216823615148916796", "name": "potter_any", "type": "holder", "color": "#725503", "emoji_url": null, "collection": "CNSZ", "display_name": "POTTER🪴"}, {"id": "1050104439811358731", "name": "token_holder_1", "type": "token", "color": "#fee88f", "emoji_url": null, "collection": "CNSZ", "display_name": "CannaSolz420 Token Holder"}, {"id": "1050106965461839962", "name": "token_holder_1k", "type": "token", "color": "#fee88f", "emoji_url": null, "collection": "CNSZ", "display_name": "CannaSolz420 Token (1k+)"}, {"id": "1050107832793571390", "name": "token_holder_5k", "type": "token", "color": "#fee88f", "emoji_url": null, "collection": "CNSZ", "display_name": "CannaSolz420 Token (5k+)"}, {"id": "1247550426501615666", "name": "token_holder_10k", "type": "token", "color": "#fee88f", "emoji_url": null, "collection": "CNSZ", "display_name": "CannaSolz420 Token (10k+)"}, {"id": "1247662904564514846", "name": "token_holder_25k", "type": "token", "color": "#fee88f", "emoji_url": null, "collection": "CNSZ", "display_name": "CannaSolz420 Token (25k+)"}, {"id": "1215479808599793684", "name": "og420", "type": "holder", "color": "#2ecc71", "emoji_url": null, "collection": "CNSZ", "display_name": "OG420"}, {"id": "1260017043005112330", "name": "HARVESTER Gold", "type": "holder", "color": "#d5ba46", "emoji_url": null, "collection": "seedling_gold", "display_name": "HARVESTER Gold"}, {"id": "1260016966324846592", "name": "HARVESTER Silver", "type": "holder", "color": "#9aaaaa", "emoji_url": null, "collection": "seedling_silver", "display_name": "HARVESTER Silver"}, {"id": "1260016886587068556", "name": "HARVESTER Purple", "type": "holder", "color": "#9b59b6", "emoji_url": null, "collection": "seedling_purple", "display_name": "HARVESTER Purple"}, {"id": "1260016258087387297", "name": "HARVESTER Dark Green", "type": "holder", "color": "#004a1f", "emoji_url": null, "collection": "seedling_dark_green", "display_name": "HARVESTER Dark Green"}, {"id": "1248728576770048140", "name": "HARVESTER Light Green", "type": "holder", "color": "#6bfb7d", "emoji_url": null, "collection": "seedling_light_green", "display_name": "HARVESTER Light Green"}, {"id": "1247188594431361146", "name": "collector", "type": "special", "color": "#9aafb6", "emoji_url": null, "collection": "CNSZ", "display_name": "COLLECTOR"}, {"id": "1246627805454929960", "name": "level_7_mashed", "type": "level", "color": "#2967ff", "emoji_url": null, "collection": "CNSZ", "display_name": "LEVEL 7: MASHED (20+)"}]	t	t	t	t	t
\.


--
-- TOC entry 3506 (class 0 OID 16524)
-- Dependencies: 218
-- Data for Name: user_wallets; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_wallets (id, discord_id, wallet_address, is_primary, connected_at, last_used, discord_name) FROM stdin;
80	290531269970755587	A6w5xnT64gbKQynkPmcPuSXiy6sUNK3cJpzdUTQWSrMZ	f	2025-11-19 02:32:14.479836	2025-11-19 02:32:14.479836	gob.1.
83	392070555102085130	Cs7hpLYxEaMde1DnyeJUAY4xcJAm2zTaGj6J88VhuTpH	f	2025-11-19 09:46:16.704629	2025-11-19 09:46:16.704629	Gaeaphile | tD P4L
85	392070555102085130	CCACZDCrttZiEwdVQus6BtMWHn6PWsnkqKw77xy7mLj9	f	2025-11-19 09:53:40.974204	2025-11-19 09:53:40.974204	gaeaphile
89	1082504606690582601	SDFAcEJgaHX5HWRfyW3evA8o9BDv6rVuXdhvnBAZHwq	f	2025-11-20 03:13:15.607273	2025-11-20 03:13:15.607273	snoopdfox
91	1082504606690582601	FksThXsojjxkWuEdgmruo86vS2monx2jNEzeKiNpp4Ha	f	2025-11-20 03:17:36.7051	2025-11-20 03:17:36.7051	snoopdfox
54	968226679963148318	BfBokuitRZSx4wf5v4jBLAp5AGmp6rfS55STzw3UzGJJ	t	2025-11-18 05:01:25.982482	2025-11-18 05:01:25.982482	jeffdukes1
45	890398220600115271	7azqm8HWqiqZPrcgWoBbtNc9HykxpzK5zGTuiJXkpzNZ	t	2025-11-16 23:48:30.437064	2025-11-16 23:48:30.437064	.shoeman
41	290531269970755587	AfVXtsmsbmeVDuYSTdEQdiJsYKsi8EKZEdzoTmRb8mQ	f	2025-11-16 18:14:58.932683	2025-11-16 18:14:58.957777	Gob1
37	931160720261939230	AcWwsEwgcEHz6rzUTXcnSksFZbETtc2JhA4jF7PKjp9T	f	2025-11-16 08:13:15.500443	2025-11-16 08:13:15.57073	Tom [SLOTTO]
\.


--
-- TOC entry 3528 (class 0 OID 0)
-- Dependencies: 222
-- Name: claim_transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.claim_transactions_id_seq', 1, false);


--
-- TOC entry 3529 (class 0 OID 0)
-- Dependencies: 226
-- Name: nft_metadata_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.nft_metadata_id_seq', 654, true);


--
-- TOC entry 3530 (class 0 OID 0)
-- Dependencies: 228
-- Name: roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.roles_id_seq', 35, true);


--
-- TOC entry 3531 (class 0 OID 0)
-- Dependencies: 231
-- Name: user_wallets_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.user_wallets_id_seq', 93, true);


--
-- TOC entry 3322 (class 2606 OID 16686)
-- Name: claim_transactions claim_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_transactions
    ADD CONSTRAINT claim_transactions_pkey PRIMARY KEY (id);


--
-- TOC entry 3326 (class 2606 OID 16688)
-- Name: collection_counts collection_counts_discord_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_counts
    ADD CONSTRAINT collection_counts_discord_id_key UNIQUE (discord_id);


--
-- TOC entry 3328 (class 2606 OID 16690)
-- Name: daily_rewards daily_rewards_new_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_rewards
    ADD CONSTRAINT daily_rewards_new_pkey PRIMARY KEY (discord_id);


--
-- TOC entry 3320 (class 2606 OID 16694)
-- Name: claim_accounts new_claim_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_accounts
    ADD CONSTRAINT new_claim_accounts_pkey PRIMARY KEY (discord_id);


--
-- TOC entry 3332 (class 2606 OID 16696)
-- Name: nft_metadata nft_metadata_mint_address_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nft_metadata
    ADD CONSTRAINT nft_metadata_mint_address_key UNIQUE (mint_address);


--
-- TOC entry 3334 (class 2606 OID 16698)
-- Name: nft_metadata nft_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nft_metadata
    ADD CONSTRAINT nft_metadata_pkey PRIMARY KEY (id);


--
-- TOC entry 3339 (class 2606 OID 16702)
-- Name: roles roles_discord_role_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_discord_role_id_key UNIQUE (discord_role_id);


--
-- TOC entry 3341 (class 2606 OID 16704)
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- TOC entry 3343 (class 2606 OID 16706)
-- Name: session session_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session
    ADD CONSTRAINT session_pkey PRIMARY KEY (sid);


--
-- TOC entry 3314 (class 2606 OID 16684)
-- Name: token_holders token_holders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.token_holders
    ADD CONSTRAINT token_holders_pkey PRIMARY KEY (wallet_address);


--
-- TOC entry 3316 (class 2606 OID 16712)
-- Name: user_wallets user_wallets_discord_id_wallet_address_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_wallets
    ADD CONSTRAINT user_wallets_discord_id_wallet_address_key UNIQUE (discord_id, wallet_address);


--
-- TOC entry 3318 (class 2606 OID 16714)
-- Name: user_wallets user_wallets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_wallets
    ADD CONSTRAINT user_wallets_pkey PRIMARY KEY (id);


--
-- TOC entry 3323 (class 1259 OID 16718)
-- Name: idx_claim_transactions_discord_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_claim_transactions_discord_id ON public.claim_transactions USING btree (discord_id);


--
-- TOC entry 3324 (class 1259 OID 16719)
-- Name: idx_claim_transactions_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_claim_transactions_status ON public.claim_transactions USING btree (status, created_at);


--
-- TOC entry 3329 (class 1259 OID 16723)
-- Name: idx_nft_metadata_symbol_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nft_metadata_symbol_name ON public.nft_metadata USING btree (symbol, name);


--
-- TOC entry 3336 (class 1259 OID 16724)
-- Name: idx_roles_discord_role_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_roles_discord_role_id ON public.roles USING btree (discord_role_id);


--
-- TOC entry 3337 (class 1259 OID 16725)
-- Name: idx_roles_type_collection; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_roles_type_collection ON public.roles USING btree (type, collection);


--
-- TOC entry 3312 (class 1259 OID 16717)
-- Name: idx_token_holders_owner_discord_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_token_holders_owner_discord_id ON public.token_holders USING btree (owner_discord_id);


--
-- TOC entry 3330 (class 1259 OID 16726)
-- Name: nft_lookup_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX nft_lookup_idx ON public.nft_metadata USING btree (symbol, name);


--
-- TOC entry 3335 (class 1259 OID 16727)
-- Name: nft_rank_lookup_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX nft_rank_lookup_idx ON public.nft_metadata USING btree (symbol, rarity_rank);


--
-- TOC entry 3344 (class 1259 OID 16728)
-- Name: user_roles_pkey; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_roles_pkey ON public.user_roles USING btree (discord_id);


--
-- TOC entry 3347 (class 2620 OID 16729)
-- Name: user_wallets add_bux_holder_on_wallet_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER add_bux_holder_on_wallet_insert AFTER INSERT ON public.user_wallets FOR EACH ROW EXECUTE FUNCTION public.insert_bux_holder_on_new_wallet();


--
-- TOC entry 3346 (class 2620 OID 229384)
-- Name: token_holders bux_holders_update_user_roles; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER bux_holders_update_user_roles AFTER INSERT OR DELETE OR UPDATE ON public.token_holders FOR EACH ROW EXECUTE FUNCTION public.update_user_roles_on_bux_change();


--
-- TOC entry 3351 (class 2620 OID 229383)
-- Name: collection_counts collection_counts_update_user_roles; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER collection_counts_update_user_roles AFTER INSERT OR DELETE OR UPDATE ON public.collection_counts FOR EACH ROW EXECUTE FUNCTION public.update_user_roles_on_collection_counts_change();


--
-- TOC entry 3350 (class 2620 OID 16735)
-- Name: claim_accounts set_claim_account_discord_name; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_claim_account_discord_name BEFORE INSERT OR UPDATE ON public.claim_accounts FOR EACH ROW EXECUTE FUNCTION public.sync_claim_account_discord_name();


--
-- TOC entry 3348 (class 2620 OID 16736)
-- Name: user_wallets trg_create_user_on_wallet_connect; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_create_user_on_wallet_connect AFTER INSERT ON public.user_wallets FOR EACH ROW EXECUTE FUNCTION public.create_user_on_wallet_connect();


--
-- TOC entry 3354 (class 2620 OID 106513)
-- Name: nft_metadata trg_update_collection_counts_on_metadata; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_update_collection_counts_on_metadata AFTER UPDATE OF owner_discord_id ON public.nft_metadata FOR EACH ROW WHEN ((new.owner_discord_id IS NOT NULL)) EXECUTE FUNCTION public.refresh_counts_on_metadata();


--
-- TOC entry 3352 (class 2620 OID 245767)
-- Name: collection_counts trg_update_daily_rewards_on_collection_counts; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_update_daily_rewards_on_collection_counts AFTER INSERT OR UPDATE ON public.collection_counts FOR EACH ROW EXECUTE FUNCTION public.trg_update_daily_rewards();


--
-- TOC entry 3349 (class 2620 OID 106511)
-- Name: user_wallets trg_update_nft_metadata_on_wallet_connect; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_update_nft_metadata_on_wallet_connect AFTER INSERT ON public.user_wallets FOR EACH ROW EXECUTE FUNCTION public.update_nft_metadata_on_wallet_connect();


--
-- TOC entry 3353 (class 2620 OID 254198)
-- Name: collection_counts trigger_rebuild_roles_on_collection_counts_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_rebuild_roles_on_collection_counts_update AFTER INSERT OR UPDATE ON public.collection_counts FOR EACH ROW EXECUTE FUNCTION public.rebuild_roles_on_collection_counts_update();


--
-- TOC entry 3355 (class 2620 OID 16738)
-- Name: nft_metadata update_nft_lister_details_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_nft_lister_details_trigger AFTER UPDATE OF original_lister ON public.nft_metadata FOR EACH ROW EXECUTE FUNCTION public.update_nft_lister_details();


--
-- TOC entry 3356 (class 2620 OID 16740)
-- Name: nft_metadata update_nft_owner_details_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_nft_owner_details_trigger AFTER UPDATE OF owner_wallet ON public.nft_metadata FOR EACH ROW EXECUTE FUNCTION public.update_nft_owner_details();


--
-- TOC entry 3345 (class 2606 OID 16741)
-- Name: claim_transactions claim_transactions_discord_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_transactions
    ADD CONSTRAINT claim_transactions_discord_id_fkey FOREIGN KEY (discord_id) REFERENCES public.user_roles(discord_id);


-- Completed on 2025-11-20 10:32:10 GMT

--
-- PostgreSQL database dump complete
--

