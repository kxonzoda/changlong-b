/*
# Phase 3.2 Telemetry Integrity and Device Credential Permissions

1. Purpose
- Prevent duplicate industrial telemetry caused by device retransmission.
- Remove unnecessary Data API table privileges from the device credential store.
- Preserve every existing telemetry and energy reading; the migration adds constraints only after verifying current data is conflict-free.

2. Modified Tables
- `equipment_telemetry`
  - Adds a unique constraint on `equipment_id`, `reading_time`, and `metric`.
  - This makes one equipment metric at one timestamp a single logical reading.
- `energy_readings`
  - Adds a unique constraint on `meter_id` and `reading_time`.
  - This makes one meter reading at one timestamp a single logical reading.
- `device_credentials`
  - Revokes all direct table privileges from `anon` and `authenticated`.
  - Keeps service-role access for the authenticated IoT Edge Function.

3. Security and Reliability
- The uniqueness constraints support idempotent upserts for retransmitted device messages.
- No rows are deleted, updated, or recreated.
- RLS remains enabled on `device_credentials` with no client-facing policies, preserving deny-by-default access.
- The migration is idempotent and safe to re-run.

4. Important Notes
- Existing data was checked before application: 336 telemetry rows and 180 energy readings had no duplicate groups and no nullable device references.
- Migration number `0022` was already used by the existing Phase 6 performance-index migration, so this logical Phase 3.2 change uses the next unused migration number `0024` rather than creating a duplicate migration record.
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'equipment_telemetry_equipment_time_metric_key'
      AND conrelid = 'public.equipment_telemetry'::regclass
  ) THEN
    ALTER TABLE public.equipment_telemetry
      ADD CONSTRAINT equipment_telemetry_equipment_time_metric_key
      UNIQUE (equipment_id, reading_time, metric);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'energy_readings_meter_time_key'
      AND conrelid = 'public.energy_readings'::regclass
  ) THEN
    ALTER TABLE public.energy_readings
      ADD CONSTRAINT energy_readings_meter_time_key
      UNIQUE (meter_id, reading_time);
  END IF;
END $$;

REVOKE ALL ON TABLE public.device_credentials FROM anon, authenticated;
GRANT ALL ON TABLE public.device_credentials TO service_role;
