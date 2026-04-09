# Local AI Email Auto-Responder (n8n + Ollama)

A fully local, privacy-first email auto-responder that reads incoming emails via IMAP, generates context-aware replies with a local LLM through Ollama, and sends threaded responses via SMTP using n8n.

## What This Project Includes

- `docker-compose.yml` with `n8n` and `ollama` services.
- Shared custom Docker network (`ai_responder_net`).
- Named persistent volumes for n8n and Ollama data.
- Health checks for both services.
- Automatic model pull for Ollama startup (`llama3:8b` by default).
- `workflow.json` export with:
  - IMAP trigger (`n8n-nodes-base.emailReadImap`)
  - Loop-prevention IF logic (`n8n-nodes-base.if`)
  - Ollama POST request (`n8n-nodes-base.httpRequest`)
  - SMTP reply node (`n8n-nodes-base.emailSend`)
  - Threading support (`messageId` passed to reply options)
- `.env.example` documenting all required variables.
- `submission.json` in the required schema.

## Prerequisites

- Docker Desktop
- A reachable IMAP/SMTP email account for testing

## 1) Setup

1. Copy `.env.example` to `.env`.
2. Update `.env` values for your environment.
3. Start services:

```bash
docker-compose up -d --build
```

4. Check status/health:

```bash
docker-compose ps
```

Both `n8n_responder` and `ollama_responder` should become healthy. On first run this may take a few minutes while Ollama downloads the model.

## 2) Verify Ollama Model Is Available

The Ollama container auto-pulls the model set by `OLLAMA_MODEL` (default: `llama3:8b`) on startup.

Check installed models:

```bash
docker exec -it ollama_responder ollama list
```

Or verify with API tags endpoint:

```bash
curl http://localhost:11434/api/tags
```

Expected: JSON contains a model where `name` matches `llama3:8b` (or your configured `OLLAMA_MODEL`).

If you want to use a different model than the assignment default, set this in `.env` before startup:

```bash
OLLAMA_MODEL=llama3:8b
```

## 3) Import and Configure n8n Workflow

1. Open n8n at `http://localhost:5678`.
2. Import `workflow.json` from the repository root.
3. Create credentials in n8n:
   - IMAP credential for `Email Read (IMAP)`.
   - SMTP credential for `Send Reply (SMTP)`.
4. Map credentials to the nodes (if not auto-mapped by name).
5. Save and activate the workflow.

## 4) Workflow Behavior

1. Trigger on unread emails in `INBOX`.
2. `Loop Prevention IF` allows processing only when:
   - sender is not your auto-reply address, and
   - subject does not contain the auto-reply marker.
3. HTTP request calls `http://ollama:11434/api/generate` with a dynamic prompt that includes:
   - `{{ $json.subject }}`
   - `{{ $json.text }}` (fallback to HTML when needed)
4. SMTP node sends the generated response back to original sender.
5. `messageId` is set from original email to preserve thread continuity.

## 5) End-to-End Test

1. Send an email from a different account to your configured inbox.
2. Inspect n8n Executions to confirm flow reaches all nodes.
3. Verify a reply arrives in the sender inbox.
4. Confirm the reply appears in the same thread.
5. Send an email from your bot address to itself and verify IF node prevents reply loop.

## 6) Submission File

Update `submission.json` with valid evaluation credentials before submitting:

- `emailCredentials.imap.host`
- `emailCredentials.imap.port`
- `emailCredentials.imap.user`
- `emailCredentials.imap.password`
- `emailCredentials.smtp.host`
- `emailCredentials.smtp.port`
- `emailCredentials.smtp.user`
- `emailCredentials.smtp.password`

## Troubleshooting

- n8n cannot reach Ollama:
  - Ensure both are on `ai_responder_net` and URL uses `http://ollama:11434`.
- Model not found:
  - Run `docker exec -it ollama_responder ollama list` and match `OLLAMA_MODEL`.
- Workflow imports but does not send:
  - Confirm IMAP/SMTP credentials are configured in n8n.
- Loop prevention too strict/loose:
  - Adjust `AUTO_REPLY_EMAIL` and `AUTO_REPLY_SUBJECT_MARKER` in `.env`.
