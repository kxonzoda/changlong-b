# Edge Functions

CHANGLONG INTELLIGENCE deploys 6 Supabase Edge Functions (Deno runtime) for AI-powered analytics, anomaly detection, report generation, and industrial IoT data ingestion. All functions require JWT authentication and implement mandatory CORS headers.

## Overview

| Function | Path | JWT | Purpose |
|----------|------|-----|---------|
| `ai-analyst` | `/functions/v1/ai-analyst` | Required | Natural language Q&A with statistical fallback |
| `energy-analysis` | `/functions/v1/energy-analysis` | Required | Energy intensity, CO2 estimates, anomaly detection |
| `production-insights` | `/functions/v1/production-insights` | Required | Shift performance, target achievement, rejection analysis |
| `equipment-anomaly-analysis` | `/functions/v1/equipment-anomaly-analysis` | Required | Z-score anomaly detection and risk assessment |
| `generate-operational-report` | `/functions/v1/generate-operational-report` | Required | Comprehensive operational report with optional AI narrative |
| `iot-ingestion` | `/functions/v1/iot-ingestion` | Required | Industrial IoT telemetry & energy reading ingestion |

## Common Architecture

All edge functions share the same structure:

1. **CORS handling** — every response (preflight, success, error) includes the mandatory header set.
2. **JWT validation** — extracts the Bearer token and validates via `supabase.auth.getUser(token)`.
3. **Service role client** — uses `SUPABASE_SERVICE_ROLE_KEY` to bypass RLS for read access across all tables.
4. **Try/catch wrapper** — all logic is wrapped; errors return JSON `{ error: string }` with appropriate HTTP status.
5. **AI provider abstraction** — functions that generate text accept `AI_PROVIDER` and `AI_API_KEY` env vars. When absent, they fall back to rule-based statistical summaries.

### CORS Headers (mandatory on every response)

```typescript
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};
if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: corsHeaders });
```

### Authentication Pattern

```typescript
const authHeader = req.headers.get("Authorization");
if (!authHeader) return errorResponse(401, "Not authenticated");
const token = authHeader.replace("Bearer ", "");
const { data: userData, error: userError } = await supabase.auth.getUser(token);
if (userError || !userData.user) return errorResponse(401, "Invalid session");
```

---

## 1. AI Analyst

**Endpoint:** `POST /functions/v1/ai-analyst`

**Input:**
```json
{
  "question": "What is our current production efficiency?",
  "domain": "production"  // optional: production, energy, equipment, maintenance, safety, quality
}
```

**Behavior:**
- Gathers data from production, energy, equipment, maintenance, safety, and quality tables.
- If `AI_PROVIDER=openai` and `AI_API_KEY` is set, sends the data and question to GPT-4o-mini for a natural language answer.
- If no AI provider is configured, generates a rule-based statistical summary covering all domains.
- Returns a structured response with the answer, key metrics, and source attribution.

**Response:**
```json
{
  "answer": "Production efficiency is at 92.3%...",
  "metrics": { "productionEfficiency": 92.3, "totalOutputKg": 450000 },
  "source": "openai-llm" | "rule-based",
  "isDemoData": true
}
```

---

## 2. Energy Analysis

**Endpoint:** `POST /functions/v1/energy-analysis`

**Input:**
```json
{ "days": 30 }
```

**Behavior:**
- Queries `energy_consumption_daily` joined with `energy_meters` and `production_records`.
- Calculates **energy intensity** (kWh per tonne of output).
- Estimates **CO2 emissions** using IPCC reference emission factors:
  - Electricity: 0.5 kg CO2/kWh (grid average)
  - Natural gas: 2.02 kg CO2/m³
  - Steam: 0.21 kg CO2/kg
- Detects **peak consumption days** (values > 1.5× mean) and **anomalies** (z-score > 2).
- Returns structured analysis with per-energy-type breakdown.

**Response:**
```json
{
  "summary": {
    "totalElectricityKwh": 45000,
    "totalGasM3": 1200,
    "totalWaterM3": 800,
    "energyIntensity": 45.5,
    "energyIntensityUnit": "kWh per tonne",
    "estimatedCo2Kg": 22500
  },
  "byType": [...],
  "peakDays": [...],
  "anomalies": [...],
  "isDemoData": true
}
```

