# Frontend Integration Guide — CHANGLONG INTELLIGENCE

## Overview

The React frontend communicates with the Supabase backend through:
1. **Supabase JS SDK** — direct queries to tables (governed by RLS).
2. **Edge Functions** — server-side operations via `fetch()` with JWT auth.
3. **Realtime** — subscription to notification changes (future).

## Supabase Client

```typescript
// src/lib/supabase.ts
import { createClient } from '@supabase/supabase-js';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: { persistSession: true, autoRefreshToken: true },
});
```

## Authentication

### Sign In
```typescript
import { signIn } from '@/services/authService';
await signIn('user@changlong.com', 'password');
```

### Sign Up
```typescript
import { signUp } from '@/services/authService';
await signUp('user@changlong.com', 'password', 'Zhang Wei');
```

### Sign Out
```typescript
import { signOut } from '@/services/authService';
await signOut();
```

### Get Current Profile
```typescript
import { getCurrentProfile } from '@/services/authService';
const profile = await getCurrentProfile();
// profile.role → 'admin' | 'plant_director' | ... | 'viewer'
```

### Auth State (React Hook)
```typescript
import { useAuth } from '@/context/useAuth';
const { session, profile, loading } = useAuth();
```

## Service Layer

All services are in `src/services/` and return typed data. Each handles errors via `ServiceError`.

### Organization
```typescript
import { getDepartments, getShifts, getProductionLines } from '@/services/organizationService';
const departments = await getDepartments();
const shifts = await getShifts();
const lines = await getProductionLines();
```

### Production
```typescript
import { getProductionRecords, getProductionTrend, getTotalOutputKg } from '@/services/productionService';
const records = await getProductionRecords(30);  // last 30 days
const trend = await getProductionTrend(30);       // aggregated daily
const totalKg = await getTotalOutputKg(30);
```

### Energy
```typescript
import { getEnergyMeters, getEnergyTrend, getTotalEnergyKwh } from '@/services/energyService';
const meters = await getEnergyMeters();
const trend = await getEnergyTrend(30);  // { date, electricity, gas, water }
const totalKwh = await getTotalEnergyKwh(30);
```

### Equipment
```typescript
import { getEquipment, getEquipmentHealth, getEquipmentTelemetry } from '@/services/equipmentService';
const allEquipment = await getEquipment();
const { avgHealth, operational, total } = await getEquipmentHealth();
const telemetry = await getEquipmentTelemetry(equipmentId, 24);  // last 24h
```

### Maintenance
```typescript
import { getWorkOrders, getCriticalMaintenanceCount } from '@/services/maintenanceService';
const workOrders = await getWorkOrders(50);
const criticalCount = await getCriticalMaintenanceCount();
```

### Safety
```typescript
import { getSafetyIncidents, getOpenIncidentCount } from '@/services/safetyService';
const incidents = await getSafetyIncidents(50);
const openCount = await getOpenIncidentCount();
```

### Warehouse
```typescript
import { getWarehouseItems, getLowStockCount } from '@/services/warehouseService';
const items = await getWarehouseItems();
const lowStock = await getLowStockCount();
```

### Overview (KPIs)
```typescript
import { getKpiSummary } from '@/services/overviewService';
const kpi = await getKpiSummary(30);
// { totalOutputKg, energyConsumptionKwh, energyIntensity, equipmentAvailability,
//   openSafetyIncidents, criticalMaintenance, lowStockItems }
```

### Notifications
```typescript
import { getNotifications, markNotificationRead } from '@/services/notificationService';
const notifications = await getNotifications();
await markNotificationRead(notificationId);
```

## Edge Functions

All edge functions require a valid JWT (Authorization: Bearer <token>).

### ai-analyst
```typescript
const res = await fetch(`${SUPABASE_URL}/functions/v1/ai-analyst`, {
  method: 'POST',
  headers: {
    Authorization: `Bearer ${session.access_token}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({ question: 'What is the current production efficiency?' }),
});
const { answer, source, note } = await res.json();
```
Response: `{ answer: string, source: 'rule-based' | 'openai-llm', note?: string, context: { isDemoData: boolean } }`

### energy-analysis
```typescript
const res = await fetch(`${SUPABASE_URL}/functions/v1/energy-analysis`, {
  method: 'POST',
  headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({ days: 30 }),
});
const data = await res.json();
// { totals: { electricity_kwh, natural_gas_m3, water_m3 },
//   energyIntensity, estimatedCo2: { total_kg, note, factors },
//   peak: { electricity_kwh, average_kwh, deviation_pct },
//   anomalies: { highConsumptionDays, threshold } }
```

### production-insights
```typescript
const res = await fetch(`${SUPABASE_URL}/functions/v1/production-insights`, {
  method: 'POST',
  headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({ days: 30 }),
});
const data = await res.json();
// { totals: { total_output_kg, target_achievement_pct, rejection_rate_pct },
//   dailyTrend: [...], shiftPerformance: [...], highlights: { bestDay, worstDay } }
```

## Realtime (Future)

```typescript
// Subscribe to notification changes
supabase
  .channel('notifications')
  .on('postgres_changes',
    { event: 'INSERT', schema: 'public', table: 'notifications', filter: `user_id=eq.${userId}` },
    (payload) => { /* handle new notification */ }
  )
  .subscribe();
```

## Required Permissions

| Operation | Required Role |
|-----------|--------------|
| View dashboard data | Any authenticated user |
| View safety incidents | admin, plant_director, manager, safety_officer |
| View employee records | admin, plant_director, manager |
| View audit logs | admin, plant_director |
| Record inventory movement | Any authenticated user (via RPC) |
| Call edge functions | Any authenticated user (JWT required) |
| Manage departments/equipment | service_role (edge function or admin tool) |
