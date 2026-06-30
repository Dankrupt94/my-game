# Stage 16 - WotLK Client Feature March

Status: Planned

## Goal

Rebuild the WotLK client feature set in Godot as faithfully as possible, one vertical slice at a time.

This stage is not a loose inspiration pass. It is the long feature-parity march toward a fully functional Godot-native WotLK client. The original WotLK client may be used for local comparison and validation, but it is not an acceptable runtime dependency.

## Feature Areas

- Chat.
- Inventory.
- Equipment.
- Loot.
- Vendors.
- Quests.
- Trainers.
- Spells.
- Auras.
- Groups.
- Guilds.
- Mail.
- Auction house.
- Maps/minimap.
- Addon-like UI customization, if feasible.

## Entry Criteria

- Stage 15 combat and interaction works.

## Done Criteria

- Each feature area has a working Godot implementation, a test checklist, and a documented parity status.
- Any deviation from original WotLK behavior is documented as a compatibility tweak with a reason.
- No feature is permanently skipped unless a later explicit decision says exact parity is impossible or intentionally deferred.

## Documentation To Update During Work

- Feature checklist.
- Protocol packets per feature.
- UI screens.
- Known behavior differences from WotLK.
- Test cases against AzerothCore.
