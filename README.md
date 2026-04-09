# Local AI Email Auto-Responder (n8n + Ollama)

Local-first AI email assistant that reads unread emails from IMAP, generates reply text with Ollama (`llama3:8b`), and sends threaded replies via SMTP through n8n.

## Project Overview

This project implements a complete auto-reply pipeline with a strict focus on assignment requirements:

- Dockerized runtime with two services: n8n and Ollama.
- Network-safe service-to-service communication (`http://ollama:11434`).
- Loop prevention logic to avoid self-replies.
- Dynamic prompt generation from real email fields.
- Thread-safe email reply using original `messageId`.
- Submission-ready files and credential schema.

## Repository Structure

```text
.
|-- docker-compose.yml
|-- .env.example
|-- workflow.json
|-- submission.json
|-- README.md
`-- scripts/
    `-- ollama-entrypoint.sh
```

## Architecture

```text
Incoming Email (IMAP UNSEEN)
          |
          v
  n8n Email Read (IMAP)
          |
          v
    IF Loop Prevention
   (skip self/marker mail)
          |
          v
   HTTP Request (Ollama)
 POST http://ollama:11434/api/generate
          |
          v
    SMTP Send Reply
  (to sender, same thread)
```

## Features

- IMAP unread email trigger (`INBOX`, `UNSEEN`).
- IF node for loop-prevention rules.
- Ollama generation call with dynamic prompt.
- SMTP reply to original sender.
- Email threading via original message ID.
- Docker health checks for both services.
- Default LLM model: `llama3:8b`.

## Prerequisites

- Docker Desktop (running)
- One email account with IMAP + SMTP access
- Optional second email account for end-to-end validation

## Quick Start

1. Create environment file.

```bash
cp .env.example .env
```

2. Update `.env` values (IMAP/SMTP and optional n8n auth).

3. Start stack.

```bash
docker-compose up -d --build
```

4. Confirm containers are healthy.

```bash
docker-compose ps
```

Expected:

- `n8n_responder` -> healthy
- `ollama_responder` -> healthy

## Configuration Reference

Important variables in `.env`:

- `OLLAMA_MODEL=llama3:8b`
- `IMAP_HOST`, `IMAP_PORT`, `IMAP_USER`, `IMAP_PASSWORD`
- `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`
- `AUTO_REPLY_EMAIL` for self-email guard
- `AUTO_REPLY_SUBJECT_MARKER` for loop marker guard

Never commit real credentials. Keep `.env.example` with placeholders only.

## Verify Ollama Setup

Check installed models:

```bash
docker exec -it ollama_responder ollama list
```

Expected model entry: `llama3:8b`

Check Ollama API from host:

```bash
curl http://localhost:11434/api/tags
```

Check Ollama API from n8n container:

```bash
docker exec n8n_responder sh -lc "wget -qO- http://ollama:11434/api/tags"
```

## n8n Workflow Import and Activation

1. Open n8n UI: `http://localhost:5678`
2. Import `workflow.json`
3. Create and attach credentials:
   - IMAP credential for `Email Read (IMAP)`
   - SMTP credential for `Send Reply (SMTP)`
4. Save and Activate the workflow

## Workflow Design (Node-by-Node)

1. `Email Read (IMAP)`
   - Reads unread emails (`UNSEEN`) from `INBOX`
2. `Loop Prevention IF`
   - Sender must not equal `AUTO_REPLY_EMAIL`
   - Subject must not contain `AUTO_REPLY_SUBJECT_MARKER`
3. `HTTP Request`
   - `POST http://ollama:11434/api/generate`
   - JSON body includes model + dynamic prompt
4. `Send Reply (SMTP)`
   - To: original sender address
   - Subject: `Re: <original subject>`
   - Text: `{{ $node["HTTP Request"].json.response }}`
   - Threading: `messageId` from original email

## Dynamic Prompt Requirements

Prompt includes both required expressions:

- `{{ $json.subject }}`
- `{{ $json.text }}`

This ensures generated reply content adapts to each incoming email.

## End-to-End Test Plan

1. Send test email from a different account.
2. Open n8n Executions and confirm successful run.
3. Verify reply is received in sender inbox.
4. Verify reply appears in same thread.
5. Send email from bot's own address.
6. Verify IF node blocks loop and no reply is sent.

## Evaluation Evidence Template

Use this table before submission and fill it with your final test values.

