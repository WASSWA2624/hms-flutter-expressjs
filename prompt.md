# Backend AI utilities platform (Ollama first)

## Context

Build a **provider-agnostic AI utilities layer** on the backend. The frontend must never talk to a model host. Every AI use goes through authenticated HMS APIs. All provider, model, URL, timeout, and enablement settings come from environment variables via `backend/src/config/env.js`.

Speech-to-text and AI are sequential, not mixed:

1. **STT (required):** the platform speech engine converts microphone audio to raw text. This already exists (`AppSpeechToTextButton` / `AppSpeechRecognizer`). STT must keep working if AI is disabled, offline, or down.
2. **Insert:** show that STT text in the field immediately (local `transcriptTransform` for partials and as the baseline).
3. **AI format (optional):** if the backend AI provider is available, send the **text** (never audio) to `speech_format` so the model rewrites it into the field’s expected format. If AI is not available, keep the STT text.

Shared fields already insert live transcripts through `AppSpeechToTextButton` and local transforms in `frontend/lib/shared/components/app_speech_to_text.dart` (`text`, `email`, `digits`, `decimal`, plus date-part parsing). The AI pass runs on **final** STT utterances only. Do not send audio buffers, files, or recordings to the AI API.

Local Ollama is already running with `llama3.2:3b` at `http://127.0.0.1:11434`. That is the **first provider**, not the architecture. The same task registry and HTTP contract must accept a later provider or a larger model by changing env vars (and adding one provider adapter), without changing frontend callers or task routes.

This is **speech-to-text** (dictation into inputs), not text-to-speech. Do not add a Prisma table or a paid subscription module for v1.

**STT** means on-device/platform speech recognition that turns audio into text. **AI format** means an optional backend model call that rewrites that text. **Task** means a named, versioned backend capability (`speech_format` now; later examples: summarization, coding assist, structured extraction). **Provider** means the model runtime (`ollama` now; later another HTTP-compatible runtime). **Completion** means one non-streaming generate/chat call that returns text. **Available** means `AI_ENABLED=true`, the app is online, and `GET /api/v1/ai/status` reports `ready: true` (or the format request succeeds without `degraded`).

## Requirements

1. Add AI runtime config in `backend/src/config/env.js` only. Required names:
   - `AI_ENABLED` (default `true`)
   - `AI_PROVIDER` (default `ollama`; allowlist `ollama` in v1; reject unknown values at startup)
   - `AI_BASE_URL` (default `http://127.0.0.1:11434`)
   - `AI_MODEL` (default `llama3.2:3b`)
   - `AI_TIMEOUT_MS` (default `8000`; integer ≥ 1000)
   - `AI_MAX_INPUT_CHARS` (default `4000`; integer ≥ 1)
   - `AI_TEMPERATURE` (default `0`; number 0–2)
   Do not read `process.env` outside `env.js`. Do not hardcode host, model, or provider in modules. The AI host must not be a startup-required dependency: the API process starts if Ollama is down.

2. Add a shared AI library under `backend/src/lib/ai/` modeled on storage (`src/lib/storage/`):
   - Provider interface: `complete({ system, user, model, temperature, timeoutMs, signal }) → { text, model, provider }`
   - Factory selected by `AI_PROVIDER`
   - `ollama` adapter: `POST {AI_BASE_URL}/api/chat`, `stream: false`, Node built-in `fetch`
   - Task registry: each task exports `{ key, systemPrompt, inputSchema, outputParser, failOpen }`
   - `runTask(key, input, { signal })` loads the task, validates input, calls the provider, parses output
   Services and controllers must not import the Ollama adapter. They call `runTask` or the factory only. Adding a future provider is a new adapter file plus an `AI_PROVIDER` allowlist entry. Adding a future task is a new registry entry plus tests; the HTTP route stays generic.

3. Add backend module `ai` (no repository/Prisma): Zod schemas, service, controller, routes. Mount under `/api/v1/ai`. Authenticate every route. Authorize with `profile:read` so any signed-in user can use utilities that shared fields need. Do not add a new permission key or subscription module in v1.

