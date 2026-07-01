#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

class AcoreProtocolClient : public godot::RefCounted
{
    GDCLASS(AcoreProtocolClient, godot::RefCounted)

protected:
    static void _bind_methods();

public:
    godot::Dictionary self_test();
    godot::Dictionary character_flow(
        godot::String const& host,
        godot::String const& port,
        godot::String const& account,
        godot::String const& password);
    godot::Dictionary create_character(
        godot::String const& host,
        godot::String const& port,
        godot::String const& account,
        godot::String const& password,
        godot::String const& name);
    godot::Dictionary enter_world(
        godot::String const& host,
        godot::String const& port,
        godot::String const& account,
        godot::String const& password,
        godot::String const& character_name);
    godot::Dictionary visible_targets_snapshot(
        godot::String const& host,
        godot::String const& port,
        godot::String const& account,
        godot::String const& password,
        godot::String const& character_name);
    godot::Dictionary move_heartbeat(
        godot::String const& host,
        godot::String const& port,
        godot::String const& account,
        godot::String const& password,
        godot::String const& character_name,
        double delta_x,
        double delta_y,
        double delta_orientation);
    godot::Dictionary interact_with_npc(
        godot::String const& host,
        godot::String const& port,
        godot::String const& account,
        godot::String const& password,
        godot::String const& character_name,
        int64_t target_entry,
        godot::String const& target_name);
    godot::Dictionary combat_probe(
        godot::String const& host,
        godot::String const& port,
        godot::String const& account,
        godot::String const& password,
        godot::String const& character_name,
        int64_t target_entry,
        godot::String const& target_name);
    godot::Dictionary loot_open_probe(
        godot::String const& host,
        godot::String const& port,
        godot::String const& account,
        godot::String const& password,
        godot::String const& character_name,
        int64_t target_entry,
        godot::String const& target_name);
    godot::Dictionary loot_open_probe_selector(
        godot::String const& host,
        godot::String const& port,
        godot::String const& account,
        godot::String const& password,
        godot::String const& character_name,
        godot::String const& target_selector,
        godot::String const& target_name);
    godot::Dictionary corpse_loot_probe(
        godot::String const& host,
        godot::String const& port,
        godot::String const& account,
        godot::String const& password,
        godot::String const& character_name,
        int64_t target_entry,
        godot::String const& target_name);
    godot::Dictionary corpse_loot_probe_selector(
        godot::String const& host,
        godot::String const& port,
        godot::String const& account,
        godot::String const& password,
        godot::String const& character_name,
        godot::String const& target_selector,
        godot::String const& target_name);
    godot::Dictionary loot_inventory_handoff_probe(
        godot::String const& host,
        godot::String const& port,
        godot::String const& account,
        godot::String const& password,
        godot::String const& character_name,
        int64_t target_entry,
        godot::String const& target_name);
    godot::Dictionary loot_inventory_handoff_probe_selector(
        godot::String const& host,
        godot::String const& port,
        godot::String const& account,
        godot::String const& password,
        godot::String const& character_name,
        godot::String const& target_selector,
        godot::String const& target_name);
    godot::Dictionary chat_say(
        godot::String const& host,
        godot::String const& port,
        godot::String const& account,
        godot::String const& password,
        godot::String const& character_name,
        godot::String const& message);
    godot::Dictionary chat_whisper_self(
        godot::String const& host,
        godot::String const& port,
        godot::String const& account,
        godot::String const& password,
        godot::String const& character_name,
        godot::String const& message);
    godot::Dictionary spellbook(
        godot::String const& host,
        godot::String const& port,
        godot::String const& account,
        godot::String const& password,
        godot::String const& character_name);
    godot::Dictionary action_buttons(
        godot::String const& host,
        godot::String const& port,
        godot::String const& account,
        godot::String const& password,
        godot::String const& character_name);
    godot::Dictionary inventory_snapshot(
        godot::String const& host,
        godot::String const& port,
        godot::String const& account,
        godot::String const& password,
        godot::String const& character_name);
    godot::Dictionary swap_inventory_slots(
        godot::String const& host,
        godot::String const& port,
        godot::String const& account,
        godot::String const& password,
        godot::String const& character_name,
        int64_t source_slot,
        int64_t destination_slot);
    godot::Dictionary split_inventory_stack(
        godot::String const& host,
        godot::String const& port,
        godot::String const& account,
        godot::String const& password,
        godot::String const& character_name,
        int64_t source_slot,
        int64_t destination_slot,
        int64_t split_count);
    godot::Dictionary set_action_button(
        godot::String const& host,
        godot::String const& port,
        godot::String const& account,
        godot::String const& password,
        godot::String const& character_name,
        int64_t button,
        int64_t action,
        int64_t type);
    godot::Dictionary cast_spell(
        godot::String const& host,
        godot::String const& port,
        godot::String const& account,
        godot::String const& password,
        godot::String const& character_name,
        int64_t spell_id);
    godot::Dictionary cast_spell_at_target(
        godot::String const& host,
        godot::String const& port,
        godot::String const& account,
        godot::String const& password,
        godot::String const& character_name,
        int64_t spell_id,
        int64_t target_entry,
        godot::String const& target_name);
};
