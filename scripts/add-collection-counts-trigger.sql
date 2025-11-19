-- Trigger function to rebuild user roles when collection_counts changes
CREATE OR REPLACE FUNCTION rebuild_roles_on_collection_counts_update()
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

-- Drop trigger if it exists
DROP TRIGGER IF EXISTS trigger_rebuild_roles_on_collection_counts_update ON collection_counts;

-- Create trigger on collection_counts table
CREATE TRIGGER trigger_rebuild_roles_on_collection_counts_update
  AFTER INSERT OR UPDATE ON collection_counts
  FOR EACH ROW
  EXECUTE FUNCTION rebuild_roles_on_collection_counts_update();

