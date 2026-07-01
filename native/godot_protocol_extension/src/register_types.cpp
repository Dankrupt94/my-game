#include "register_types.h"

#include "acore_protocol_client.h"

#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_acore_protocol_module(ModuleInitializationLevel level)
{
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE)
    {
        return;
    }

    GDREGISTER_CLASS(AcoreProtocolClient);
}

void uninitialize_acore_protocol_module(ModuleInitializationLevel level)
{
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE)
    {
        return;
    }
}

extern "C"
{
GDExtensionBool GDE_EXPORT acore_protocol_library_init(
    GDExtensionInterfaceGetProcAddress get_proc_address,
    GDExtensionClassLibraryPtr library,
    GDExtensionInitialization* initialization)
{
    GDExtensionBinding::InitObject init_obj(get_proc_address, library, initialization);

    init_obj.register_initializer(initialize_acore_protocol_module);
    init_obj.register_terminator(uninitialize_acore_protocol_module);
    init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

    return init_obj.init();
}
}
