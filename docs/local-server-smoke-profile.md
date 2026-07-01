# Local Server Smoke Profile

This project uses a local AzerothCore smoke profile when validating the Godot-native protocol client. The profile is for fast, repeatable protocol checks only; it is not the final gameplay compatibility target.

## Active Local Settings

Applied locally on 2026-06-30 under `/run/media/doodbro/New 1tb/AzerothCore`:

- `Warden.Enabled = 0`
- `AiPlayerbot.RandomBotAutologin = 0`
- `AiPlayerbot.MinRandomBots = 0`
- `AiPlayerbot.MaxRandomBots = 0`

These settings were applied to the editable config copies in `configs/` and to the active runtime copies under `run/etc/` and `run/bin/`.

## Why These Are Off For Stage 11

- Warden sends `SMSG_WARDEN_DATA` before the normal character-list path. Full Warden module handling remains a later compatibility task.
- Random bot autologin can start hundreds of bots during server boot, delaying session initialization and making protocol smoke tests slow and noisy.
- Disabling random bot autologin does not delete bot accounts, character data, or module support; it only prevents the large startup login wave.

## Local Test Account

The disposable protocol account is `CODEXPROTO`.

Its password is stored only in the ignored local file `local_runtime/protocol-test-account.env`. Do not commit or print that file.

## Local Test Fixtures

`tools/prepare_trainer_buy_fixture.py` prepares `Codexstage` for the repeatable trainer-buy success check by ensuring enough copper and clearing only the Stage 17 test spell from `character_spell`. The tool refuses to mutate an online character by default and writes an ignored audit entry to `local_runtime/database-transactions.log`.

## Current Validation

With this smoke profile active, the native helper completed:

- authserver SRP6 proof,
- realm-list parsing,
- worldserver `CMSG_AUTH_SESSION`,
- encrypted world header handling,
- ignored non-character startup packets,
- encrypted `CMSG_CHAR_ENUM`,
- live `SMSG_CHAR_ENUM` parsing with `CHAR_ENUM_OK count=0`.

## Restore Notes

For gameplay testing with the original local server behavior, restore the changed config values and restart AzerothCore:

- `Warden.Enabled = 1`
- `AiPlayerbot.RandomBotAutologin = 1`
- `AiPlayerbot.MinRandomBots = 700`
- `AiPlayerbot.MaxRandomBots = 900`
