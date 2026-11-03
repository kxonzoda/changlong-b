# Project memory

## Product intent & audience

- Industrial metallurgical plant management platform for CHANGLONG INTELLIGENCE
- Full-stack: React frontend (Vite) + Supabase backend (Postgres, RLS, Edge Functions)
- Backend covers 11 industrial domains: production, energy, equipment, maintenance, safety, warehouse, quality, environment, workforce, production batch traceability, equipment telemetry
- Frontend: 9 dashboard tabs with KPI cards and Recharts visualizations
- Edge functions: AI analyst, energy analysis, production insights, equipment anomaly detection, operational report generation

## Brand personality & voice

- Professional, industrial, engineering-focused
- Technical documentation is a core deliverable — 12 markdown docs required
- Clarity and precision over marketing language

## Visual design & UX direction

- Existing React frontend must be preserved — no redesign, no framework replacement
- TypeScript + Tailwind CSS + Lucide React icons + Recharts for charts
- `@/` path alias maps to `src/` (per `.bolt/prompt`)
- No additional UI packages unless explicitly requested

## Decisions, constraints & rationale

- 10 database migrations applied across 11 domains (40+ tables)
- RLS enabled on every table; 11 roles with role-based access control
- SECURITY DEFINER functions use locked `search_path`, restricted EXECUTE
- Atomic inventory movement function prevents negative stock
- Auto-profile creation trigger on signup
- Demo data marked `is_demo = true` across all domains; 30 days of realistic simulated data
- Demo seeding repeatable, safe, never auto-runs against production
- AI provider abstraction with rule-based statistical fallback (z-score anomaly detection) when no AI key configured
- External dependency: `AI_PROVIDER` and `AI_API_KEY` edge function secrets needed for real AI responses
- Production build passes cleanly (2240 modules, ~3.94s)
- Must not bypass RLS, expose secrets, claim unverified compliance, or present demo data as real

## Open questions & assumptions

- AI provider integration requires external secrets to be set — currently running rule-based fallback
- One security advisor finding (SECURITY DEFINER callable by authenticated) is an accepted design decision for atomic inventory mutation
- Testing strategy documented but actual test execution status unclear — build verification is the primary automated check
- Environment-specific deployment (dev/staging/prod) configuration details may need further validation