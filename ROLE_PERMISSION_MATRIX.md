# Role Permission Matrix

CHANGLONG INTELLIGENCE uses role-based access control (RBAC) enforced at the database layer via Row Level Security (RLS) policies. The frontend `user_role` enum maps to 11 distinct roles, each with scoped read/write permissions across the 11 operational domains.

## Roles Overview

| Role | Description | Scope |
|------|-------------|-------|
| `admin` | System administrator | Full access to all domains, including user management |
| `plant_director` | Plant director | Read access to all domains; executive dashboards |
| `manager` | Operations manager | Read access to most domains; limited HR write |
| `production_manager` | Production manager | Production, equipment, quality domains |
| `engineer` | Process engineer | Production, equipment, energy telemetry |
| `energy_manager` | Energy manager | Energy domain only |
| `maintenance_manager` | Maintenance manager | Maintenance, equipment, warehouse |
| `safety_officer` | Safety officer | Safety, environmental domains |
| `warehouse_manager` | Warehouse manager | Warehouse, inventory, purchasing |
| `operator` | Floor operator | Production records, equipment status |
| `viewer` | Read-only viewer | Read access to non-sensitive operational data |

## Permission Levels

- **R** = Read (SELECT)
- **W** = Write (INSERT/UPDATE/DELETE) — handled via edge functions or RPC
- **—** = No access (RLS blocks entirely)

## Domain Permission Matrix

### Organization
| Role | departments | profiles | shifts | employees |
|------|-----------|----------|--------|-----------|
| admin | R/W | R/W | R/W | R/W |
| plant_director | R | R | R | R |
| manager | R | R | R | R |
| production_manager | R | R | R | — |
| engineer | R | R | R | — |
| energy_manager | R | R | — | — |
| maintenance_manager | R | R | R | — |
| safety_officer | R | R | — | R |
| warehouse_manager | R | R | — | — |
| operator | R | R (self) | R (own shift) | — |
| viewer | R | R (self) | — | — |

### Production
| Role | production_lines | production_batches | production_records | production_targets | production_events |
|------|-----------------|-------------------|--------------------|--------------------|-------------------|
| admin | R/W | R/W | R/W | R/W | R/W |
| plant_director | R | R | R | R | R |
| manager | R | R | R | R | R |
| production_manager | R | R/W | R/W | R/W | R/W |
| engineer | R | R | R/W | R | R |
| energy_manager | R | R | R | — | — |
| maintenance_manager | R | R | R | — | — |
| safety_officer | R | R | R | — | — |
| warehouse_manager | R | — | — | — | — |
| operator | R | R | R/W | — | R |
| viewer | R | R | R | — | — |

### Energy
| Role | energy_meters | energy_readings | energy_consumption_daily | energy_targets | energy_cost_records |
|------|--------------|-----------------|--------------------------|---------------|--------------------|
| admin | R/W | R/W | R/W | R/W | R/W |
| plant_director | R | R | R | R | R |
| manager | R | R | R | R | R |
| production_manager | R | R | R | — | — |
| engineer | R | R/W | R | — | — |
| energy_manager | R/W | R/W | R | R/W | R/W |
| maintenance_manager | R | R | R | — | — |
| safety_officer | — | — | — | — | — |
| warehouse_manager | — | — | — | — | — |
| operator | R | R | R | — | — |
| viewer | R | R | R | — | — |

### Equipment
| Role | equipment_categories | equipment | equipment_telemetry | equipment_status_history |
|------|--------------------|-----------|--------------------|--------------------------|
| admin | R/W | R/W | R/W | R/W |
| plant_director | R | R | R | R |
| manager | R | R | R | R |
| production_manager | R | R | R | R |
| engineer | R | R/W | R/W | R |
| energy_manager | R | R | R | — |
| maintenance_manager | R | R/W | R/W | R/W |
| safety_officer | R | R | R | R |
| warehouse_manager | — | — | — | — |
| operator | R | R | R | R |
| viewer | R | R | R | — |

### Maintenance
| Role | maintenance_work_orders | maintenance_schedules | corrective_actions |
|------|------------------------|----------------------|--------------------|
| admin | R/W | R/W | R/W |
| plant_director | R | R | R |
| manager | R/W | R/W | R/W |
| production_manager | R | R | R |
| engineer | R/W | R | R/W |
| energy_manager | — | — | — |
| maintenance_manager | R/W | R/W | R/W |
| safety_officer | R | R | R |
| warehouse_manager | R | R | — |
| operator | R | — | — |
| viewer | R | R | — |

