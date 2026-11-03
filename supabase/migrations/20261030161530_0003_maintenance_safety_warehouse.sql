/*
# Maintenance, Safety, and Warehouse Domains

## Purpose
Implements maintenance work order management, safety incident tracking,
and warehouse/inventory control for the CHANGLONG INTELLIGENCE platform.

## New Tables

### maintenance_work_orders
- `id`, `work_order_number` (unique), `equipment_id` (FK), `type` (enum: preventive/corrective/predictive/inspection),
  `priority` (enum: low/medium/high/critical), `status` (enum: open/in_progress/completed/cancelled/overdue),
  `assigned_to` (FK profiles), `description`, `scheduled_date`, `completed_date`,
  `downtime_hours` (numeric), `cost` (numeric), `is_demo`, timestamps

### maintenance_schedules
- `id`, `equipment_id` (FK), `frequency_days` (int), `next_due_date` (date),
  `procedure` (text), `is_active`, `is_demo`, timestamps

### warehouse_items
- `id`, `item_code` (unique), `name`, `category_id` (FK), `unit` (text),
  `current_stock` (numeric), `min_stock` (numeric), `max_stock` (numeric),
  `unit_cost` (numeric), `is_demo`, timestamps

### warehouse_categories
- `id`, `name`, `code` (unique), `description`, timestamps

### inventory_movements
- `id`, `item_id` (FK), `movement_type` (enum: incoming/outgoing/adjustment),
  `quantity` (numeric), `reference` (text), `performed_by` (FK profiles),
  `is_demo`, timestamps

### safety_incidents
- `id`, `incident_number` (unique), `title`, `description`, `severity` (enum: minor/moderate/serious/critical),
  `status` (enum: reported/investigating/resolved/closed), `department_id` (FK),
  `reported_by` (FK profiles), `incident_date` (timestamptz), `resolution_date` (timestamptz),
  `is_demo`, timestamps

### notifications
- `id`, `user_id` (FK profiles), `title`, `message`, `severity` (enum: info/warning/critical),
  `category` (text), `is_read` (bool), `created_at`

## Security
- RLS on all tables.
- Maintenance: authenticated read; service_role write.
- Safety incidents: restricted read (admins, safety_officer, managers) due to sensitive incident info.
- Warehouse: authenticated read; service_role write. Stock movements use an atomic SECURITY DEFINER function.
- Notifications: users read/update only their own.

## Important Notes
1. `record_inventory_movement` is a SECURITY DEFINER function that atomically adjusts stock and logs the movement,
   preventing negative stock and race conditions.
2. Safety incidents contain sensitive information — access is restricted to privileged roles.
3. Notifications are user-scoped with ownership-based RLS.
*/