4. Public HTTP contract (snake_case, versioned under `/api/v1/`):
   - `GET /api/v1/ai/status` → `{ enabled, provider, model, ready }` where `ready` is whether the configured provider answered a cheap probe (or `false` if disabled/unreachable). Do not expose `AI_BASE_URL`, secrets, or system prompts.
   - `POST /api/v1/ai/tasks/:task_key` → body is task-specific JSON; response `{ task_key, output, model, provider, degraded }`
   Unknown `task_key` → 404. Invalid body → 400. Unauthenticated → existing auth error. Provider timeout, unreachable host, empty completion, or `AI_ENABLED=false` → HTTP 200 with `degraded: true` and the task’s fail-open output (for `speech_format`, original `transcript`). Do not return 5xx for provider failure.

5. Register task `speech_format` as the first capability. Body:
   - `transcript` (required string, trimmed, max `AI_MAX_INPUT_CHARS`)
   - `mode` (required enum: `text` | `email` | `digits` | `decimal` | `date` | `time` | `phone` | `currency`)
   - `locale` (optional string, default `en`)
   - `hint` (optional string, max 200 chars; field label or format hint such as `YYYY-MM-DD`)
   Output: `{ formatted_text, mode }`. The model **edits format only**. It must not invent clinical facts, diagnoses, medications, identifiers, or missing values. It must not wrap the answer in markdown or explanation. Mode rules:
   - `text`: punctuation words → marks; spoken cardinals → digits; preserve meaning and paragraph breaks
   - `email`: `name at domain dot com` → `name@domain.com`; no spaces
   - `digits`: spoken or mixed digits → integer digit string
   - `decimal` / `currency`: spoken amount → numeric string with `.` decimal separator
   - `phone`: digit sequence only (no country-code invention)
   - `date`: ISO `YYYY-MM-DD` when a full date is present; otherwise the clearest partial the utterance supports
   - `time`: `HH:mm` 24-hour when a time is present

6. Frontend accesses AI **only** through the existing network stack (`dio`, `HmsApiResource`, domain repository, data source). No widget, coordinator, or feature may call Ollama, `AI_BASE_URL`, or any model host. Add `HmsApiResource.ai` and an `AiRepository` with `status()` and `runTask(taskKey, body, { cancelToken })`. Speech-to-text is one consumer of that repository, not a private HTTP client.

7. Enforce this pipeline in `AppSpeechToTextCoordinator` so every shared field that already uses `AppSpeechToTextButton` gets it without per-screen wiring: `AppTextField`, `AppPhoneField`, `AppDateField`, `AppTimeField`, `AppCurrencyAmountField`, `AppSearchBar`, `AppSelectField`, `AppRichTextEditor`, and other existing speech-enabled controls. Map keyboard / field type to the task `mode` enum. Password / obscured fields remain speech-disabled.
   - Partial STT results: local transform only; insert into the field; do not call AI.
   - Final STT result: insert the local-transformed STT text first, then if AI is available call `runTask('speech_format', { transcript, mode, … })` with that text and replace only the current dictation span with `formatted_text`.
   - If AI is not available, skip the API and leave the STT text in the field. Dictation must still succeed.

8. Remote formatting must not block typing or mic stop. Cancel in-flight AI requests when the user starts a new utterance, edits the field, or disposes the control. If the user has already typed over the inserted transcript, do not overwrite their edit.

9. Loading: no full-screen spinner. The mic control may show a brief busy state only while a final `speech_format` request is in flight; do not disable the whole form. Empty transcript: do not call the API. Error/degraded: keep the locally transformed transcript; do not show a blocking error dialog. Offline: skip the API (existing offline mic messaging stays as-is). Success: replace only the current dictation span with `formatted_text`. Field validators stay on the field.

10. Do not log prompts, transcripts, completions, or PHI. Sanitize AI errors the same way other outbound integrations are sanitized. Do not send payloads to any host other than `AI_BASE_URL`.

## Constraints

