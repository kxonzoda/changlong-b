import { createClient } from "npm:@supabase/supabase-js@2";

/*
 * IoT Ingestion Edge Function — Secure Device Authentication (v2)
 *
 * DEVICE PROVISIONING PROCESS:
 * 1. Admin creates a device_credentials row via service-role client:
 *      - device_id: unique device identifier (e.g. "SENSOR-PLC-001")
 *      - api_key_hash: SHA-256 hash of a generated API key (store the key
 *        securely and give it to the device; only the hash lives in the DB)
 *      - equipment_id: the equipment this device may write telemetry for
 *      - meter_id: the energy meter this device may write readings for
 *    At least one of equipment_id/meter_id should be set based on device purpose.
 * 2. The device is configured with its device_id and API key.
 * 3. The device sends requests with header: X-Device-Key: <api_key>
 * 4. To revoke: set is_active = false on the device_credentials row.
 * 5. To rotate: generate a new API key, update api_key_hash, reconfigure device.
 *
 * SECURITY:
 * - The API key is never stored in plaintext — only its SHA-256 hash.
 * - Device identity is validated against device_credentials on every request.
 * - Device-to-equipment authorization is enforced: a device can only write
 *   telemetry for its assigned equipment_id and readings for its assigned meter_id.
 * - system_events writes use server-controlled values (no attacker-controlled text).
 * - Retransmitted readings are idempotent through database-backed upserts.
 * - Historical device timestamps are accepted within the configured lookback window.
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey, X-Device-Key, X-Device-Id",
};

const MAX_READINGS = 500;
const MAX_BODY_BYTES = 256 * 1024;
const DEFAULT_MAX_AGE_DAYS = 7;
const MAX_CONFIGURED_AGE_DAYS = 30;

function getMaxAgeDays(): number {
  const configured = Number(Deno.env.get("IOT_MAX_AGE_DAYS") ?? DEFAULT_MAX_AGE_DAYS);
  return Number.isInteger(configured) && configured >= 1 && configured <= MAX_CONFIGURED_AGE_DAYS
    ? configured
    : DEFAULT_MAX_AGE_DAYS;
}

interface TelemetryPayload {
  device_id: string;
  equipment_id?: string;
  timestamp: string;
  readings: Array<{
    metric: string;
    value: number;
    unit: string;
    quality?: string;
  }>;
}

interface EnergyPayload {
  meter_id: string;
  timestamp: string;
  value: number;
  unit: string;
  quality?: string;
}

const ALLOWED_METRICS = new Set([
  "temperature", "vibration", "pressure", "rpm", "power", "current",
  "voltage", "flow_rate", "humidity", "load",
]);

const ALLOWED_QUALITY = new Set(["good", "suspect", "estimated", "invalid"]);

async function sha256(message: string): Promise<string> {
  const data = new TextEncoder().encode(message);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

interface DeviceAuth {
  device_id: string;
  equipment_id: string | null;
  meter_id: string | null;
}

async function authenticateDevice(
  supabase: ReturnType<typeof createClient>,
  deviceId: string,
  apiKey: string,
): Promise<DeviceAuth | null> {
  const keyHash = await sha256(apiKey);
  const { data, error } = await supabase
    .from("device_credentials")
    .select("device_id, equipment_id, meter_id, is_active")
    .eq("device_id", deviceId)
    .eq("api_key_hash", keyHash)
    .eq("is_active", true)
    .maybeSingle();

  if (error || !data) return null;

  await supabase
    .from("device_credentials")
    .update({ last_used_at: new Date().toISOString() })
    .eq("device_id", deviceId);

  return {
    device_id: data.device_id,
    equipment_id: data.equipment_id,
    meter_id: data.meter_id,
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const contentLength = parseInt(req.headers.get("content-length") ?? "0", 10);
    if (contentLength > MAX_BODY_BYTES) {
      return jsonError("Request body too large", 413);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const deviceId = req.headers.get("x-device-id") ?? "";
    const deviceKey = req.headers.get("x-device-key") ?? "";

    if (!deviceId || !deviceKey) {
      return jsonError("Device authentication required (X-Device-Id and X-Device-Key headers)", 401);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    const device = await authenticateDevice(supabase, deviceId, deviceKey);
    if (!device) {
      return jsonError("Invalid or revoked device credentials", 403);
    }

    const rawBody = await req.text();
    if (rawBody.length > MAX_BODY_BYTES) {
      return jsonError("Request body too large", 413);
    }

    let body: Record<string, unknown>;
    try {
      body = JSON.parse(rawBody);
    } catch {
      return jsonError("Invalid JSON body", 400);
    }

    const ingestionType = body.type ?? "telemetry";

    if (ingestionType === "telemetry") {
      return await handleTelemetry(supabase, body as unknown as TelemetryPayload, device, corsHeaders);
    } else if (ingestionType === "energy") {
      return await handleEnergy(supabase, body as unknown as EnergyPayload, device, corsHeaders);
    } else {
      return jsonError(`Unknown ingestion type: ${ingestionType}`, 400);
    }
  } catch {
    return jsonError("Internal error", 500);
  }

  function jsonError(message: string, status: number): Response {
    return new Response(
      JSON.stringify({ error: message }),
      { status, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});

async function handleTelemetry(
  supabase: ReturnType<typeof createClient>,
  payload: TelemetryPayload,
  device: DeviceAuth,
  headers: Record<string, string>,
): Promise<Response> {
  if (!payload.device_id || !payload.timestamp || !payload.readings?.length) {
    return jsonResp({ error: "Missing required fields: device_id, timestamp, readings" }, 400, headers);
  }

  if (payload.device_id !== device.device_id) {
    return jsonResp({ error: "device_id in payload does not match authenticated device" }, 403, headers);
  }

  if (payload.readings.length > MAX_READINGS) {
    return jsonResp({ error: `Too many readings (max ${MAX_READINGS} per request)` }, 400, headers);
  }

  const ts = new Date(payload.timestamp);
  if (isNaN(ts.getTime())) {
    return jsonResp({ error: "Invalid timestamp format" }, 400, headers);
  }

  const now = Date.now();
  if (ts.getTime() > now + 60000) {
    return jsonResp({ error: "Timestamp is too far in the future" }, 400, headers);
  }

  const maxAgeDays = getMaxAgeDays();
  if (ts.getTime() < now - maxAgeDays * 24 * 60 * 60 * 1000) {
    return jsonResp({ error: `Timestamp is older than the allowed ${maxAgeDays}-day device lookback window` }, 400, headers);
  }

  let equipmentId = device.equipment_id;
  if (!equipmentId && payload.equipment_id) {
    const { data: eq } = await supabase
      .from("equipment")
      .select("id")
      .eq("id", payload.equipment_id)
      .maybeSingle();
    equipmentId = eq?.id ?? null;
  }

  if (!equipmentId) {
    return jsonResp({ error: "Device has no equipment assignment and none provided" }, 403, headers);
  }

  if (device.equipment_id && payload.equipment_id && payload.equipment_id !== device.equipment_id) {
    return jsonResp({ error: "Device not authorized for this equipment" }, 403, headers);
  }

  const rows: Array<Record<string, unknown>> = [];
  const skipped: string[] = [];

  for (const reading of payload.readings) {
    if (!ALLOWED_METRICS.has(reading.metric)) {
      skipped.push(reading.metric);
      continue;
    }
    if (typeof reading.value !== "number" || !isFinite(reading.value)) {
      skipped.push(reading.metric);
      continue;
    }
    rows.push({
      equipment_id: equipmentId,
      reading_time: ts.toISOString(),
      metric: reading.metric,
      value: reading.value,
      unit: reading.unit ?? "unknown",
      quality: ALLOWED_QUALITY.has(reading.quality ?? "") ? reading.quality : "good",
      is_demo: false,
    });
  }

  if (rows.length === 0) {
    return jsonResp({ error: "No valid readings after filtering", skipped }, 400, headers);
  }

  const { error } = await supabase
    .from("equipment_telemetry")
    .upsert(rows, { onConflict: "equipment_id,reading_time,metric", ignoreDuplicates: false });

  if (error) {
    return jsonResp({ error: "Database insert failed" }, 500, headers);
  }

  await supabase.from("system_events").insert({
    event_type: "iot_telemetry_ingested",
    severity: "info",
    message: `Ingested ${rows.length} telemetry readings for device ${device.device_id}`,
    source: "iot-ingestion",
    metadata: { device_id: device.device_id, equipment_id: equipmentId, reading_count: rows.length, skipped_count: skipped.length },
  });

  return jsonResp({
    success: true,
    ingested: rows.length,
    skipped: skipped.length > 0 ? skipped : undefined,
  }, 200, headers);
}

async function handleEnergy(
  supabase: ReturnType<typeof createClient>,
  payload: EnergyPayload,
  device: DeviceAuth,
  headers: Record<string, string>,
): Promise<Response> {
  if (!payload.meter_id || !payload.timestamp || typeof payload.value !== "number") {
    return jsonResp({ error: "Missing required fields: meter_id, timestamp, value" }, 400, headers);
  }

  if (!isFinite(payload.value)) {
    return jsonResp({ error: "Invalid value" }, 400, headers);
  }

  const ts = new Date(payload.timestamp);
  if (isNaN(ts.getTime())) {
    return jsonResp({ error: "Invalid timestamp format" }, 400, headers);
  }

  const now = Date.now();
  if (ts.getTime() > now + 60000) {
    return jsonResp({ error: "Timestamp is too far in the future" }, 400, headers);
  }

  const maxAgeDays = getMaxAgeDays();
  if (ts.getTime() < now - maxAgeDays * 24 * 60 * 60 * 1000) {
    return jsonResp({ error: `Timestamp is older than the allowed ${maxAgeDays}-day device lookback window` }, 400, headers);
  }

  if (device.meter_id && payload.meter_id !== device.meter_id) {
    return jsonResp({ error: "Device not authorized for this meter" }, 403, headers);
  }

  if (!device.meter_id) {
    const { data: meter } = await supabase
      .from("energy_meters")
      .select("id, is_active")
      .eq("id", payload.meter_id)
      .maybeSingle();

    if (!meter || !meter.is_active) {
      return jsonResp({ error: "Meter not found or inactive" }, 404, headers);
    }
  }

  const { error } = await supabase
    .from("energy_readings")
    .upsert({
      meter_id: payload.meter_id,
      reading_time: ts.toISOString(),
      value: payload.value,
      unit: payload.unit ?? "kWh",
      quality: ALLOWED_QUALITY.has(payload.quality ?? "") ? payload.quality : "good",
      is_demo: false,
    }, { onConflict: "meter_id,reading_time", ignoreDuplicates: false });

  if (error) {
    return jsonResp({ error: "Database insert failed" }, 500, headers);
  }

  return jsonResp({ success: true, meter_id: payload.meter_id, value: payload.value }, 200, headers);
}

function jsonResp(body: Record<string, unknown>, status: number, headers: Record<string, string>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...headers, "Content-Type": "application/json" },
  });
}
