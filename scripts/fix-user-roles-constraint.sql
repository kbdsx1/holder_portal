-- Fix user_roles table to add unique constraint on discord_id
-- This fixes the ON CONFLICT errors in triggers and sync functions

-- Add unique constraint if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'user_roles_discord_id_key'
    ) THEN
        ALTER TABLE user_roles ADD CONSTRAINT user_roles_discord_id_key UNIQUE (discord_id);
    END IF;
END $$;

-- Fix the create_user_on_wallet_connect trigger function
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
    ON CONFLICT (discord_id) DO UPDATE SET discord_name = EXCLUDED.discord_name;

    INSERT INTO claim_accounts (discord_id, unclaimed_amount, total_claimed, last_claim_time)
    VALUES (NEW.discord_id, 0, 0, CURRENT_TIMESTAMP)
    ON CONFLICT (discord_id) DO NOTHING;

    INSERT INTO daily_rewards (discord_id, discord_name, total_daily_reward, is_processed)
    VALUES (NEW.discord_id, NEW.discord_name, 0, false)
    ON CONFLICT (discord_id) DO NOTHING;
  END IF;

  INSERT INTO collection_counts (
    discord_id, discord_name, total_count, last_updated,
    underground_count, outer_count, motor_city_count, neon_row_count,
    city_gardens_count, stream_town_count, jabberjaw_count, none_count, og_total_count,
    yotr_underground_count, yotr_outer_count, yotr_motor_city_count, yotr_neon_row_count,
    yotr_city_gardens_count, yotr_stream_town_count, yotr_jabberjaw_count, yotr_nomad_count, yotr_total_count,
    art_count,
    pinups_total_count, pinups_underground_count, pinups_outer_count, pinups_motor_city_count,
    pinups_neon_row_count, pinups_city_gardens_count, pinups_stream_town_count, pinups_jabberjaw_count
  )
  VALUES (
    NEW.discord_id, NEW.discord_name, 0, CURRENT_TIMESTAMP,
    0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0,
    0,
    0, 0, 0, 0, 0, 0, 0, 0
  )
  ON CONFLICT (discord_id) DO NOTHING;

  RETURN NEW;
END;
$$;

-- The rebuild_roles_on_collection_counts_update function should now work with the constraint
-- But let's make sure it's correct
CREATE OR REPLACE FUNCTION public.rebuild_roles_on_collection_counts_update()
RETURNS TRIGGER AS $$
BEGIN
  -- Rebuild roles JSONB array
  PERFORM rebuild_user_roles(NEW.discord_id);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