---

## 3. Production Insights

**Endpoint:** `POST /functions/v1/production-insights`

**Input:**
```json
{ "days": 30 }
```

**Behavior:**
- Queries `production_records` joined with `shifts` and `production_lines`.
- Calculates **shift performance** — output by shift (morning, afternoon, night).
- Calculates **target achievement** — actual output vs. target weight, with percentage.
- Performs **rejection analysis** — total rejected weight, rejection rate, trend over time.
- Returns structured insights with recommendations.

**Response:**
```json
{
  "summary": {
    "totalOutputKg": 450000,
    "totalTargetKg": 480000,
    "targetAchievementPct": 93.75,
    "totalRejectedKg": 4500,
    "rejectionRatePct": 1.0
  },
  "shiftPerformance": [...],
  "dailyTrend": [...],
  "recommendations": [...],
  "isDemoData": true
}
```

---

## 4. Equipment Anomaly Analysis

**Endpoint:** `POST /functions/v1/equipment-anomaly-analysis`

**Input:**
```json
{
  "equipment_id": "uuid-of-equipment",
  "hours": 24
}
```

**Behavior:**
- Queries `equipment_telemetry` for the specified equipment over the time window.
- Groups readings by metric (temperature, vibration, pressure, etc.).
- For each metric, computes mean, stddev, min, max, and last value.
- **Anomaly detection** using z-score:
  - `|z| > 2` → warning
  - `|z| > 3` → critical
  - Recent 20% of readings trending away from mean → trend anomaly
- Computes a **risk score** (0–100) based on health score + anomaly count.
- Returns risk level (low/medium/high) and actionable recommendations.

**Response:**
```json
{
  "equipment": { "code": "EQP-001", "name": "Blast Furnace #1", "status": "operational", "healthScore": 85 },
  "analysis": {
    "hoursAnalyzed": 24,
    "totalReadings": 336,
    "metrics": [{ "metric": "temperature", "count": 84, "mean": 1450, "min": 1430, "max": 1470, "stddev": 8.5, "lastValue": 1455 }],
    "anomalies": [{ "metric": "vibration", "value": 7.2, "mean": 4.5, "stddev": 0.8, "zScore": 3.38, "severity": "critical" }],
    "anomalyCount": 1
  },
  "riskAssessment": {
    "score": 65,
    "level": "medium",
    "recommendations": ["1 critical anomaly detected. Immediate investigation recommended."]
  },
  "isDemoData": true
}
```

---

## 5. Generate Operational Report

**Endpoint:** `POST /functions/v1/generate-operational-report`

**Input:**
```json
{ "days": 30 }
```

**Behavior:**
- Runs 7 parallel queries across production, energy, equipment, maintenance, safety, quality, and environmental tables.
- Aggregates KPIs from every domain into a structured report.
- If `AI_PROVIDER=openai` and `AI_API_KEY` is set, generates a narrative executive summary via GPT-4o-mini.
- If no AI provider configured, generates a rule-based text summary covering all domains.
- Returns the full structured report plus a narrative summary string.

**Response:**
```json
{
  "reportDate": "2026-01-15T10:00:00Z",
  "period": { "days": 30, "startDate": "2025-12-16" },
  "production": { "totalOutputKg": 450000, "targetAchievementPct": 93.75, "rejectionRatePct": 1.0 },
  "energy": { "totalElectricityKwh": 45000, "energyIntensity": 45.5 },
  "equipment": { "totalUnits": 8, "operational": 7, "availabilityPct": 87, "avgHealthScore": 85 },
  "maintenance": { "totalWorkOrders": 12, "completionRatePct": 75, "totalCost": 15000, "totalDowntimeHours": 24 },
  "safety": { "openIncidents": 2, "criticalIncidents": 0 },
  "quality": { "totalInspections": 45, "passRatePct": 95.5 },
  "environmental": { "estimatedCo2Kg": 22500 },
  "narrativeSummary": "OPERATIONAL REPORT — 30 days (demo data)...",
  "source": "rule-based" | "openai-llm",
  "isDemoData": true
}
```

