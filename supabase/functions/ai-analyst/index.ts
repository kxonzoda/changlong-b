// CHANGLONG INTELLIGENCE Edge Function
// Rate limiting should be implemented at the API gateway / Supabase project settings level.
// Supabase does not support per-function rate limiting natively.
import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

const MAX_BODY_BYTES = 100 * 1024;
const MAX_QUESTION_LENGTH = 2000;

const ALLOWED_ROLES = new Set([
  "admin", "plant_director", "manager", "production_manager",
  "energy_manager", "maintenance_manager", "engineer", "safety_officer",
]);

interface AiRequest {
  question: string;
}

function jsonResponse(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const contentLength = parseInt(req.headers.get("content-length") ?? "0", 10);
    if (contentLength > MAX_BODY_BYTES) {
      return jsonResponse({ error: "Request body too large" }, 413);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } }
    );

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Not authenticated" }, 401);
    }

    const token = authHeader.replace("Bearer ", "");
    const { data: userData, error: userError } = await supabase.auth.getUser(token);
    if (userError || !userData.user) {
      return jsonResponse({ error: "Invalid session" }, 401);
    }

    const { data: profile } = await supabase
      .from("profiles")
      .select("role, full_name")
      .eq("id", userData.user.id)
      .maybeSingle();

    if (!profile) {
      return jsonResponse({ error: "Profile not found" }, 403);
    }

    if (!ALLOWED_ROLES.has(profile.role)) {
      return jsonResponse({ error: "Insufficient permissions for this operation" }, 403);
    }

    const rawBody = await req.text();
    if (rawBody.length > MAX_BODY_BYTES) {
      return jsonResponse({ error: "Request body too large" }, 413);
    }

    let parsedBody: AiRequest;
    try {
      parsedBody = JSON.parse(rawBody) as AiRequest;
    } catch {
      return jsonResponse({ error: "Invalid JSON body" }, 400);
    }

    const { question } = parsedBody;
    if (typeof question !== "string" || question.trim().length === 0) {
      return jsonResponse({ error: "Question is required" }, 400);
    }

    if (question.length > MAX_QUESTION_LENGTH) {
      return jsonResponse({ error: `Question must be ${MAX_QUESTION_LENGTH} characters or fewer` }, 400);
    }

    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    const dateStr = sevenDaysAgo.toISOString().split("T")[0];

    const [productionRes, energyRes, equipmentRes, maintenanceRes, safetyRes] = await Promise.all([
      supabase.from("production_records")
        .select("record_date, output_weight_kg, rejected_weight_kg, target_weight_kg")
        .gte("record_date", dateStr)
        .order("record_date", { ascending: false })
        .limit(30),
      supabase.from("energy_consumption_daily")
        .select("consumption_date, total_value, meter:energy_meters(energy_type)")
        .gte("consumption_date", dateStr)
        .order("consumption_date", { ascending: false })
        .limit(30),
      supabase.from("equipment")
        .select("equipment_code, name, status, health_score, operating_hours")
        .order("health_score", { ascending: true })
        .limit(10),
      supabase.from("maintenance_work_orders")
        .select("work_order_number, type, priority, status, description")
        .in("status", ["open", "in_progress", "overdue"])
        .order("priority", { ascending: true })
        .limit(10),
      supabase.from("safety_incidents")
        .select("incident_number, title, severity, status")
        .in("status", ["reported", "investigating"])
        .limit(10),
    ]);

    const context = {
      production: productionRes.data,
      energy: energyRes.data,
      equipment: equipmentRes.data,
      maintenance: maintenanceRes.data,
      safety: safetyRes.data,
      generatedAt: new Date().toISOString(),
      userRole: profile.role,
      dataSource: "database",
    };

    const aiApiKey = Deno.env.get("AI_API_KEY");
    const aiProvider = Deno.env.get("AI_PROVIDER");

    if (!aiApiKey || !aiProvider) {
      const summary = generateStatisticalSummary(context);
      return jsonResponse({
        answer: summary,
        source: "rule-based",
        note: "AI provider not configured. Returning statistical analysis based on operational data.",
        context: { dataSource: "database", dataPoints: Object.values(context).flat().length },
      }, 200);
    }

    try {
      const aiResponse = await callAiProvider(aiProvider, aiApiKey, question, context);
      return jsonResponse({
        answer: aiResponse,
        source: `${aiProvider}-llm`,
        context: { dataSource: "database", dataPoints: Object.values(context).flat().length },
      }, 200);
    } catch {
      const summary = generateStatisticalSummary(context);
      return jsonResponse({
        answer: summary,
        source: "rule-based-fallback",
        note: "AI provider unavailable. Returning statistical analysis from database records.",
        context: { dataSource: "database", dataPoints: Object.values(context).flat().length },
      }, 200);
    }
  } catch {
    return jsonResponse({ error: "Internal error" }, 500);
  }
});