- Follow `prompts/.cursor/prompt.mdc` implementation rules, `backend/.cursor/architecture.mdc`, `backend/.cursor/project-structure.mdc`, `backend/.cursor/constants-env.mdc`, `backend/.cursor/storage.mdc` (provider/factory pattern), `frontend/.cursor/network_api.mdc`, `frontend/.cursor/project_structure.mdc`, `frontend/.cursor/components.mdc`, and `frontend/.cursor/localization_i18n.mdc`. Skip Prisma and the permissions catalog because this module has no table in v1.
- Reuse existing speech insertion (`insertSpeechTranscript`, session prefix/suffix) and local normalizers. Do not replace the platform speech engine. Do not send audio to the backend or to the model. AI receives STT text only.
- Do not add npm packages if `fetch` is sufficient.
- Do not put provider URLs, model names, or API keys in the Flutter client or in committed secrets.
- Do not recreate `screens/` inventory. Do not implement extra tasks beyond `speech_format` in this change. Do not drive unrelated refactors.

## Optional enhancements

- In-process LRU cache keyed by `(task_key, canonical_input)` with a small cap.
- Optional per-task model override later via `AI_TASK_<TASK_KEY>_MODEL` without changing the HTTP contract.
- Probe cache for `GET /api/v1/ai/status` so the frontend can skip format calls when `ready` is false.

## Acceptance Criteria

- AC1 (Req 1): Backend starts with AI unset or Ollama unreachable. All AI settings are read only from `env.js`. Changing `AI_MODEL` / `AI_BASE_URL` / `AI_PROVIDER` does not require frontend changes.
- AC2 (Req 2–4): Authenticated `GET /api/v1/ai/status` and `POST /api/v1/ai/tasks/speech_format` work. Unknown task keys return 404. Unauthenticated requests are rejected. Provider down still returns 200 with `degraded: true` and original `transcript` as `formatted_text`.
- AC3 (Req 2): Service tests complete a task through the factory with a mocked provider. No service/controller test imports the Ollama adapter. A second mocked provider can be selected by config in unit tests without changing the task or route.
- AC4 (Req 5): Fixture inputs for each `mode` produce format-only output (no markdown, no invented facts) when the provider is mocked with known completions.
- AC5 (Req 6–7): Frontend speech code calls `AiRepository.runTask` only; it does not contain Ollama URLs or audio payloads. A final dictation inserts STT text first, then triggers one `speech_format` request when AI is available; partials do not call AI. Phone, date, time, currency, and email fields send the matching `mode`.
- AC6 (Req 7–9): When AI is unavailable, disabled, offline, or degraded, the field still contains the STT text. A user edit during an in-flight format request is not overwritten. Obscured fields still have no mic.
- AC7: Unauthorized UI is unchanged: no new menu, screen, or permission chip. Authorized signed-in users keep existing mic buttons.

## Relevant Files

- `backend/src/config/env.js`
- `backend/src/app/router.js`
- `backend/src/config/permissions.js`
- `backend/src/lib/storage/` (provider/factory pattern to mirror)
- `frontend/lib/core/network/api_endpoints.dart`
- `frontend/lib/shared/components/app_speech_to_text.dart`
- `frontend/lib/shared/components/app_text_field.dart`
- `frontend/lib/shared/components/app_phone_field.dart`
- `frontend/lib/shared/components/app_date_field.dart`
- `frontend/lib/shared/components/app_time_field.dart`
- `frontend/lib/shared/components/app_currency_amount_field.dart`
- `frontend/test/shared/components/app_speech_to_text_test.dart`
- `backend/.cursor/constants-env.mdc`
- `backend/.cursor/architecture.mdc`
- `backend/.cursor/storage.mdc`
- `frontend/.cursor/network_api.mdc`

## Verification

- Backend: env validation, factory allowlist, schema, route, controller, and `runTask` tests with a mocked provider (success, timeout, empty completion, disabled flag, unknown task, unauthenticated).
- Prove a second in-test provider can satisfy `speech_format` without route changes.
- Frontend: `AiRepository` tests plus coordinator tests proving STT insert happens before any AI call, AI is skipped when not available, final-only format calls, cancellation, and “do not overwrite user edits”.
- Manual: stop Ollama, dictate, confirm STT text still appears. Start Ollama, dictate the same kinds of fields (text, email, phone, date, amount, notes), confirm STT text appears first and is then replaced by formatted text. Confirm `GET /api/v1/ai/status` shows `ready: false` when Ollama is stopped.
- Confirm no new unauthorized chrome and that existing mic buttons remain for signed-in users.
- Representative viewports and light/dark themes: mic control layout unchanged except optional brief busy state.
