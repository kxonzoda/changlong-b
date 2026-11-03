# API & Service Reference

Complete reference for all frontend service modules and Supabase edge functions in the CHANGLONG INTELLIGENCE platform.

## Table of Contents
1. [Service Architecture](#service-architecture)
2. [Auth Service](#auth-service)
3. [Organization Service](#organization-service)
4. [Production Service](#production-service)
5. [Energy Service](#energy-service)
6. [Equipment Service](#equipment-service)
7. [Maintenance Service](#maintenance-service)
8. [Maintenance Analytics Service](#maintenance-analytics-service)
9. [Quality Service](#quality-service)
10. [Safety Service](#safety-service)
11. [Warehouse Service](#warehouse-service)
12. [Environment Service](#environment-service)
13. [Workforce Service](#workforce-service)
14. [Notification Service](#notification-service)
15. [Overview Service](#overview-service)
16. [Admin Service](#admin-service)
17. [Analytics Service](#analytics-service)
18. [Edge Functions](#edge-functions)

---

## Service Architecture

All services follow a consistent pattern:

```
src/services/
├── serviceError.ts              # Shared error class
├── authService.ts               # Authentication
├── adminService.ts              # Admin user management & audit
├── analyticsService.ts          # KPI analytics & business logic
├── overviewService.ts           # Dashboard KPI aggregation
├── organizationService.ts       # Departments, shifts, lines
├── productionService.ts         # Production records, batches, shifts
├── energyService.ts             # Energy meters, readings, sources, anomalies
├── equipmentService.ts          # Equipment, telemetry, events, components
├── maintenanceService.ts        # Work orders, schedules, downtime
├── maintenanceAnalyticsService.ts # MTBF, MTTR, procedures, parts
├── qualityService.ts            # Inspections, measurements, batches, lab results
├── safetyService.ts             # Incidents, inspections, risk assessments
├── warehouseService.ts          # Inventory, stock movements, transactions
├── environmentService.ts         # Environmental readings, alerts
├── workforceService.ts          # Employees, attendance, qualifications
└── notificationService.ts        # User notifications
```

### ServiceError

```typescript
export class ServiceError extends Error {
  status: number;
  details?: unknown;
  static fromSupabaseError(error: { code?: string; message: string; details?: unknown }): ServiceError;
}
```

All service methods throw `ServiceError` on failure.

### Supabase Client

```typescript
import { createClient } from '@supabase/supabase-js';
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;
export const supabase = createClient(supabaseUrl, supabaseAnonKey);
```

---

## Auth Service

File: `src/services/authService.ts`

| Method | Signature | Description |
|--------|-----------|-------------|
| `signIn` | `(email: string, password: string) => Promise<void>` | Sign in with email/password |
| `signUp` | `(email: string, password: string, fullName?: string) => Promise<void>` | Create account, profile auto-created |
| `signOut` | `() => Promise<void>` | End session |
| `getCurrentProfile` | `() => Promise<Profile \| null>` | Fetch current user's profile |
| `updateProfile` | `(updates: Partial<Pick<Profile, 'full_name' \| 'phone' \| 'language'>>) => Promise<void>` | Update own profile |
| `resetPassword` | `(email: string) => Promise<void>` | Send password reset email |
| `hasRole` | `(profile: Profile, ...roles: UserRole[]) => boolean` | Check role membership |

---

## Organization Service

File: `src/services/organizationService.ts`

| Method | Signature | Description |
|--------|-----------|-------------|
| `getDepartments` | `() => Promise<Department[]>` | All active departments |
| `getShifts` | `() => Promise<Shift[]>` | All active shifts |
| `getProductionLines` | `() => Promise<ProductionLine[]>` | All active production lines |

---

## Production Service

File: `src/services/productionService.ts`

| Method | Signature | Description |
|--------|-----------|-------------|
| `getProductionRecords` | `(days?: number) => Promise<ProductionRecord[]>` | Recent production records |
| `getProductionTrend` | `(days?: number) => Promise<ProductionTrendPoint[]>` | Daily output vs. target |
| `getTotalOutputKg` | `(days?: number) => Promise<number>` | Sum of output_weight_kg |
| `getProductionBatches` | `(limit?: number) => Promise<ProductionBatch[]>` | Recent production batches |
| `getProductionShifts` | `(days?: number) => Promise<ProductionShift[]>` | Shift-level summaries |
| `createProductionRecord` | `(payload) => Promise<ProductionRecord>` | Insert a production record |

---

## Energy Service

File: `src/services/energyService.ts`

| Method | Signature | Description |
|--------|-----------|-------------|
| `getEnergyMeters` | `() => Promise<EnergyMeter[]>` | All active energy meters |
| `getEnergyTrend` | `(days?: number) => Promise<EnergyTrendPoint[]>` | Daily consumption by type |
| `getTotalEnergyKwh` | `(days?: number) => Promise<number>` | Total electricity in kWh |
| `getEnergySources` | `() => Promise<EnergySource[]>` | Energy source registry |
| `getEnergyAnomalies` | `(days?: number, limit?: number) => Promise<EnergyAnomaly[]>` | Recent energy anomalies |
| `insertEnergyReading` | `(payload) => Promise<void>` | Insert an energy reading |

---

## Equipment Service

File: `src/services/equipmentService.ts`

| Method | Signature | Description |
|--------|-----------|-------------|
| `getEquipment` | `() => Promise<Equipment[]>` | All equipment with health scores |
| `getEquipmentHealth` | `() => Promise<{ avgHealth, operational, total }>` | Aggregated health metrics |
| `getEquipmentTelemetry` | `(equipmentId: string, hours?: number) => Promise<EquipmentTelemetry[]>` | Recent telemetry |
| `getEquipmentEvents` | `(equipmentId?: string, days?: number) => Promise<EquipmentEvent[]>` | Equipment event log |
| `getEquipmentOperatingHours` | `(equipmentId?: string, days?: number) => Promise<EquipmentOperatingHours[]>` | Operating hours records |
| `getEquipmentComponents` | `(equipmentId: string) => Promise<EquipmentComponent[]>` | Equipment components |
| `insertEquipmentTelemetry` | `(payload) => Promise<void>` | Insert telemetry reading |

---

## Maintenance Service

File: `src/services/maintenanceService.ts`

| Method | Signature | Description |
|--------|-----------|-------------|
| `getWorkOrders` | `(limit?: number) => Promise<MaintenanceWorkOrder[]>` | Recent work orders |
| `getCriticalMaintenanceCount` | `() => Promise<number>` | Open critical/high work orders |
| `createWorkOrder` | `(payload) => Promise<MaintenanceWorkOrder>` | Create a new work order |
| `updateWorkOrderStatus` | `(id, status, completedDate?) => Promise<void>` | Update work order status |
| `getMaintenanceSchedules` | `(limit?: number) => Promise<MaintenanceSchedule[]>` | Upcoming maintenance schedules |
| `getEquipmentDowntime` | `(equipmentId?: string, days?: number) => Promise<EquipmentDowntime[]>` | Downtime records |

---

## Maintenance Analytics Service

File: `src/services/maintenanceAnalyticsService.ts`

| Method | Signature | Description |
|--------|-----------|-------------|
| `getEquipmentMtbf` | `(equipmentId?: string, days?: number) => Promise<MtbfResult[]>` | Mean Time Between Failures |
| `getEquipmentMttr` | `(equipmentId?: string, days?: number) => Promise<MttrResult[]>` | Mean Time To Repair |
| `getMaintenanceProcedures` | `() => Promise<MaintenanceProcedure[]>` | Active maintenance procedures |
| `getMaintenanceParts` | `(workOrderId: string) => Promise<MaintenancePart[]>` | Parts used in a work order |

---

## Quality Service

File: `src/services/qualityService.ts`

| Method | Signature | Description |
|--------|-----------|-------------|
| `getQualityStandards` | `() => Promise<QualityStandard[]>` | Active quality standards |
| `getQualityInspections` | `(limit?: number) => Promise<QualityInspection[]>` | Recent inspections |
| `getQualityMeasurements` | `(inspectionId: string) => Promise<QualityMeasurement[]>` | Measurements for an inspection |
| `getQualityStats` | `() => Promise<{ total, passed, failed, conditional, passRate }>` | Aggregated quality stats |
| `getQualityBatches` | `(limit?: number) => Promise<QualityBatch[]>` | Batch quality status |
| `getLaboratoryResults` | `(batchId?: string, limit?: number) => Promise<LaboratoryResult[]>` | Lab test results |
| `getQualityParameters` | `() => Promise<QualityParameter[]>` | Configurable parameters |
| `createQualityInspection` | `(payload) => Promise<QualityInspection>` | Create an inspection |

---

## Safety Service

File: `src/services/safetyService.ts`

| Method | Signature | Description |
|--------|-----------|-------------|
| `getSafetyIncidents` | `(limit?: number) => Promise<SafetyIncident[]>` | Recent safety incidents |
| `getOpenIncidentCount` | `() => Promise<number>` | Open + investigating count |
| `getSafetyInspections` | `(limit?: number) => Promise<SafetyInspection[]>` | Safety inspections |
| `getRiskAssessments` | `(limit?: number) => Promise<RiskAssessment[]>` | Risk assessment records |
| `getSafetyTrainingRecords` | `(limit?: number) => Promise<SafetyTrainingRecord[]>` | Training records |
| `createSafetyIncident` | `(payload) => Promise<SafetyIncident>` | Report a new incident |

---

## Warehouse Service

File: `src/services/warehouseService.ts`

| Method | Signature | Description |
|--------|-----------|-------------|
| `getWarehouseItems` | `() => Promise<WarehouseItem[]>` | All warehouse items |
| `getLowStockCount` | `() => Promise<number>` | Items below minimum stock |
| `getStockTransactions` | `(days?: number, limit?: number) => Promise<StockTransaction[]>` | Stock transaction ledger |
| `recordStockMovement` | `(payload) => Promise<{ success, new_stock, message }>` | Atomic stock movement via RPC |

---

## Environment Service

File: `src/services/environmentService.ts`

| Method | Signature | Description |
|--------|-----------|-------------|
| `getEnvironmentalReadings` | `(days?: number) => Promise<EnvironmentalReading[]>` | Recent environmental readings |
| `getEmissionRecords` | `(days?: number) => Promise<EmissionRecord[]>` | Emission records |
| `getWasteRecords` | `(days?: number) => Promise<WasteRecord[]>` | Waste disposal records |
| `getTotalCo2Emissions` | `(days?: number) => Promise<number>` | Sum of CO2 emissions in kg |
| `getEnvironmentalAlerts` | `(limit?: number) => Promise<EnvironmentalAlert[]>` | Environmental threshold alerts |

---

## Workforce Service

File: `src/services/workforceService.ts`

| Method | Signature | Description |
|--------|-----------|-------------|
| `getEmployees` | `() => Promise<Employee[]>` | All employees |
| `getAttendanceRecords` | `(days?: number) => Promise<AttendanceRecord[]>` | Recent attendance |
| `getQualifications` | `(employeeId?: string) => Promise<Qualification[]>` | Employee qualifications |
| `getTrainingRecords` | `(employeeId?: string) => Promise<TrainingRecord[]>` | Training records |

---

## Notification Service

File: `src/services/notificationService.ts`

| Method | Signature | Description |
|--------|-----------|-------------|
| `getNotifications` | `() => Promise<Notification[]>` | Current user's notifications |
| `markNotificationRead` | `(id: string) => Promise<void>` | Mark notification as read |

### Realtime Subscription

```typescript
const channel = supabase
  .channel('notifications')
  .on('postgres_changes',
    { event: 'INSERT', schema: 'public', table: 'notifications', filter: `user_id=eq.${userId}` },
    (payload) => console.log('New notification:', payload.new)
  )
  .subscribe();
```

---

## Overview Service

File: `src/services/overviewService.ts`

| Method | Signature | Description |
|--------|-----------|-------------|
| `getKpiSummary` | `(days?: number) => Promise<KpiSummary>` | Aggregated KPIs from all domains |

Runs 7 parallel queries and computes energy intensity, equipment availability, and production efficiency.

---

## Admin Service

File: `src/services/adminService.ts`

| Method | Signature | Description |
|--------|-----------|-------------|
| `getAllProfiles` | `() => Promise<Profile[]>` | All user profiles (admin only) |
| `updateProfileRole` | `(userId: string, role: UserRole) => Promise<void>` | Change user role (admin only, prevents self-change) |
| `setUserActive` | `(userId: string, isActive: boolean) => Promise<void>` | Activate/deactivate user |
| `assignDepartment` | `(userId: string, departmentId: string \| null) => Promise<void>` | Assign department |
| `getAuditLogs` | `(limit?: number) => Promise<AuditLog[]>` | Recent audit log entries |
| `getSystemEvents` | `(limit?: number) => Promise<SystemEvent[]>` | Recent system events |

All admin methods verify the caller's role before proceeding. Role changes and user activation/deactivation also write audit log entries via the `log_audit_event` RPC.

---

## Analytics Service

File: `src/services/analyticsService.ts`

| Method | Signature | Description |
|--------|-----------|-------------|
| `getMaintenanceCompletionRate` | `(days?: number) => Promise<MaintenanceCompletionRate>` | Completion rate via RPC |
| `getProductionEfficiency` | `(days?: number) => Promise<number>` | Output vs target percentage |
| `getRejectionRate` | `(days?: number) => Promise<number>` | Rejected / total output percentage |
| `getEnergyIntensity` | `(days?: number) => Promise<number>` | kWh per tonne of steel |
| `getEquipmentDowntimeByEquipment` | `(equipmentId?: string, days?: number) => Promise<DowntimeSummary[]>` | Downtime grouped by equipment |
| `getStockMovementSummary` | `(days?: number) => Promise<StockMovementSummary>` | Incoming/outgoing/adjustment totals |

---

## Edge Functions

All edge functions require a valid JWT (Authorization header).

### Calling Pattern

```typescript
const apiUrl = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/<function-name>`;
const response = await fetch(apiUrl, {
  method: 'POST',
  headers: {
    Authorization: `Bearer ${session.access_token}`,
    'Content-Type': 'application/json',
    apikey: import.meta.env.VITE_SUPABASE_ANON_KEY,
  },
  body: JSON.stringify({ /* params */ }),
});
if (!response.ok) throw new Error(`Request failed (${response.status})`);
const data = await response.json();
```

### Available Functions

| Function | Endpoint | Input | Description |
|----------|----------|-------|-------------|
| AI Analyst | `ai-analyst` | `{ question?, domain? }` | Natural language Q&A with statistical fallback |
| Energy Analysis | `energy-analysis` | `{ days? }` | Energy intensity, CO2 estimates, anomaly detection |
| Production Insights | `production-insights` | `{ days? }` | Shift performance, target achievement, rejection analysis |
| Equipment Anomaly | `equipment-anomaly-analysis` | `{ equipment_id, hours? }` | Z-score anomaly detection, risk assessment |
| Operational Report | `generate-operational-report` | `{ days? }` | Full operational report with optional AI narrative |
| IoT Ingestion | `iot-ingestion` | `{ type, device_id, timestamp, readings }` | Industrial telemetry & energy ingestion |

See [EDGE_FUNCTIONS.md](EDGE_FUNCTIONS.md) for detailed edge function documentation.