-- ============================================================
-- ENUM TYPES
-- ============================================================
DO $$ BEGIN
  CREATE TYPE maintenance_type AS ENUM ('preventive', 'corrective', 'predictive', 'inspection');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE priority_level AS ENUM ('low', 'medium', 'high', 'critical');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE work_order_status AS ENUM ('open', 'in_progress', 'completed', 'cancelled', 'overdue');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE movement_type AS ENUM ('incoming', 'outgoing', 'adjustment');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE incident_severity AS ENUM ('minor', 'moderate', 'serious', 'critical');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE incident_status AS ENUM ('reported', 'investigating', 'resolved', 'closed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE notification_severity AS ENUM ('info', 'warning', 'critical');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- MAINTENANCE WORK ORDERS
-- ============================================================
CREATE TABLE IF NOT EXISTS maintenance_work_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  work_order_number text NOT NULL UNIQUE,
  equipment_id uuid REFERENCES equipment(id) ON DELETE SET NULL,
  type maintenance_type NOT NULL DEFAULT 'corrective',
  priority priority_level NOT NULL DEFAULT 'medium',
  status work_order_status NOT NULL DEFAULT 'open',
  assigned_to uuid REFERENCES profiles(id) ON DELETE SET NULL,
  description text,
  scheduled_date date,
  completed_date date,
  downtime_hours numeric(8,2) DEFAULT 0,
  cost numeric(12,2) DEFAULT 0,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE maintenance_work_orders ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON maintenance_work_orders TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON maintenance_work_orders TO service_role;

DROP POLICY IF EXISTS "wo_select_auth" ON maintenance_work_orders;
CREATE POLICY "wo_select_auth" ON maintenance_work_orders FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "wo_service" ON maintenance_work_orders;
CREATE POLICY "wo_service" ON maintenance_work_orders FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_wo_equip ON maintenance_work_orders(equipment_id);
CREATE INDEX IF NOT EXISTS idx_wo_status ON maintenance_work_orders(status);
CREATE INDEX IF NOT EXISTS idx_wo_assigned ON maintenance_work_orders(assigned_to);

-- ============================================================
-- MAINTENANCE SCHEDULES
-- ============================================================
CREATE TABLE IF NOT EXISTS maintenance_schedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid REFERENCES equipment(id) ON DELETE CASCADE,
  frequency_days integer NOT NULL CHECK (frequency_days > 0),
  next_due_date date NOT NULL,
  procedure text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE maintenance_schedules ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON maintenance_schedules TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON maintenance_schedules TO service_role;

DROP POLICY IF EXISTS "msched_select_auth" ON maintenance_schedules;
CREATE POLICY "msched_select_auth" ON maintenance_schedules FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "msched_service" ON maintenance_schedules;
CREATE POLICY "msched_service" ON maintenance_schedules FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_msched_equip ON maintenance_schedules(equipment_id);

-- ============================================================
-- WAREHOUSE CATEGORIES
-- ============================================================
CREATE TABLE IF NOT EXISTS warehouse_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  code text NOT NULL UNIQUE,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE warehouse_categories ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON warehouse_categories TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON warehouse_categories TO service_role;

DROP POLICY IF EXISTS "wcat_select_auth" ON warehouse_categories;
CREATE POLICY "wcat_select_auth" ON warehouse_categories FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "wcat_service" ON warehouse_categories;
CREATE POLICY "wcat_service" ON warehouse_categories FOR ALL
  TO service_role USING (true) WITH CHECK (true);

-- ============================================================
-- WAREHOUSE ITEMS
-- ============================================================
CREATE TABLE IF NOT EXISTS warehouse_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_code text NOT NULL UNIQUE,
  name text NOT NULL,
  category_id uuid REFERENCES warehouse_categories(id) ON DELETE SET NULL,
  unit text NOT NULL DEFAULT 'pcs',
  current_stock numeric(12,2) NOT NULL DEFAULT 0,
  min_stock numeric(12,2) NOT NULL DEFAULT 0,
  max_stock numeric(12,2) NOT NULL DEFAULT 0,
  unit_cost numeric(12,2) DEFAULT 0,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE warehouse_items ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON warehouse_items TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON warehouse_items TO service_role;

DROP POLICY IF EXISTS "witem_select_auth" ON warehouse_items;
CREATE POLICY "witem_select_auth" ON warehouse_items FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "witem_service" ON warehouse_items;
CREATE POLICY "witem_service" ON warehouse_items FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_witem_cat ON warehouse_items(category_id);

-- ============================================================
-- INVENTORY MOVEMENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS inventory_movements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid REFERENCES warehouse_items(id) ON DELETE CASCADE,
  movement_type movement_type NOT NULL,
  quantity numeric(12,2) NOT NULL,
  reference text,
  performed_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE inventory_movements ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON inventory_movements TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON inventory_movements TO service_role;

DROP POLICY IF EXISTS "imov_select_auth" ON inventory_movements;
CREATE POLICY "imov_select_auth" ON inventory_movements FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "imov_service" ON inventory_movements;
CREATE POLICY "imov_service" ON inventory_movements FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_imov_item ON inventory_movements(item_id);
CREATE INDEX IF NOT EXISTS idx_imov_created ON inventory_movements(created_at);

-- ============================================================
-- ATOMIC INVENTORY MOVEMENT FUNCTION
-- ============================================================
CREATE OR REPLACE FUNCTION public.record_inventory_movement(
  p_item_id uuid,
  p_movement_type movement_type,
  p_quantity numeric,
  p_reference text DEFAULT NULL,
  p_performed_by uuid DEFAULT NULL,
  p_is_demo boolean DEFAULT false
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_stock numeric(12,2);
  v_movement_id uuid;
BEGIN
  IF p_quantity <= 0 THEN
    RAISE EXCEPTION 'Quantity must be positive (use movement_type for direction)';
  END IF;

  SELECT current_stock INTO v_new_stock
  FROM warehouse_items WHERE id = p_item_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Warehouse item % not found', p_item_id;
  END IF;

  IF p_movement_type = 'incoming' THEN
    v_new_stock := v_new_stock + p_quantity;
  ELSIF p_movement_type = 'outgoing' THEN
    v_new_stock := v_new_stock - p_quantity;
    IF v_new_stock < 0 THEN
      RAISE EXCEPTION 'Insufficient stock for item %. Available: %, Requested: %',
        p_item_id, (SELECT current_stock FROM warehouse_items WHERE id = p_item_id), p_quantity;
    END IF;
  ELSIF p_movement_type = 'adjustment' THEN
    v_new_stock := p_quantity;
  END IF;

  UPDATE warehouse_items SET current_stock = v_new_stock, updated_at = now()
  WHERE id = p_item_id;

  INSERT INTO inventory_movements (item_id, movement_type, quantity, reference, performed_by, is_demo)
  VALUES (p_item_id, p_movement_type,
    CASE WHEN p_movement_type = 'adjustment' THEN p_quantity ELSE p_quantity END,
    p_reference, p_performed_by, p_is_demo)
  RETURNING id INTO v_movement_id;

  RETURN v_movement_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.record_inventory_movement(uuid, movement_type, numeric, text, uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_inventory_movement(uuid, movement_type, numeric, text, uuid, boolean) TO authenticated, service_role;

-- ============================================================
-- SAFETY INCIDENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS safety_incidents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_number text NOT NULL UNIQUE,
  title text NOT NULL,
  description text,
  severity incident_severity NOT NULL DEFAULT 'minor',
  status incident_status NOT NULL DEFAULT 'reported',
  department_id uuid REFERENCES departments(id) ON DELETE SET NULL,
  reported_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  incident_date timestamptz NOT NULL DEFAULT now(),
  resolution_date timestamptz,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE safety_incidents ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON safety_incidents TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON safety_incidents TO service_role;

-- Restricted read: admins, plant directors, managers, safety officers
DROP POLICY IF EXISTS "safety_select_privileged" ON safety_incidents;
CREATE POLICY "safety_select_privileged" ON safety_incidents FOR SELECT
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager', 'safety_officer'))
  );

DROP POLICY IF EXISTS "safety_service" ON safety_incidents;
CREATE POLICY "safety_service" ON safety_incidents FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_safety_dept ON safety_incidents(department_id);
CREATE INDEX IF NOT EXISTS idx_safety_status ON safety_incidents(status);
CREATE INDEX IF NOT EXISTS idx_safety_severity ON safety_incidents(severity);

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title text NOT NULL,
  message text,
  severity notification_severity NOT NULL DEFAULT 'info',
  category text,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
GRANT SELECT, UPDATE ON notifications TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON notifications TO service_role;

DROP POLICY IF EXISTS "notif_select_own" ON notifications;
CREATE POLICY "notif_select_own" ON notifications FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "notif_update_own" ON notifications;
CREATE POLICY "notif_update_own" ON notifications FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "notif_service" ON notifications;
CREATE POLICY "notif_service" ON notifications FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_notif_user_read ON notifications(user_id, is_read);

-- ============================================================
-- AUDIT LOGS
-- ============================================================
CREATE TABLE IF NOT EXISTS audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  action text NOT NULL,
  entity_type text,
  entity_id uuid,
  details jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON audit_logs TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON audit_logs TO service_role;

-- Admins can read audit logs
DROP POLICY IF EXISTS "audit_select_admin" ON audit_logs;
CREATE POLICY "audit_select_admin" ON audit_logs FOR SELECT
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director'))
  );

DROP POLICY IF EXISTS "audit_service" ON audit_logs;
CREATE POLICY "audit_service" ON audit_logs FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_entity ON audit_logs(entity_type, entity_id);

-- ============================================================
-- UPDATED_AT TRIGGERS
-- ============================================================
DROP TRIGGER IF EXISTS wo_set_updated_at ON maintenance_work_orders;
CREATE TRIGGER wo_set_updated_at BEFORE UPDATE ON maintenance_work_orders
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS msched_set_updated_at ON maintenance_schedules;
CREATE TRIGGER msched_set_updated_at BEFORE UPDATE ON maintenance_schedules
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS witem_set_updated_at ON warehouse_items;
CREATE TRIGGER witem_set_updated_at BEFORE UPDATE ON warehouse_items
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS wcat_set_updated_at ON warehouse_categories;
CREATE TRIGGER wcat_set_updated_at BEFORE UPDATE ON warehouse_categories
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS safety_set_updated_at ON safety_incidents;
CREATE TRIGGER safety_set_updated_at BEFORE UPDATE ON safety_incidents
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
