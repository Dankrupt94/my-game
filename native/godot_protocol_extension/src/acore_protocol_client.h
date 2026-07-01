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
    godot::Dictionary move_heartbeat(
        godot::String const& host,
        godot::String const& port,
        godot::String const& account,
        godot::String const& password,
        godot::String const& character_name,
        double delta_x,
        double delta_y,
        double delta_orientation);
};