function generateStatisticalSummary(ctx: {
  production: unknown[];
  energy: unknown[];
  equipment: unknown[];
  maintenance: unknown[];
  safety: unknown[];
}): string {
  const prodData = ctx.production as Array<{ output_weight_kg: number; rejected_weight_kg: number; target_weight_kg: number | null }>;
  const totalOutput = prodData.reduce((s, r) => s + Number(r.output_weight_kg || 0), 0);
  const totalRejected = prodData.reduce((s, r) => s + Number(r.rejected_weight_kg || 0), 0);
  const rejectionRate = totalOutput > 0 ? (totalRejected / totalOutput) * 100 : 0;
  const equipmentLow = (ctx.equipment as Array<{ health_score: number }>).filter((e) => e.health_score < 70).length;
  const openWO = ctx.maintenance.length;
  const openIncidents = ctx.safety.length;

  return [
    `OPERATIONAL SUMMARY (last 7 days, database records):`,
    `- Total steel output: ${(totalOutput / 1000).toFixed(1)} tonnes`,
    `- Rejection rate: ${rejectionRate.toFixed(2)}%`,
    `- Equipment with low health (<70%): ${equipmentLow} units`,
    `- Open maintenance work orders: ${openWO}`,
    `- Open safety incidents: ${openIncidents}`,
    ``,
    `NOTE: This is rule-based statistical analysis using current database records.`,
    `Configure an AI provider to enable LLM-powered natural language responses.`
  ].join("\n");
}

async function callAiProvider(provider: string, apiKey: string, question: string, context: unknown): Promise<string> {
  const systemPrompt = `You are an industrial intelligence assistant for a steel manufacturing plant.
Analyze operational data and answer the user's question.
Always distinguish between observed data, calculated metrics, and hypotheses.
All data provided comes from the operational database unless explicitly stated otherwise.
Never fabricate sensor readings or claim predictions are verified.`;

  if (provider !== "openai" && provider !== "groq") {
    throw new Error("Unsupported AI provider");
  }

  const baseUrl = Deno.env.get("AI_BASE_URL") ?? (provider === "groq" ? "https://api.groq.com/openai/v1" : "https://api.openai.com/v1");
  const model = Deno.env.get("AI_MODEL") ?? (provider === "groq" ? "llama-3.3-70b-versatile" : "gpt-4o-mini");
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15000);
  try {
    const res = await fetch(`${baseUrl}/chat/completions`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": `Bearer ${apiKey}` },
      body: JSON.stringify({
        model,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: `Question: ${question}\n\nOperational data context:\n${JSON.stringify(context, null, 2)}` },
        ],
        max_tokens: 1000,
      }),
      signal: controller.signal,
    });
    if (!res.ok) throw new Error(`AI provider error: ${res.status}`);
    const data: unknown = await res.json();
    const content = (data as { choices?: Array<{ message?: { content?: unknown } }> }).choices?.[0]?.message?.content;
    if (typeof content !== "string" || content.trim().length === 0 || content.length > 8000) {
      throw new Error("AI provider returned an invalid response");
    }
    return content.trim();
  } finally {
    clearTimeout(timeout);
  }
}