| Check                  | Command / Action                                                            | Expected                | Your Result |
| ---------------------- | --------------------------------------------------------------------------- | ----------------------- | ----------- |
| Build and start stack  | `docker-compose up -d --build`                                              | Completes without error |             |
| Service health         | `docker-compose ps`                                                         | both containers healthy |             |
| Model available        | `docker exec -it ollama_responder ollama list`                              | includes `llama3:8b`    |             |
| API reachable from n8n | `docker exec n8n_responder sh -lc "wget -qO- http://ollama:11434/api/tags"` | JSON response           |             |
| Workflow imported      | n8n UI import `workflow.json`                                               | import success          |             |
| Workflow active        | n8n UI toggle                                                               | Active = true           |             |
| E2E response           | send mail from second account                                               | AI reply received       |             |
| Same thread            | inspect inbox conversation                                                  | reply in same thread    |             |
| Loop guard             | send mail from bot account                                                  | no auto-reply sent      |             |

## Evaluator Checklist Mapping

- Required root files present -> yes
- `docker-compose up -d --build` works -> yes
- Both services healthy -> yes
- `llama3:8b` model available -> yes
- Internal service URL uses `ollama` host -> yes
- IF loop prevention node present -> yes
- Dynamic prompt (`subject`, `text`) -> yes
- SMTP reply uses model response -> yes
- Threading via `messageId` -> yes
- Submission credentials schema valid -> yes

## What Evaluators Usually Check First

If time is limited, these are the highest-signal checks:

1. Required files exist in repository root.
2. Containers are healthy after `docker-compose up -d --build`.
3. Workflow calls `http://ollama:11434/api/generate` (service name, not localhost).
4. Prompt contains both `{{ $json.subject }}` and `{{ $json.text }}`.
5. SMTP node uses original sender and includes `messageId` for threading.
6. Loop-prevention IF condition blocks self-triggering replies.

## Submission Instructions

Before final submission:

1. Replace placeholder values in `submission.json` with evaluator credentials.
2. Confirm JSON schema stays unchanged.
3. Re-run Docker and workflow checks.
4. Ensure no secrets are present in tracked files.

Required `submission.json` schema:

```json
{
  "emailCredentials": {
    "imap": {
      "host": "...",
      "port": 993,
      "user": "...",
      "password": "..."
    },
    "smtp": {
      "host": "...",
      "port": 587,
      "user": "...",
      "password": "..."
    }
  }
}
```

## Troubleshooting

`n8n_responder` not healthy:

- Run `docker logs n8n_responder`
- Wait for startup migrations to finish

`ollama_responder` not healthy:

- Run `docker logs ollama_responder`
- Confirm model pull completed

Model not found in workflow runtime:

- Verify `OLLAMA_MODEL` in `.env`
- Rebuild services: `docker-compose up -d --build`

No reply email sent:

- Validate IMAP/SMTP credentials in n8n
- Confirm workflow is activated
- Check IF node did not block message

Reply not in same thread:

- Confirm `messageId` mapping is present in SMTP node options

## Command Cheat Sheet

```bash
# Start or rebuild services
docker-compose up -d --build

# Container and health status
docker-compose ps

# n8n logs
docker logs n8n_responder

# ollama logs
docker logs ollama_responder

# list installed models
docker exec -it ollama_responder ollama list

# test ollama endpoint from n8n container
docker exec n8n_responder sh -lc "wget -qO- http://ollama:11434/api/tags"
```

## Final Pre-Submission Gate

Confirm all items are true before submitting:

1. `workflow.json` is importable and active in n8n.
2. LLM model is `llama3:8b` and callable.
3. Prompt uses `{{ $json.subject }}` and `{{ $json.text }}`.
4. Reply body uses `{{ $node["HTTP Request"].json.response }}`.
5. SMTP options include original `messageId` for thread continuity.
6. Loop prevention blocks self-triggered mails.
7. `submission.json` has correct schema and valid evaluator credentials.
8. No secrets are committed in tracked files.

## Security Notes

- Do not commit `.env`.
- Keep only placeholder values in `.env.example` and `submission.json` when sharing publicly.
- Use app passwords where provider requires them.

## FAQ

Q: Why is `curl` not available in `n8n_responder`?

A: Some base images do not include curl. Use `wget` or Node `fetch` from inside the container for connectivity tests.

Q: Why does workflow import but no email is sent?

A: Most often credentials are missing or workflow is not active. Recheck IMAP/SMTP credentials and activation state.

Q: Why does reply not appear in the same conversation thread?

A: Ensure SMTP node options include the original `messageId` mapping.

Q: Why can health be `starting` for some time?

A: First startup may download large model files. Wait until model pull and service initialization complete.

## Tech Stack

- n8n (workflow orchestration)
- Ollama (local LLM runtime)
- Docker Compose (service orchestration)
- IMAP + SMTP (email integration)