### Quality
| Role | quality_standards | quality_inspections | quality_measurements | quality_defects |
|------|-----------------|--------------------|--------------------|----------------|
| admin | R/W | R/W | R/W | R/W |
| plant_director | R | R | R | R |
| manager | R | R | R | R |
| production_manager | R/W | R/W | R/W | R/W |
| engineer | R | R/W | R/W | R |
| energy_manager | — | — | — | — |
| maintenance_manager | R | R | R | R |
| safety_officer | R | R | R | R |
| warehouse_manager | — | — | — | — |
| operator | R | R/W | R | R |
| viewer | R | R | — | — |

### Safety
| Role | safety_incidents | safety_inspections | safety_observations |
|------|-----------------|--------------------|--------------------|
| admin | R/W | R/W | R/W |
| plant_director | R | R | R |
| manager | R | R | R |
| production_manager | R | R | R |
| engineer | R | — | R |
| energy_manager | — | — | — |
| maintenance_manager | R | R | R |
| safety_officer | R/W | R/W | R/W |
| warehouse_manager | — | — | — |
| operator | R | — | R/W |
| viewer | R | — | — |

### Warehouse
| Role | warehouse_categories | warehouse_items | inventory_movements | suppliers | purchase_requests | warehouse_locations |
|------|--------------------|-----------------|--------------------|-----------|--------------------|--------------------|
| admin | R/W | R/W | R/W | R/W | R/W | R/W |
| plant_director | R | R | R | R | R | R |
| manager | R | R | R | R | R | R |
| production_manager | R | R | — | R | — | R |
| engineer | R | R | — | — | — | R |
| energy_manager | — | — | — | — | — | — |
| maintenance_manager | R | R | R/W | R | R | R |
| safety_officer | — | — | — | — | — | — |
| warehouse_manager | R/W | R/W | R/W | R/W | R/W | R/W |
| operator | R | R | — | — | — | R |
| viewer | R | R | — | — | — | R |

### Environmental
| Role | environmental_readings | emission_records | waste_records | environmental_targets |
|------|-----------------------|-----------------|--------------|--------------------|
| admin | R/W | R/W | R/W | R/W |
| plant_director | R | R | R | R |
| manager | R | R | R | R |
| production_manager | R | R | R | — |
| engineer | R | R | — | — |
| energy_manager | R | R/W | — | — |
| maintenance_manager | — | — | — | — |
| safety_officer | R/W | R/W | R/W | R/W |
| warehouse_manager | — | — | — | — |
| operator | R | R | — | — |
| viewer | R | R | — | — |

### Workforce
| Role | attendance_records | qualifications | training_records |
|------|-------------------|---------------|----------------|
| admin | R/W | R/W | R/W |
| plant_director | R | R | R |
| manager | R/W | R | R/W |
| production_manager | R | — | R |
| engineer | — | — | — |
| energy_manager | — | — | — |
| maintenance_manager | R | — | R |
| safety_officer | R | R | R/W |
| warehouse_manager | — | — | — |
| operator | R (self) | R (self) | R (self) |
| viewer | — | — | — |

### Notifications & Audit
| Role | notifications | notification_preferences | audit_logs |
|------|--------------|-------------------------|------------|
| admin | R/W (all) | R/W | R |
| plant_director | R (own) | R | R |
| manager | R (own) | R | R |
| all other roles | R/W (own) | R/W (own) | — |
| viewer | R/W (own) | R/W (own) | — |

## Implementation Notes

1. **RLS is enforced at the database level** — the frontend cannot bypass it. All queries run as the `authenticated` role with the user's JWT context.

2. **Writes are primarily handled via edge functions** using the `service_role` key, which bypasses RLS. This allows server-side validation before mutations reach the database.

3. **`record_inventory_movement()`** is a `SECURITY DEFINER` RPC function callable by `authenticated` users. It performs atomic inventory mutations with server-side quantity validation (prevents negative stock). This is an intentional privileged-mutation pattern, not a security gap.

4. **Sensitive tables** (safety_incidents, employees, attendance_records, qualifications, training_records) are restricted to admin/manager/safety_officer roles for read access, preventing operators and viewers from seeing personnel data.

5. **Profile access** — every authenticated user can read and update their own profile. Only admin can read all profiles.

6. **Demo data** (`is_demo = true`) follows the same RLS rules as production data — the flag is for safe cleanup, not access control.

## Role Assignment

Roles are assigned during signup via the profile creation trigger (`handle_new_user`). The default role for new signups is `viewer`. Admins can upgrade roles via direct database access or an admin panel (future enhancement).

## Adding a New Role

1. Add the role to the `user_role` PostgreSQL enum: `ALTER TYPE user_role ADD VALUE 'new_role';`
2. Update RLS policies on each affected table to include the new role.
3. Add the role to `src/types/database.ts` UserRole type.
4. Update this matrix.
5. Add UI conditionals if the role needs specific navigation.
