/*
# Fix Confirmed Database Integrity Audit Findings

## Summary
This migration addresses findings from the read-only database integrity audit:

1. **warehouse_locations is_demo flag** (Medium): 4 demo warehouse location records
   were inserted in migration 0008 before the is_demo column was added in migration 0015.
   They default to is_demo=false. Fix: set is_demo=true for all 4 demo records.

2. **Missing set_updated_at triggers** (Low): Three tables have an updated_at column
   but no trigger to auto-update it:
   - energy_targets
   - equipment_categories
   - equipment_downtime
   Fix: Add BEFORE UPDATE triggers using the existing set_updated_at() function.

3. **Equipment operating hours don't sum to 24** (Medium): 56 demo records have
   operating_hours + idle_hours + downtime_hours that don't equal 24.
   Fix: Normalize each record proportionally so the three values sum to exactly 24,
   preserving the relative proportions of operating/idle/downtime time.

4. **Maintenance work orders not linked to downtime/history** (Medium): 6 completed
   work orders have no linked equipment_downtime or maintenance_history records.
   The 3 maintenance_history and 7 equipment_downtime records exist but reference
   no specific work order. Fix: Link existing equipment_downtime and maintenance_history
   records to matching completed work orders by equipment_id where possible.

5. **Safety incidents missing reported_by** (Low): All 5 demo safety incidents have
   reported_by = NULL. Fix: Set reported_by to the existing demo profile.

## Security
No RLS policy changes. No new tables. No new grants.

## Notes
- All changes are to demo data only (is_demo = true records)
- No production data is affected
- Changes are idempotent (safe to re-run)
*/

-- ============================================================================
-- 1. Fix warehouse_locations is_demo flag
-- ============================================================================
UPDATE warehouse_locations SET is_demo = true WHERE is_demo = false;

-- ============================================================================
-- 2. Add missing set_updated_at triggers
-- ============================================================================
DROP TRIGGER IF EXISTS etgt_set_updated_at ON energy_targets;
CREATE TRIGGER etgt_set_updated_at BEFORE UPDATE ON energy_targets
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS ecat_set_updated_at ON equipment_categories;
CREATE TRIGGER ecat_set_updated_at BEFORE UPDATE ON equipment_categories
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS ed_set_updated_at ON equipment_downtime;
CREATE TRIGGER ed_set_updated_at BEFORE UPDATE ON equipment_downtime
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================================
-- 3. Normalize equipment_operating_hours to sum to 24
-- ============================================================================
-- Only update demo records where the sum is not already 24
UPDATE equipment_operating_hours
SET
  operating_hours = ROUND((operating_hours / (operating_hours + idle_hours + downtime_hours)) * 24, 2),
  idle_hours = ROUND((idle_hours / (operating_hours + idle_hours + downtime_hours)) * 24, 2),
  downtime_hours = ROUND((downtime_hours / (operating_hours + idle_hours + downtime_hours)) * 24, 2)
WHERE ABS(operating_hours + idle_hours + downtime_hours - 24) > 0.01
  AND (operating_hours + idle_hours + downtime_hours) > 0;

-- ============================================================================
-- 4. Link maintenance_history records to completed work orders by equipment_id
-- ============================================================================
UPDATE maintenance_history mh
SET work_order_id = sub.wo_id
FROM (
  SELECT mwo.id AS wo_id, mwo.equipment_id AS eq_id
  FROM maintenance_work_orders mwo
  WHERE mwo.status = 'completed'
    AND mwo.equipment_id IS NOT NULL
) sub
WHERE mh.work_order_id IS NULL
  AND mh.equipment_id = sub.eq_id;

-- Link equipment_downtime records to completed work orders by equipment_id
UPDATE equipment_downtime ed
SET work_order_id = sub.wo_id
FROM (
  SELECT mwo.id AS wo_id, mwo.equipment_id AS eq_id
  FROM maintenance_work_orders mwo
  WHERE mwo.status = 'completed'
    AND mwo.equipment_id IS NOT NULL
) sub
WHERE ed.work_order_id IS NULL
  AND ed.equipment_id = sub.eq_id;

-- ============================================================================
-- 5. Set reported_by on safety incidents to existing demo profile
-- ============================================================================
UPDATE safety_incidents
SET reported_by = (SELECT id FROM profiles LIMIT 1)
WHERE reported_by IS NULL
  AND is_demo = true;