---

## 6. IoT Ingestion

**Endpoint:** `POST /functions/v1/iot-ingestion`

**Input (Telemetry):**
```json
{
  "type": "telemetry",
  "device_id": "EAF-01",
  "equipment_id": "uuid-or-null",
  "timestamp": "2026-10-30T10:00:00Z",
  "readings": [
    { "metric": "temperature", "value": 1450, "unit": "celsius", "quality": "good" },
    { "metric": "vibration", "value": 4.5, "unit": "mm/s" }
  ]
}
```

**Input (Energy):**
```json
{
  "type": "energy",
  "meter_id": "uuid-of-meter",
  "timestamp": "2026-10-30T10:00:00Z",
  "value": 125.5,
  "unit": "kWh",
  "quality": "good"
}
```

**Behavior:**
- Validates authentication (Bearer token or X-API-Key header).
- For telemetry: resolves `device_id` to equipment via `equipment_code`, validates timestamp (not future-dated beyond 60s), filters readings against an allowlist of metrics (temperature, vibration, pressure, rpm, power, current, voltage, flow_rate, humidity, load), and inserts valid rows into `equipment_telemetry`.
- For energy: validates the meter exists and is active, then inserts into `energy_readings`.
- Logs a `system_events` entry on successful telemetry ingestion.
- Invalid readings are skipped (not partially inserted).

**Response:**
```json
{
  "success": true,
  "ingested": 2,
  "skipped": ["invalid_metric"]
}
```

**Metrics Allowlist:** `temperature`, `vibration`, `pressure`, `rpm`, `power`, `current`, `voltage`, `flow_rate`, `humidity`, `load`.

**Quality Values:** `good`, `suspect`, `estimated`, `invalid` (defaults to `good`).

---

## Configuration

### supabase/config.toml

```toml
[functions.ai-analyst]
verify_jwt = true
entrypoint = "./functions/ai-analyst/index.ts"

[functions.energy-analysis]
verify_jwt = true
entrypoint = "./functions/energy-analysis/index.ts"

[functions.production-insights]
verify_jwt = true
entrypoint = "./functions/production-insights/index.ts"

[functions.equipment-anomaly-analysis]
verify_jwt = true
entrypoint = "./functions/equipment-anomaly-analysis/index.ts"

[functions.generate-operational-report]
verify_jwt = true
entrypoint = "./functions/generate-operational-report/index.ts"

[functions.iot-ingestion]
verify_jwt = true
entrypoint = "./functions/iot-ingestion/index.ts"
```

### Environment Variables (Edge Function Secrets)

| Variable | Required | Description |
|----------|----------|-------------|
| `SUPABASE_URL` | Yes (auto) | Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Yes (auto) | Service role key for DB access |
| `AI_PROVIDER` | No | AI provider name (currently `openai`) |
| `AI_API_KEY` | No | API key for the AI provider |

When `AI_PROVIDER` and `AI_API_KEY` are not set, AI-capable functions degrade gracefully to rule-based statistical summaries. No errors are thrown — the `source` field in the response indicates which path was taken.

## Deployment

Edge functions are deployed via the `mcp__supabase__deploy_edge_functions` MCP tool, which auto-detects changed source files under `supabase/functions/` and deploys them in a single call. The tool reads source from disk — always write/update the `index.ts` file before calling deploy.

See [MIGRATION_AND_DEPLOYMENT.md](MIGRATION_AND_DEPLOYMENT.md) for the full deployment workflow.

## Limitations

- All responses include `isDemoData: true` while the database contains only demo seed data. In production with real data, this flag will be `false`.
- AI-generated content is based on snapshot data from the database at request time — it is not real-time and does not reflect changes that occur during the request.
- Anomaly detection is statistical (z-score based), not ML-based. It does not "learn" from historical patterns — it evaluates each request independently against the requested time window.
- CO2 emission estimates use IPCC reference factors, not measured plant-specific emission data.
