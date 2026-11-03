# AI Architecture

CHANGLONG INTELLIGENCE integrates AI capabilities through Supabase Edge Functions using a provider-abstraction pattern. The system gracefully degrades from LLM-powered natural language responses to rule-based statistical summaries when no AI provider is configured.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Frontend (React)                          │
│  DashboardPage → fetch('/functions/v1/<function>')           │
└──────────────────────┬──────────────────────────────────────┘
                       │ HTTPS + JWT
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              Supabase Edge Functions (Deno)                   │
│                                                              │
│  1. Validate JWT (supabase.auth.getUser)                     │
│  2. Query database (service_role, bypasses RLS)             │
│  3. Process data (statistical analysis)                      │
│  4. If AI_PROVIDER + AI_API_KEY configured:                  │
│     → Send data + prompt to LLM (OpenAI GPT-4o-mini)         │
│     → Return LLM-generated natural language response         │
│  5. Else:                                                    │
│     → Generate rule-based statistical summary                │
│     → Return structured data + text summary                   │
│  6. Return JSON with source attribution                      │
└──────────────────────┬──────────────────────────────────────┘
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
    ┌──────────┐ ┌──────────┐ ┌───────────┐
    │ Supabase │ │  OpenAI  │ │  Rule     │
    │ Database │ │  API     │ │  Engine   │
    │ (RLS     │ │ (optional)│ │ (fallback)│
    │  bypass) │ │          │ │           │
    └──────────┘ └──────────┘ └───────────┘
```

## Design Principles

1. **Provider Abstraction** — AI calls are abstracted behind a simple interface. Currently only OpenAI is supported, but the pattern allows adding Anthropic, Azure OpenAI, or local models by extending the provider switch.

2. **Graceful Degradation** — Every AI-capable function works without an AI provider. When `AI_PROVIDER` or `AI_API_KEY` is absent, the function returns a rule-based statistical summary. The `source` field in the response tells the frontend which path was taken (`openai-llm` vs `rule-based`).

3. **Data-First, AI-Second** — All functions gather and structure the data first, then optionally enhance it with AI. This means the structured JSON response is always available regardless of AI availability. The AI only enhances the narrative summary, not the core metrics.

4. **Demo Data Transparency** — All responses include `isDemoData: true` while the database contains only demo seed data. This prevents users from mistaking demo analytics for real plant data.

## Provider Implementation

### OpenAI (Current)

```typescript
async function callOpenAI(prompt: string, systemPrompt: string, apiKey: string): Promise<string> {
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: prompt },
      ],
      max_tokens: 500,
    }),
  });
  if (!res.ok) throw new Error(`AI provider error: ${res.status}`);
  const data = await res.json();
  return data.choices?.[0]?.message?.content ?? "No summary generated.";
}
```

### Adding a New Provider

To add Anthropic Claude (example):

```typescript
async function callAnthropic(prompt: string, systemPrompt: string, apiKey: string): Promise<string> {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-3-haiku-20240307",
      max_tokens: 500,
      system: systemPrompt,
      messages: [{ role: "user", content: prompt }],
    }),
  });
  // ... parse response
}
```

Then add to the provider switch in each function:

```typescript
if (provider === "anthropic") {
  return await callAnthropic(prompt, systemPrompt, apiKey);
}
```

## Functions Using AI

| Function | AI Enhancement | Fallback |
|----------|---------------|----------|
| `ai-analyst` | Natural language Q&A from plant data | Rule-based statistical summary covering all domains |
| `energy-analysis` | (Not currently AI-enhanced) | Statistical analysis with IPCC emission factors |
| `production-insights` | (Not currently AI-enhanced) | Shift performance and target achievement statistics |
| `equipment-anomaly-analysis` | (Not currently AI-enhanced) | Z-score anomaly detection with risk scoring |
| `generate-operational-report` | Narrative executive summary | Rule-based text report covering all domains |

## Rule-Based Fallback Engine

The rule-based engine is not a stub — it produces meaningful, structured analysis:

### Statistical Methods Used

1. **Z-score anomaly detection** (equipment-anomaly-analysis) — identifies readings > 2 standard deviations from the mean as warnings, > 3 as critical.

2. **Trend detection** — compares the mean of the last 20% of readings against the overall mean. Divergence > 1 stddev flags a progressive trend.

3. **Peak detection** (energy-analysis) — values > 1.5× the mean are flagged as peak consumption events.

4. **IPCC emission factors** (energy-analysis, generate-operational-report) — CO2 estimates use reference factors:
   - Electricity: 0.5 kg CO2/kWh
   - Natural gas: 2.02 kg CO2/m³
   - Steam: 0.21 kg CO2/kg

5. **Risk scoring** (equipment-anomaly-analysis) — composite score from health score + anomaly count:
   - Health < 60 → +40 points
   - Health < 80 → +20 points
   - Critical anomaly → +25 points each
   - Warning anomaly → +10 points each
   - Capped at 100

6. **Target achievement** (production-insights) — actual output / target weight × 100, with rejection rate (rejected / output × 100).

## Security Considerations

- AI API keys are stored as Edge Function secrets, never exposed to the frontend.
- All AI requests are proxied through edge functions — the frontend never calls the AI provider directly.
- JWT validation occurs before any AI call — unauthenticated requests never reach the AI provider.
- The service_role key used for database queries is never exposed to the frontend.
- AI prompts include `isDemoData` context so the LLM knows the data is synthetic and can note this in its responses.

## Future Enhancements

1. **Streaming responses** — currently the AI generates the full response before returning. SSE/streaming would improve perceived performance for long reports.

2. **Vector embeddings** — for the AI analyst, storing historical Q&A pairs as embeddings would allow similarity search and more contextual answers.

3. **Time series forecasting** — the current anomaly detection is reactive (z-score on past data). Adding ARIMA or Prophet-based forecasting would enable predictive maintenance alerts.

4. **Multi-turn conversations** — the AI analyst currently treats each request independently. Adding conversation context would allow follow-up questions.

5. **Fine-tuned models** — for production deployment, a model fine-tuned on metallurgical industry data would produce more domain-specific insights.
