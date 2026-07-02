# Local AI Resources

## Available Local Models

As of 2026-07-02, Ollama lists these local models:

```text
qwen2.5-coder:7b
qwen-agent:latest
qwen2.5-coder:14b
```

Primary coding model:

```text
qwen2.5-coder:7b
```

Recommended local model roles on this machine:

```text
qwen2.5-coder:7b   Fast helper for small snippets and quick second opinions.
qwen-agent:latest  Agent-flavored helper when already loaded by Ollama.
qwen2.5-coder:14b  Slower reviewer for tricky local-only code or diff review.
```

The workstation currently has an NVIDIA GTX 1080 with 8 GB VRAM and about
24 GB system RAM. That makes a 14B coding model a reasonable upper-middle
tradeoff for local review. Larger 24B/30B/32B models may run partly from system
RAM, but they are expected to be slow enough that they should not be the normal
inner-loop coding assistant for this project.

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

The local model is useful, but only as an advisory reviewer. It is best for
small, safe, bounded context: a function, a compact diff, a failing compiler
message, or a short design tradeoff. It is not the project supervisor, and it
does not replace direct code reading, Godot/native builds, tests, or live
AzerothCore validation.

## GPU Ownership Rule

Ollama can keep a model loaded on the GPU after a request. On this machine that
can reserve most of the GTX 1080's 8 GB VRAM, which makes Godot rendering,
Blender, graphics tracing, conversion experiments, and GPU debugging worse.

Before GPU-bound port work, check for loaded local models:

```bash
ollama ps
```

If a model is loaded and the task needs the GPU, unload it first:

```bash
ollama stop qwen-agent
ollama stop qwen2.5-coder:7b
ollama stop qwen2.5-coder:14b
```

Only restart a model when the task is returning to small local-AI review.

## Guardrails

- Treat local model output as assistance, not authority.
- Verify generated code before committing.
- Do not give local models secrets unless a task explicitly requires it and the
  handling is documented.
- Do not ask local models to copy proprietary client assets into this repo.
- Do not let any AI helper revert local AzerothCore source changes without explicit permission.
- Unload local models before GPU-bound Godot, Blender, graphics-capture,
  conversion, or native debugging tasks.
- Keep Git commits and task notes as the source of truth for project changes.

## Practical Recommendation

Use `qwen2.5-coder:7b` when speed matters. Use `qwen2.5-coder:14b` for a
deliberate second pass on harder Godot, C++, or protocol changes. Avoid
24B/30B/32B local models as the default unless this machine is upgraded or a
specific task is worth waiting much longer for.

## How To Recheck Availability

```bash
ollama list
```

## Future Integration Ideas

- Add a Godot button to ask the local model to summarize recent server logs.
- Add a bridge endpoint that sends safe, redacted diagnostics to `qwen2.5-coder:7b`.
- Add local code-review helpers for Godot scripts and bridge-service code.
- Add stage documentation summaries generated from recent commits and logs.
