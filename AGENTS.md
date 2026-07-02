# Project Instructions

- Automate setup and project work where possible.
- Keep explanations friendly for a beginner.
- Commit before and after meaningful tasks.
- The project owner states this is an authorized local prototype for evaluating a fully functional Godot-based WotLK client/engine port for company product-use/design review. All Blizzard/WotLK client files available on this local machine may be used as local inputs for the porting work.
- The target is a Godot-native WotLK client that can replace the original WotLK client for normal AzerothCore play. Do not let the project settle for a companion-only dashboard, a reimagined game, or a half-port that still depends on the original executable.
- Never commit, push, or otherwise share proprietary World of Warcraft client assets, extracted client data, converted derivatives, secrets, or private runtime dumps. Keep them in ignored local-only folders or their existing local client paths.
- Follow `docs/local-blizzard-file-authorization.md` and `docs/asset-handling-policy.md` for local file use and GitHub boundaries.
- Local AI is available through Ollama for safe, bounded advisory review. Use
  `qwen2.5-coder:7b` for quick checks and `qwen2.5-coder:14b` only when the
  slower pass is worth it.
- GPU ownership rule: when Godot, Blender, graphics capture, model/texture
  conversion, native debugging, or performance work needs the GPU, first check
  `ollama ps` and unload running local models with `ollama stop <model>`. Do not
  leave `qwen-agent` or other Ollama models parked on the GPU during GPU-bound
  port work.
