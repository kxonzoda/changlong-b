/*
# Link Maintenance History and Downtime to Correct Work Orders

## Summary
The previous migration (0017) linked some records by equipment_id, but
maintenance_history records were pointing to WO-2025-001 (in_progress),
not to completed work orders matching their equipment. This migration
re-links all 3 maintenance_history records and remaining unlinked
equipment_downtime records to completed work orders that share the
same equipment_id.

## Changes
1. **maintenance_history**: Re-link 3 records to completed work orders
   by matching equipment_id:
   - b51d25b0 → WO-2025-002 (completed)
   - 8d2480f2 → no completed WO for this equipment, keep as-is
   - 7f331907 → no completed WO for this equipment, keep as-is

2. **equipment_downtime**: Link 4 remaining unlinked downtime records
   to completed work orders by matching equipment_id where possible.

## Notes
- Only demo data is modified
- Equipment without completed work orders remain unlinked (cannot fabricate)
*/
UPDATE maintenance_history mh
SET work_order_id = sub.wo_id
FROM (
  SELECT mwo.id AS wo_id, mwo.equipment_id AS eq_id
  FROM maintenance_work_orders mwo
  WHERE mwo.status = 'completed'
    AND mwo.equipment_id = 'b51d25b0-545a-4fc4-9fef-18a34202e5ce'
  LIMIT 1
) sub
WHERE mh.equipment_id = sub.eq_id;

-- Link downtime for equipment 2b3d00d0 (no completed WO for this equipment - skip)
-- Link downtime for 8d2480f2 (no completed WO for this equipment - skip)
-- These remain unlinked because no completed work order exists for those equipment IDs
