# Local AI Resources

## Available Local Models

As of 2026-06-30, Ollama lists these local models:

```text
qwen2.5-coder:7b
qwen-agent:latest
```

Primary coding model:

```text
qwen2.5-coder:7b
```

Default local Ollama endpoint:

```text
http://127.0.0.1:11434
```

## Intended Uses

The local Qwen Coder model may be used by Codex or other AI helpers for:

- drafting Godot GDScript helpers,
- reviewing small code changes,
- summarizing local logs,
- sketching bridge-service endpoint code,
- generating test cases,
- explaining AzerothCore source snippets,
- comparing implementation options.

## Guardrails

- Treat local model output as assistance, not authority.
- Verify generated code before committing.
- Do not give local models secrets unless a task explicitly requires it and the handling is documented.
- Do not ask local models to copy proprietary client assets into this repo.
- Do not let any AI helper revert local AzerothCore source changes without explicit permission.
- Keep Git commits and task notes as the source of truth for project changes.

## How To Recheck Availability

```bash
ollama list
```

## Future Integration Ideas

- Add a Godot button to ask the local model to summarize recent server logs.
- Add a bridge endpoint that sends safe, redacted diagnostics to `qwen2.5-coder:7b`.
- Add local code-review helpers for Godot scripts and bridge-service code.
- Add stage documentation summaries generated from recent commits and logs.

