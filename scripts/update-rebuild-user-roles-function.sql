-- Update rebuild_user_roles function to include COLLECTOR and LEVEL roles
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
$function$;

