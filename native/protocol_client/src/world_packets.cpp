#include "world_packets.h"

#include "protocol_bytes.h"

#include <openssl/evp.h>
#include <zlib.h>

#include <algorithm>
#include <array>
#include <cstring>
#include <memory>
#include <stdexcept>

namespace
{
using MdPtr = std::unique_ptr<EVP_MD_CTX, decltype(&EVP_MD_CTX_free)>;

void append_u8(std::vector<std::uint8_t>& bytes, std::uint8_t value)
{
    bytes.push_back(value);
}

void append_u32_le(std::vector<std::uint8_t>& bytes, std::uint32_t value)
{
    bytes.push_back(static_cast<std::uint8_t>(value & 0xFF));
    bytes.push_back(static_cast<std::uint8_t>((value >> 8) & 0xFF));
    bytes.push_back(static_cast<std::uint8_t>((value >> 16) & 0xFF));
    bytes.push_back(static_cast<std::uint8_t>((value >> 24) & 0xFF));
}

void append_u16_le(std::vector<std::uint8_t>& bytes, std::uint16_t value)
{
    bytes.push_back(static_cast<std::uint8_t>(value & 0xFF));
    bytes.push_back(static_cast<std::uint8_t>((value >> 8) & 0xFF));
}

void append_u64_le(std::vector<std::uint8_t>& bytes, std::uint64_t value)
{
    for (int shift = 0; shift < 64; shift += 8)
    {
        bytes.push_back(static_cast<std::uint8_t>((value >> shift) & 0xFF));
    }
}

void append_packed_guid(std::vector<std::uint8_t>& bytes, std::uint64_t value)
{
    std::uint8_t mask = 0;
    std::array<std::uint8_t, 8> guid_bytes{};
    for (int i = 0; i < 8; ++i)
    {
        guid_bytes[i] = static_cast<std::uint8_t>((value >> (i * 8)) & 0xFF);
        if (guid_bytes[i] != 0)
        {
            mask |= static_cast<std::uint8_t>(1 << i);
        }
    }

    append_u8(bytes, mask);
    for (int i = 0; i < 8; ++i)
    {
        if ((mask & (1 << i)) != 0)
        {
            append_u8(bytes, guid_bytes[i]);
        }
    }
}

void append_float_le(std::vector<std::uint8_t>& bytes, float value)
{
    static_assert(sizeof(float) == sizeof(std::uint32_t));
    std::uint32_t raw = 0;
    std::memcpy(&raw, &value, sizeof(raw));
    append_u32_le(bytes, raw);
}

std::uint8_t read_u8(std::span<const std::uint8_t> bytes, std::size_t& offset)
{
    if (offset + 1 > bytes.size())
    {
        throw std::runtime_error("not enough bytes for uint8");
    }
    return bytes[offset++];
}

std::uint32_t read_u32_le(std::span<const std::uint8_t> bytes, std::size_t& offset)
{
    if (offset + 4 > bytes.size())
    {
        throw std::runtime_error("not enough bytes for uint32");
    }
    std::uint32_t value = static_cast<std::uint32_t>(bytes[offset])
        | (static_cast<std::uint32_t>(bytes[offset + 1]) << 8)
        | (static_cast<std::uint32_t>(bytes[offset + 2]) << 16)
        | (static_cast<std::uint32_t>(bytes[offset + 3]) << 24);
    offset += 4;
    return value;
}

std::uint16_t read_u16_le(std::span<const std::uint8_t> bytes, std::size_t& offset)
{
    if (offset + 2 > bytes.size())
    {
        throw std::runtime_error("not enough bytes for uint16");
    }
    std::uint16_t value = static_cast<std::uint16_t>(bytes[offset])
        | static_cast<std::uint16_t>(bytes[offset + 1] << 8);
    offset += 2;
    return value;
}

std::uint64_t read_u64_le(std::span<const std::uint8_t> bytes, std::size_t& offset)
{
    if (offset + 8 > bytes.size())
    {
        throw std::runtime_error("not enough bytes for uint64");
    }
    std::uint64_t value = 0;
    for (int shift = 0; shift < 64; shift += 8)
    {
        value |= static_cast<std::uint64_t>(bytes[offset++]) << shift;
    }
    return value;
}

std::uint64_t read_packed_guid(std::span<const std::uint8_t> bytes, std::size_t& offset)
{
    std::uint8_t const mask = read_u8(bytes, offset);
    std::uint64_t value = 0;
    for (int i = 0; i < 8; ++i)
    {
        if ((mask & (1 << i)) != 0)
        {
            value |= static_cast<std::uint64_t>(read_u8(bytes, offset)) << (i * 8);
        }
    }
    return value;
}

float read_float_le(std::span<const std::uint8_t> bytes, std::size_t& offset)
{
    std::uint32_t raw = read_u32_le(bytes, offset);
    float value = 0;
    std::memcpy(&value, &raw, sizeof(value));
    return value;
}

void skip_bytes(std::span<const std::uint8_t> bytes, std::size_t& offset, std::size_t count)
{
    if (offset + count > bytes.size())
    {
        throw std::runtime_error("not enough bytes to skip field");
    }
    offset += count;
}

struct UpdateFieldValue
{
    std::uint32_t index = 0;
    std::uint32_t value = 0;
};

constexpr std::uint32_t UnitEndField = 0x0006 + 0x008E;
constexpr std::uint32_t ObjectFieldEntry = 0x0003;
constexpr std::uint32_t UnitFieldHealth = 0x0006 + 0x0012;
constexpr std::uint32_t UnitFieldMaxHealth = 0x0006 + 0x001A;
constexpr std::uint32_t UnitFieldFlags = 0x0006 + 0x0035;
constexpr std::uint32_t UnitDynamicFlags = 0x0006 + 0x0049;
constexpr std::uint32_t ItemFieldStackCount = 0x0006 + 0x0008;
constexpr std::uint32_t ItemFieldDurability = 0x0006 + 0x0036;
constexpr std::uint32_t ItemFieldMaxDurability = 0x0006 + 0x0037;
constexpr std::uint32_t PlayerFieldInvSlotHead = UnitEndField + 0x00B0;
constexpr std::uint32_t PlayerFieldPackSlot1 = UnitEndField + 0x00DE;
constexpr std::uint32_t PlayerFieldCoinage = UnitEndField + 0x03FE;
constexpr std::uint8_t InventorySectionEquipment = 0;
constexpr std::uint8_t InventorySectionBag = 1;
constexpr std::uint8_t InventorySectionBackpack = 2;

std::uint8_t inventory_section_for_slot(std::uint8_t slot)
{
    if (slot < 19)
    {
        return InventorySectionEquipment;
    }
    if (slot < 23)
    {
        return InventorySectionBag;
    }
    return InventorySectionBackpack;
}

std::string read_c_string(std::span<const std::uint8_t> bytes, std::size_t& offset)
{
    std::size_t start = offset;
    while (offset < bytes.size() && bytes[offset] != 0)
    {
        ++offset;
    }
    if (offset >= bytes.size())
    {
        throw std::runtime_error("unterminated character name");
    }
    std::string value(reinterpret_cast<char const*>(bytes.data() + start), offset - start);
    ++offset;
    return value;
}

std::string read_length_string(std::span<const std::uint8_t> bytes, std::size_t& offset)
{
    std::uint32_t const length = read_u32_le(bytes, offset);
    if (offset + length > bytes.size())
    {
        throw std::runtime_error("not enough bytes for length-prefixed string");
    }

    std::size_t value_length = length;
    if (value_length > 0 && bytes[offset + value_length - 1] == 0)
    {
        --value_length;
    }

    std::string value(reinterpret_cast<char const*>(bytes.data() + offset), value_length);
    offset += length;
    return value;
}

std::array<std::uint8_t, 20> sha1(std::initializer_list<std::span<const std::uint8_t>> parts)
{
    MdPtr ctx(EVP_MD_CTX_new(), EVP_MD_CTX_free);
    if (!ctx || EVP_DigestInit_ex(ctx.get(), EVP_sha1(), nullptr) != 1)
    {
        throw std::runtime_error("SHA1 init failed");
    }
    for (auto part : parts)
    {
        if (EVP_DigestUpdate(ctx.get(), part.data(), part.size()) != 1)
        {
            throw std::runtime_error("SHA1 update failed");
        }
    }
    std::array<std::uint8_t, 20> digest{};
    unsigned int len = 0;
    if (EVP_DigestFinal_ex(ctx.get(), digest.data(), &len) != 1 || len != digest.size())
    {
        throw std::runtime_error("SHA1 final failed");
    }
    return digest;
}

void append_synthetic_character(std::vector<std::uint8_t>& payload)
{
    append_u64_le(payload, 0x0000000000001234ULL);
    payload.insert(payload.end(), {'S', 'a', 'f', 'e', 'T', 'e', 's', 't', 0});
    append_u8(payload, 1);  // race
    append_u8(payload, 1);  // class
    append_u8(payload, 0);  // gender
    append_u8(payload, 2);  // skin
    append_u8(payload, 3);  // face
    append_u8(payload, 4);  // hair style
    append_u8(payload, 5);  // hair color
    append_u8(payload, 0);  // facial hair
    append_u8(payload, 80); // level
    append_u32_le(payload, 12);
    append_u32_le(payload, 0);
    append_float_le(payload, -8949.95f);
    append_float_le(payload, -132.493f);
    append_float_le(payload, 83.5312f);
    append_u32_le(payload, 0); // guild
    append_u32_le(payload, 0); // char flags
    append_u32_le(payload, 0); // customize flags
    append_u8(payload, 0);     // first login
    append_u32_le(payload, 0); // pet display
    append_u32_le(payload, 0); // pet level
    append_u32_le(payload, 0); // pet family
    for (std::size_t slot = 0; slot < CharEnumEquipmentSlots; ++slot)
    {
        append_u32_le(payload, 0);
        append_u8(payload, 0);
        append_u32_le(payload, 0);
    }
}

std::vector<std::uint8_t> inflate_update_payload(std::span<const std::uint8_t> payload, std::uint32_t& uncompressed_size)
{
    if (payload.size() < 4)
    {
        throw std::runtime_error("compressed update object payload is too short");
    }

    std::size_t offset = 0;
    uncompressed_size = read_u32_le(payload, offset);
    std::vector<std::uint8_t> inflated(uncompressed_size);
    uLongf destination_size = inflated.size();
    int const result = uncompress(
        inflated.data(),
        &destination_size,
        payload.data() + offset,
        payload.size() - offset);
    if (result != Z_OK || destination_size != inflated.size())
    {
        throw std::runtime_error("could not inflate compressed update object payload");
    }
    return inflated;
}

std::uint16_t high_guid(std::uint64_t guid)
{
    return static_cast<std::uint16_t>((guid >> 48) & 0xFFFF);
}

bool high_guid_has_entry(std::uint16_t high)
{
    switch (high)
    {
        case 0xF100:
        case 0xF101:
        case 0xF110:
        case 0xF120:
        case 0xF130:
        case 0xF140:
        case 0xF150:
            return true;
        default:
            return false;
    }
}

bool high_guid_is_item(std::uint16_t high)
{
    return high == 0x4000;
}

std::uint32_t guid_entry(std::uint64_t guid)
{
    std::uint16_t const high = high_guid(guid);
    if (!high_guid_has_entry(high))
    {
        return 0;
    }
    return static_cast<std::uint32_t>((guid >> 24) & 0x00FFFFFFu);
}

std::uint32_t guid_counter(std::uint64_t guid)
{
    if (high_guid_has_entry(high_guid(guid)))
    {
        return static_cast<std::uint32_t>(guid & 0x00FFFFFFu);
    }
    return static_cast<std::uint32_t>(guid & 0xFFFFFFFFu);
}

std::vector<UpdateFieldValue> read_values_update(std::span<const std::uint8_t> body, std::size_t& offset)
{
    std::uint8_t const block_count = read_u8(body, offset);
    std::vector<std::uint32_t> masks;
    masks.reserve(block_count);
    for (std::uint8_t i = 0; i < block_count; ++i)
    {
        masks.push_back(read_u32_le(body, offset));
    }

    std::vector<UpdateFieldValue> values;
    for (std::uint32_t block = 0; block < masks.size(); ++block)
    {
        std::uint32_t mask = masks[block];
        for (std::uint32_t bit = 0; bit < 32; ++bit)
        {
            if ((mask & (1u << bit)) == 0)
            {
                continue;
            }
            values.push_back(UpdateFieldValue{
                .index = block * 32 + bit,
                .value = read_u32_le(body, offset),
            });
        }
    }
    return values;
}

bool update_value_at(std::vector<UpdateFieldValue> const& values, std::uint32_t index, std::uint32_t& value)
{
    for (UpdateFieldValue const& field : values)
    {
        if (field.index == index)
        {
            value = field.value;
            return true;
        }
    }
    return false;
}

InventoryItemObjectSummary parse_inventory_item_object(
    std::uint64_t guid,
    std::uint8_t object_type,
    std::vector<UpdateFieldValue> const& values)
{
    InventoryItemObjectSummary summary;
    summary.seen = true;
    summary.guid = guid;
    summary.object_type = object_type;

    summary.entry_seen = update_value_at(values, ObjectFieldEntry, summary.entry);
    summary.stack_count_seen = update_value_at(values, ItemFieldStackCount, summary.stack_count);
    summary.durability_seen = update_value_at(values, ItemFieldDurability, summary.durability);
    summary.max_durability_seen = update_value_at(values, ItemFieldMaxDurability, summary.max_durability);
    return summary;
}

InventorySlotSummary make_inventory_slot(std::uint8_t slot)
{
    InventorySlotSummary summary;
    summary.slot = slot;
    summary.section = inventory_section_for_slot(slot);
    return summary;
}

InventorySlotSummary& inventory_slot(PlayerInventorySummary& inventory, std::uint8_t slot)
{
    for (InventorySlotSummary& summary : inventory.slots)
    {
        if (summary.slot == slot)
        {
            return summary;
        }
    }

    inventory.slots.push_back(make_inventory_slot(slot));
    return inventory.slots.back();
}

void ensure_inventory_slots(PlayerInventorySummary& inventory)
{
    for (std::uint8_t slot = 0; slot < PlayerInventorySnapshotSlots; ++slot)
    {
        (void)inventory_slot(inventory, slot);
    }
    std::sort(
        inventory.slots.begin(),
        inventory.slots.end(),
        [](InventorySlotSummary const& left, InventorySlotSummary const& right)
        {
            return left.slot < right.slot;
        });
}

std::uint32_t inventory_field_index_for_slot(std::uint8_t slot)
{
    if (slot < 23)
    {
        return PlayerFieldInvSlotHead + static_cast<std::uint32_t>(slot) * 2;
    }
    return PlayerFieldPackSlot1 + static_cast<std::uint32_t>(slot - 23) * 2;
}

void update_populated_count(PlayerInventorySummary& inventory)
{
    inventory.populated_count = 0;
    inventory.item_detail_count = 0;
    inventory.item_template_count = 0;
    for (InventorySlotSummary const& slot : inventory.slots)
    {
        if (slot.populated)
        {
            ++inventory.populated_count;
        }
        if (slot.item_detail_seen)
        {
            ++inventory.item_detail_count;
        }
        if (slot.item_template_seen)
        {
            ++inventory.item_template_count;
        }
    }
}

void apply_player_inventory_values(
    PlayerInventorySummary& inventory,
    std::uint64_t player_guid,
    std::vector<UpdateFieldValue> const& values)
{
    bool touched = false;
    inventory.player_guid = player_guid;

    std::uint32_t coinage = 0;
    if (update_value_at(values, PlayerFieldCoinage, coinage))
    {
        inventory.coinage = coinage;
        inventory.coinage_seen = true;
        touched = true;
    }

    for (std::uint8_t slot = 0; slot < PlayerInventorySnapshotSlots; ++slot)
    {
        std::uint32_t low = 0;
        std::uint32_t high = 0;
        bool const low_seen = update_value_at(values, inventory_field_index_for_slot(slot), low);
        bool const high_seen = update_value_at(values, inventory_field_index_for_slot(slot) + 1, high);
        if (!low_seen && !high_seen)
        {
            continue;
        }

        InventorySlotSummary& summary = inventory_slot(inventory, slot);
        summary.field_seen = true;
        summary.item_guid = static_cast<std::uint64_t>(low) | (static_cast<std::uint64_t>(high) << 32);
        summary.populated = summary.item_guid != 0;
        touched = true;
    }

    if (touched)
    {
        inventory.seen = true;
        ensure_inventory_slots(inventory);
        update_populated_count(inventory);
    }
}

struct ParsedMovementUpdate
{
    std::uint16_t update_flags = 0;
    std::uint32_t movement_flags = 0;
    std::uint16_t movement_flags2 = 0;
    bool has_position = false;
    float x = 0;
    float y = 0;
    float z = 0;
    float orientation = 0;
};

ParsedMovementUpdate parse_movement_update(std::span<const std::uint8_t> body, std::size_t& offset)
{
    constexpr std::uint16_t UPDATEFLAG_TRANSPORT = 0x0002;
    constexpr std::uint16_t UPDATEFLAG_HAS_TARGET = 0x0004;
    constexpr std::uint16_t UPDATEFLAG_UNKNOWN = 0x0008;
    constexpr std::uint16_t UPDATEFLAG_LOWGUID = 0x0010;
    constexpr std::uint16_t UPDATEFLAG_LIVING = 0x0020;
    constexpr std::uint16_t UPDATEFLAG_STATIONARY_POSITION = 0x0040;
    constexpr std::uint16_t UPDATEFLAG_VEHICLE = 0x0080;
    constexpr std::uint16_t UPDATEFLAG_POSITION = 0x0100;
    constexpr std::uint16_t UPDATEFLAG_ROTATION = 0x0200;

    constexpr std::uint32_t MOVEMENTFLAG_ONTRANSPORT = 0x00000200;
    constexpr std::uint32_t MOVEMENTFLAG_FALLING = 0x00001000;
    constexpr std::uint32_t MOVEMENTFLAG_SWIMMING = 0x00200000;
    constexpr std::uint32_t MOVEMENTFLAG_FLYING = 0x02000000;
    constexpr std::uint32_t MOVEMENTFLAG_SPLINE_ELEVATION = 0x04000000;
    constexpr std::uint32_t MOVEMENTFLAG_SPLINE_ENABLED = 0x08000000;
    constexpr std::uint16_t MOVEMENTFLAG2_ALWAYS_ALLOW_PITCHING = 0x0020;
    constexpr std::uint16_t MOVEMENTFLAG2_INTERPOLATED_MOVEMENT = 0x0400;
    constexpr std::uint32_t SPLINEFLAG_FINAL_POINT = 0x00008000;
    constexpr std::uint32_t SPLINEFLAG_FINAL_TARGET = 0x00010000;
    constexpr std::uint32_t SPLINEFLAG_FINAL_ANGLE = 0x00020000;

    ParsedMovementUpdate movement;
    movement.update_flags = read_u16_le(body, offset);

    if ((movement.update_flags & UPDATEFLAG_LIVING) != 0)
    {
        movement.movement_flags = read_u32_le(body, offset);
        movement.movement_flags2 = read_u16_le(body, offset);
        skip_bytes(body, offset, 4); // server movement time
        movement.x = read_float_le(body, offset);
        movement.y = read_float_le(body, offset);
        movement.z = read_float_le(body, offset);
        movement.orientation = read_float_le(body, offset);
        movement.has_position = true;

        if ((movement.movement_flags & MOVEMENTFLAG_ONTRANSPORT) != 0)
        {
            (void)read_packed_guid(body, offset);
            skip_bytes(body, offset, 4 * 4 + 4 + 1);
            if ((movement.movement_flags2 & MOVEMENTFLAG2_INTERPOLATED_MOVEMENT) != 0)
            {
                skip_bytes(body, offset, 4);
            }
        }

        if ((movement.movement_flags & (MOVEMENTFLAG_SWIMMING | MOVEMENTFLAG_FLYING)) != 0
            || (movement.movement_flags2 & MOVEMENTFLAG2_ALWAYS_ALLOW_PITCHING) != 0)
        {
            skip_bytes(body, offset, 4);
        }

        skip_bytes(body, offset, 4); // fall time
        if ((movement.movement_flags & MOVEMENTFLAG_FALLING) != 0)
        {
            skip_bytes(body, offset, 4 * 4);
        }
        if ((movement.movement_flags & MOVEMENTFLAG_SPLINE_ELEVATION) != 0)
        {
            skip_bytes(body, offset, 4);
        }

        skip_bytes(body, offset, 9 * 4); // movement speeds
        if ((movement.movement_flags & MOVEMENTFLAG_SPLINE_ENABLED) != 0)
        {
            std::uint32_t const spline_flags = read_u32_le(body, offset);
            if ((spline_flags & SPLINEFLAG_FINAL_ANGLE) != 0)
            {
                skip_bytes(body, offset, 4);
            }
            else if ((spline_flags & SPLINEFLAG_FINAL_TARGET) != 0)
            {
                skip_bytes(body, offset, 8);
            }
            else if ((spline_flags & SPLINEFLAG_FINAL_POINT) != 0)
            {
                skip_bytes(body, offset, 3 * 4);
            }

            skip_bytes(body, offset, 4 + 4 + 4); // time passed, duration, spline id
            skip_bytes(body, offset, 4 + 4 + 4 + 4); // duration mods, vertical acceleration, effect start time
            std::uint32_t const nodes = read_u32_le(body, offset);
            skip_bytes(body, offset, static_cast<std::size_t>(nodes) * 3 * 4);
            skip_bytes(body, offset, 1 + 3 * 4); // mode and final destination
        }
    }
    else if ((movement.update_flags & UPDATEFLAG_POSITION) != 0)
    {
        (void)read_packed_guid(body, offset);
        movement.x = read_float_le(body, offset);
        movement.y = read_float_le(body, offset);
        movement.z = read_float_le(body, offset);
        skip_bytes(body, offset, 3 * 4);
        movement.orientation = read_float_le(body, offset);
        skip_bytes(body, offset, 4);
        movement.has_position = true;
    }
    else if ((movement.update_flags & UPDATEFLAG_STATIONARY_POSITION) != 0)
    {
        movement.x = read_float_le(body, offset);
        movement.y = read_float_le(body, offset);
        movement.z = read_float_le(body, offset);
        movement.orientation = read_float_le(body, offset);
        movement.has_position = true;
    }

    if ((movement.update_flags & UPDATEFLAG_UNKNOWN) != 0)
    {
        skip_bytes(body, offset, 4);
    }
    if ((movement.update_flags & UPDATEFLAG_LOWGUID) != 0)
    {
        skip_bytes(body, offset, 4);
    }
    if ((movement.update_flags & UPDATEFLAG_HAS_TARGET) != 0)
    {
        (void)read_packed_guid(body, offset);
    }
    if ((movement.update_flags & UPDATEFLAG_TRANSPORT) != 0)
    {
        skip_bytes(body, offset, 4);
    }
    if ((movement.update_flags & UPDATEFLAG_VEHICLE) != 0)
    {
        skip_bytes(body, offset, 8);
    }
    if ((movement.update_flags & UPDATEFLAG_ROTATION) != 0)
    {
        skip_bytes(body, offset, 8);
    }

    return movement;
}

VisibleObjectSummary make_visible_object(
    std::uint8_t update_type,
    std::uint64_t guid,
    std::uint8_t object_type,
    ParsedMovementUpdate const& movement,
    std::vector<UpdateFieldValue> const& values)
{
    VisibleObjectSummary object;
    object.guid = guid;
    object.high_guid = high_guid(guid);
    object.entry = guid_entry(guid);
    object.counter = guid_counter(guid);
    object.update_type = update_type;
    object.object_type = object_type;
    object.update_flags = movement.update_flags;
    object.movement_flags = movement.movement_flags;
    object.movement_flags2 = movement.movement_flags2;
    object.has_position = movement.has_position;
    object.x = movement.x;
    object.y = movement.y;
    object.z = movement.z;
    object.orientation = movement.orientation;
    object.health_seen = update_value_at(values, UnitFieldHealth, object.health);
    object.max_health_seen = update_value_at(values, UnitFieldMaxHealth, object.max_health);
    object.unit_flags_seen = update_value_at(values, UnitFieldFlags, object.unit_flags);
    object.dynamic_flags_seen = update_value_at(values, UnitDynamicFlags, object.dynamic_flags);
    return object;
}
}

std::vector<std::uint8_t> build_empty_addon_info()
{
    std::vector<std::uint8_t> plain;
    append_u32_le(plain, 0); // addon count
    append_u32_le(plain, 0); // current time

    uLongf compressed_size = compressBound(plain.size());
    std::vector<std::uint8_t> compressed(compressed_size);
    int const result = compress2(compressed.data(), &compressed_size, plain.data(), plain.size(), Z_BEST_SPEED);
    if (result != Z_OK)
    {
        throw std::runtime_error("addon info compression failed");
    }
    compressed.resize(compressed_size);

    std::vector<std::uint8_t> packet;
    append_u32_le(packet, static_cast<std::uint32_t>(plain.size()));
    packet.insert(packet.end(), compressed.begin(), compressed.end());
    return packet;
}

std::vector<std::uint8_t> build_auth_session_payload(
    std::string const& account,
    srp6::SessionKey const& session_key,
    std::array<std::uint8_t, 4> const& server_seed,
    std::array<std::uint8_t, 4> const& local_challenge,
    std::uint32_t realm_id,
    std::span<const std::uint8_t> addon_info)
{
    static constexpr std::array<std::uint8_t, 4> zeros{0, 0, 0, 0};
    auto digest = sha1({
        std::span<const std::uint8_t>(reinterpret_cast<std::uint8_t const*>(account.data()), account.size()),
        zeros,
        local_challenge,
        server_seed,
        session_key,
    });

    std::vector<std::uint8_t> payload;
    append_u32_le(payload, 12340);
    append_u32_le(payload, 0);
    payload.insert(payload.end(), account.begin(), account.end());
    append_u8(payload, 0);
    append_u32_le(payload, 0);
    payload.insert(payload.end(), local_challenge.begin(), local_challenge.end());
    append_u32_le(payload, 0);
    append_u32_le(payload, 0);
    append_u32_le(payload, realm_id);
    append_u64_le(payload, 0);
    payload.insert(payload.end(), digest.begin(), digest.end());
    payload.insert(payload.end(), addon_info.begin(), addon_info.end());
    return payload;
}

std::vector<std::uint8_t> build_character_create_payload(std::string const& name)
{
    if (name.empty() || name.size() > 12)
    {
        throw std::runtime_error("character name must be 1 to 12 bytes");
    }

    std::vector<std::uint8_t> payload;
    payload.insert(payload.end(), name.begin(), name.end());
    append_u8(payload, 0);
    append_u8(payload, 1); // human
    append_u8(payload, 1); // warrior
    append_u8(payload, 0); // male
    append_u8(payload, 0); // skin
    append_u8(payload, 0); // face
    append_u8(payload, 0); // hair style
    append_u8(payload, 0); // hair color
    append_u8(payload, 0); // facial hair
    append_u8(payload, 0); // outfit id; AzerothCore ignores this on create.
    return payload;
}

std::vector<std::uint8_t> build_player_login_payload(std::uint64_t character_guid)
{
    std::vector<std::uint8_t> payload;
    append_u64_le(payload, character_guid);
    return payload;
}

std::vector<std::uint8_t> build_raw_guid_payload(std::uint64_t raw_guid)
{
    std::vector<std::uint8_t> payload;
    append_u64_le(payload, raw_guid);
    return payload;
}

std::vector<std::uint8_t> build_trainer_buy_spell_payload(std::uint64_t trainer_guid, std::uint32_t spell_id)
{
    std::vector<std::uint8_t> payload;
    append_u64_le(payload, trainer_guid);
    append_u32_le(payload, spell_id);
    return payload;
}

std::vector<std::uint8_t> build_loot_payload(std::uint64_t raw_guid)
{
    return build_raw_guid_payload(raw_guid);
}

std::vector<std::uint8_t> build_loot_release_payload(std::uint64_t raw_guid)
{
    return build_raw_guid_payload(raw_guid);
}

std::vector<std::uint8_t> build_autostore_loot_item_payload(std::uint8_t loot_slot)
{
    std::vector<std::uint8_t> payload;
    append_u8(payload, loot_slot);
    return payload;
}

std::vector<std::uint8_t> build_item_query_single_payload(std::uint32_t item_entry)
{
    std::vector<std::uint8_t> payload;
    append_u32_le(payload, item_entry);
    return payload;
}

std::vector<std::uint8_t> build_time_sync_response_payload(std::uint32_t counter, std::uint32_t client_time)
{
    std::vector<std::uint8_t> payload;
    append_u32_le(payload, counter);
    append_u32_le(payload, client_time);
    return payload;
}

std::vector<std::uint8_t> build_movement_payload(std::uint64_t character_guid, MovementSample const& movement)
{
    std::vector<std::uint8_t> payload;
    append_packed_guid(payload, character_guid);
    append_u32_le(payload, movement.flags);
    payload.push_back(static_cast<std::uint8_t>(movement.flags2 & 0xFF));
    payload.push_back(static_cast<std::uint8_t>((movement.flags2 >> 8) & 0xFF));
    append_u32_le(payload, movement.time);
    append_float_le(payload, movement.x);
    append_float_le(payload, movement.y);
    append_float_le(payload, movement.z);
    append_float_le(payload, movement.orientation);
    append_u32_le(payload, movement.fall_time);
    return payload;
}

std::vector<std::uint8_t> build_chat_say_payload(std::uint32_t language, std::string const& message)
{
    std::vector<std::uint8_t> payload;
    append_u32_le(payload, CHAT_MSG_SAY);
    append_u32_le(payload, language);
    payload.insert(payload.end(), message.begin(), message.end());
    append_u8(payload, 0);
    return payload;
}

std::vector<std::uint8_t> build_chat_whisper_payload(
    std::uint32_t language,
    std::string const& target_name,
    std::string const& message)
{
    std::vector<std::uint8_t> payload;
    append_u32_le(payload, CHAT_MSG_WHISPER);
    append_u32_le(payload, language);
    payload.insert(payload.end(), target_name.begin(), target_name.end());
    append_u8(payload, 0);
    payload.insert(payload.end(), message.begin(), message.end());
    append_u8(payload, 0);
    return payload;
}

std::vector<std::uint8_t> build_cast_spell_payload(
    std::uint8_t cast_count,
    std::uint32_t spell_id,
    std::uint8_t cast_flags,
    std::uint32_t target_mask)
{
    std::vector<std::uint8_t> payload;
    append_u8(payload, cast_count);
    append_u32_le(payload, spell_id);
    append_u8(payload, cast_flags);
    append_u32_le(payload, target_mask);
    return payload;
}

std::vector<std::uint8_t> build_cast_spell_unit_payload(
    std::uint8_t cast_count,
    std::uint32_t spell_id,
    std::uint8_t cast_flags,
    std::uint64_t target_guid)
{
    constexpr std::uint32_t TARGET_FLAG_UNIT = 0x00000002;
    std::vector<std::uint8_t> payload = build_cast_spell_payload(cast_count, spell_id, cast_flags, TARGET_FLAG_UNIT);
    append_packed_guid(payload, target_guid);
    return payload;
}

std::vector<std::uint8_t> build_set_action_button_payload(
    std::uint8_t button,
    std::uint32_t action,
    std::uint8_t type)
{
    std::vector<std::uint8_t> payload;
    append_u8(payload, button);
    append_u32_le(payload, (action & 0x00FFFFFFu) | (static_cast<std::uint32_t>(type) << 24));
    return payload;
}

std::vector<std::uint8_t> build_swap_inventory_item_payload(
    std::uint8_t source_slot,
    std::uint8_t destination_slot)
{
    std::vector<std::uint8_t> payload;
    append_u8(payload, destination_slot);
    append_u8(payload, source_slot);
    return payload;
}

std::vector<std::uint8_t> build_split_item_payload(
    std::uint8_t source_bag,
    std::uint8_t source_slot,
    std::uint8_t destination_bag,
    std::uint8_t destination_slot,
    std::uint32_t count)
{
    std::vector<std::uint8_t> payload;
    append_u8(payload, source_bag);
    append_u8(payload, source_slot);
    append_u8(payload, destination_bag);
    append_u8(payload, destination_slot);
    append_u32_le(payload, count);
    return payload;
}

std::vector<std::uint8_t> build_client_packet(std::uint32_t opcode, std::span<const std::uint8_t> payload)
{
    std::vector<std::uint8_t> packet = build_client_header(opcode, payload.size());
    packet.insert(packet.end(), payload.begin(), payload.end());
    return packet;
}

std::vector<CharacterSummary> parse_char_enum(std::span<const std::uint8_t> payload)
{
    std::size_t offset = 0;
    std::uint8_t const count = read_u8(payload, offset);
    std::vector<CharacterSummary> characters;
    characters.reserve(count);

    for (std::uint8_t i = 0; i < count; ++i)
    {
        CharacterSummary character;
        character.guid = read_u64_le(payload, offset);
        character.name = read_c_string(payload, offset);
        character.race = read_u8(payload, offset);
        character.character_class = read_u8(payload, offset);
        character.gender = read_u8(payload, offset);
        skip_bytes(payload, offset, 5); // skin, face, hair style, hair color, facial hair
        character.level = read_u8(payload, offset);
        character.zone = read_u32_le(payload, offset);
        character.map = read_u32_le(payload, offset);
        character.x = read_float_le(payload, offset);
        character.y = read_float_le(payload, offset);
        character.z = read_float_le(payload, offset);
        skip_bytes(payload, offset, 4);  // guild id
        skip_bytes(payload, offset, 4);  // character flags
        skip_bytes(payload, offset, 4);  // customize flags
        skip_bytes(payload, offset, 1);  // first login
        skip_bytes(payload, offset, 12); // pet display, level, family

        std::size_t const equipment_bytes = CharEnumEquipmentSlots * (4 + 1 + 4);
        if (offset + equipment_bytes > payload.size())
        {
            throw std::runtime_error("character enum equipment block is incomplete");
        }
        offset += equipment_bytes;

        characters.push_back(std::move(character));
    }

    if (offset != payload.size())
    {
        throw std::runtime_error("character enum parser left trailing bytes");
    }
    return characters;
}

LoginVerifyWorld parse_login_verify_world(std::span<const std::uint8_t> payload)
{
    if (payload.size() != 20)
    {
        throw std::runtime_error("SMSG_LOGIN_VERIFY_WORLD payload must be 20 bytes");
    }

    std::size_t offset = 0;
    LoginVerifyWorld position;
    position.map = read_u32_le(payload, offset);
    position.x = read_float_le(payload, offset);
    position.y = read_float_le(payload, offset);
    position.z = read_float_le(payload, offset);
    position.orientation = read_float_le(payload, offset);
    return position;
}

std::uint32_t parse_time_sync_counter(std::span<const std::uint8_t> payload)
{
    std::size_t offset = 0;
    return read_u32_le(payload, offset);
}

ChatMessageSummary parse_chat_message_summary(std::span<const std::uint8_t> payload, bool gm_message)
{
    std::size_t offset = 0;
    ChatMessageSummary summary;
    summary.chat_type = read_u8(payload, offset);
    summary.language = read_u32_le(payload, offset);
    summary.sender_guid = read_u64_le(payload, offset);
    (void)read_u32_le(payload, offset); // chat flags

    if (gm_message)
    {
        summary.sender_name = read_length_string(payload, offset);
    }

    if (summary.chat_type == 0x11)
    {
        (void)read_c_string(payload, offset); // channel name
    }

    summary.receiver_guid = read_u64_le(payload, offset);
    summary.message = read_length_string(payload, offset);
    summary.chat_tag = read_u8(payload, offset);
    summary.parsed = true;
    return summary;
}

InitialSpellsSummary parse_initial_spells_summary(std::span<const std::uint8_t> payload)
{
    std::size_t offset = 0;
    InitialSpellsSummary summary;
    summary.seen = true;
    summary.spellbook_flags = read_u8(payload, offset);
    std::uint16_t const spell_count = read_u16_le(payload, offset);
    summary.spells.reserve(spell_count);
    for (std::uint16_t i = 0; i < spell_count; ++i)
    {
        InitialSpellSummary spell;
        spell.spell_id = read_u32_le(payload, offset);
        spell.slot = read_u16_le(payload, offset);
        summary.spells.push_back(spell);
    }

    std::uint16_t const advertised_cooldown_count = read_u16_le(payload, offset);
    summary.cooldown_count = 0;
    for (std::uint16_t i = 0; i < advertised_cooldown_count && offset < payload.size(); ++i)
    {
        if (offset + 16 > payload.size())
        {
            break;
        }
        skip_bytes(payload, offset, 4 + 2 + 2 + 4 + 4);
        ++summary.cooldown_count;
    }
    if (offset != payload.size())
    {
        throw std::runtime_error("initial spells parser left trailing bytes");
    }
    return summary;
}

ActionButtonsSummary parse_action_buttons_summary(std::span<const std::uint8_t> payload)
{
    std::size_t offset = 0;
    ActionButtonsSummary summary;
    summary.seen = true;
    summary.state = read_u8(payload, offset);
    summary.buttons.reserve(MaxActionButtons);

    std::size_t const expected_size = 1 + (MaxActionButtons * 4);
    if (summary.state != 2 && payload.size() != expected_size)
    {
        throw std::runtime_error("action buttons payload has unexpected size");
    }
    if (summary.state == 2 && payload.size() != 1 && payload.size() != expected_size)
    {
        throw std::runtime_error("action buttons clear payload has unexpected size");
    }

    for (std::size_t button = 0; button < MaxActionButtons && offset < payload.size(); ++button)
    {
        std::uint32_t const packed = read_u32_le(payload, offset);
        ActionButtonSummary action_button;
        action_button.button = static_cast<std::uint8_t>(button);
        action_button.packed = packed;
        action_button.action = packed & 0x00FFFFFFu;
        action_button.type = static_cast<std::uint8_t>((packed & 0xFF000000u) >> 24);
        action_button.populated = packed != 0;
        if (action_button.populated)
        {
            ++summary.populated_count;
        }
        summary.buttons.push_back(action_button);
    }
    return summary;
}

ItemTemplateSummary parse_item_query_single_response(std::span<const std::uint8_t> payload)
{
    std::size_t offset = 0;
    ItemTemplateSummary summary;
    summary.entry = read_u32_le(payload, offset);
    if ((summary.entry & 0x80000000u) != 0)
    {
        return summary;
    }

    summary.item_class = read_u32_le(payload, offset);
    summary.subclass = read_u32_le(payload, offset);
    (void)read_u32_le(payload, offset); // sound override subclass
    summary.name = read_c_string(payload, offset);
    (void)read_c_string(payload, offset);
    (void)read_c_string(payload, offset);
    (void)read_c_string(payload, offset);
    summary.display_id = read_u32_le(payload, offset);
    summary.quality = read_u32_le(payload, offset);
    (void)read_u32_le(payload, offset); // flags
    (void)read_u32_le(payload, offset); // flags2
    (void)read_u32_le(payload, offset); // buy price
    (void)read_u32_le(payload, offset); // sell price
    summary.inventory_type = read_u32_le(payload, offset);
    (void)read_u32_le(payload, offset); // allowable class
    (void)read_u32_le(payload, offset); // allowable race
    summary.item_level = read_u32_le(payload, offset);
    summary.required_level = read_u32_le(payload, offset);
    summary.parsed = true;
    return summary;
}

AttackerStateUpdateSummary parse_attacker_state_update(std::span<const std::uint8_t> payload)
{
    constexpr std::uint32_t HITINFO_UNK1 = 0x00000001;
    constexpr std::uint32_t HITINFO_FULL_ABSORB = 0x00000020;
    constexpr std::uint32_t HITINFO_PARTIAL_ABSORB = 0x00000040;
    constexpr std::uint32_t HITINFO_FULL_RESIST = 0x00000080;
    constexpr std::uint32_t HITINFO_PARTIAL_RESIST = 0x00000100;
    constexpr std::uint32_t HITINFO_BLOCK = 0x00002000;
    constexpr std::uint32_t HITINFO_RAGE_GAIN = 0x00800000;

    std::size_t offset = 0;
    AttackerStateUpdateSummary summary;
    summary.payload_size = payload.size();
    summary.hit_info = read_u32_le(payload, offset);
    summary.attacker_guid = read_packed_guid(payload, offset);
    summary.target_guid = read_packed_guid(payload, offset);
    summary.total_damage = read_u32_le(payload, offset);
    summary.overkill = read_u32_le(payload, offset);
    summary.sub_damage_count = read_u8(payload, offset);
    if (summary.sub_damage_count == 0 || summary.sub_damage_count > 2)
    {
        throw std::runtime_error("attacker state update has unsupported sub-damage count");
    }

    summary.sub_damages.reserve(summary.sub_damage_count);
    for (std::uint8_t i = 0; i < summary.sub_damage_count; ++i)
    {
        AttackSubDamageSummary sub_damage;
        sub_damage.school_mask = read_u32_le(payload, offset);
        sub_damage.float_damage = read_float_le(payload, offset);
        sub_damage.damage = read_u32_le(payload, offset);
        summary.sub_damages.push_back(sub_damage);
    }

    summary.has_absorb = (summary.hit_info & (HITINFO_FULL_ABSORB | HITINFO_PARTIAL_ABSORB)) != 0;
    if (summary.has_absorb)
    {
        for (AttackSubDamageSummary& sub_damage : summary.sub_damages)
        {
            sub_damage.absorb = read_u32_le(payload, offset);
        }
    }

    summary.has_resist = (summary.hit_info & (HITINFO_FULL_RESIST | HITINFO_PARTIAL_RESIST)) != 0;
    if (summary.has_resist)
    {
        for (AttackSubDamageSummary& sub_damage : summary.sub_damages)
        {
            sub_damage.resist = read_u32_le(payload, offset);
        }
    }

    summary.target_state = read_u8(payload, offset);
    summary.attacker_state = read_u32_le(payload, offset);
    summary.melee_spell_id = read_u32_le(payload, offset);

    summary.has_blocked_amount = (summary.hit_info & HITINFO_BLOCK) != 0;
    if (summary.has_blocked_amount)
    {
        summary.blocked_amount = read_u32_le(payload, offset);
    }

    summary.has_rage_gain = (summary.hit_info & HITINFO_RAGE_GAIN) != 0;
    if (summary.has_rage_gain)
    {
        skip_bytes(payload, offset, 4);
    }

    summary.has_debug_fields = (summary.hit_info & HITINFO_UNK1) != 0;
    if (summary.has_debug_fields)
    {
        skip_bytes(payload, offset, 4 + 10 * 4 + 4);
    }

    if (offset != payload.size())
    {
        throw std::runtime_error("attacker state update parser left trailing bytes");
    }
    summary.parsed = true;
    return summary;
}

SpellCastResponseSummary parse_spell_cast_response(std::uint16_t opcode, std::span<const std::uint8_t> payload)
{
    std::size_t offset = 0;
    SpellCastResponseSummary summary;
    summary.opcode = opcode;

    if (opcode == SMSG_CAST_FAILED)
    {
        summary.cast_count = read_u8(payload, offset);
        summary.spell_id = read_u32_le(payload, offset);
        summary.fail_reason = read_u8(payload, offset);
        summary.cast_failed = true;
        summary.parsed = true;
        return summary;
    }

    if (opcode == SMSG_SPELL_FAILURE || opcode == SMSG_SPELL_FAILED_OTHER)
    {
        summary.caster_guid = read_packed_guid(payload, offset);
        summary.cast_count = read_u8(payload, offset);
        summary.spell_id = read_u32_le(payload, offset);
        summary.fail_reason = read_u8(payload, offset);
        summary.spell_failure = true;
        summary.parsed = true;
        return summary;
    }

    if (opcode == SMSG_SPELL_START || opcode == SMSG_SPELL_GO)
    {
        summary.source_guid = read_packed_guid(payload, offset);
        summary.caster_guid = read_packed_guid(payload, offset);
        summary.cast_count = read_u8(payload, offset);
        summary.spell_id = read_u32_le(payload, offset);
        summary.cast_flags = read_u32_le(payload, offset);
        summary.spell_start = opcode == SMSG_SPELL_START;
        summary.spell_go = opcode == SMSG_SPELL_GO;
        summary.parsed = true;
        return summary;
    }

    throw std::runtime_error("unsupported spell cast response opcode");
}

LootResponseSummary parse_loot_response(std::span<const std::uint8_t> payload)
{
    std::size_t offset = 0;
    LootResponseSummary summary;
    summary.payload_size = payload.size();
    summary.guid = read_u64_le(payload, offset);
    summary.loot_type = read_u8(payload, offset);

    if (summary.loot_type == 0)
    {
        summary.error_code = read_u8(payload, offset);
        if (offset != payload.size())
        {
            throw std::runtime_error("loot error response parser left trailing bytes");
        }
        summary.error = true;
        summary.parsed = true;
        return summary;
    }

    summary.gold = read_u32_le(payload, offset);
    summary.item_count = read_u8(payload, offset);
    summary.items.reserve(summary.item_count);
    for (std::uint8_t i = 0; i < summary.item_count; ++i)
    {
        LootItemSummary item;
        item.slot = read_u8(payload, offset);
        item.item_id = read_u32_le(payload, offset);
        item.count = read_u32_le(payload, offset);
        item.display_id = read_u32_le(payload, offset);
        item.random_suffix = read_u32_le(payload, offset);
        item.random_property_id = read_u32_le(payload, offset);
        item.slot_type = read_u8(payload, offset);
        summary.items.push_back(item);
    }

    if (offset != payload.size())
    {
        throw std::runtime_error("loot response parser left trailing bytes");
    }
    summary.parsed = true;
    return summary;
}

TrainerListSummary parse_trainer_list_response(std::span<const std::uint8_t> payload)
{
    std::size_t offset = 0;
    TrainerListSummary summary;
    summary.payload_size = payload.size();
    summary.trainer_guid = read_u64_le(payload, offset);
    summary.trainer_type = static_cast<std::int32_t>(read_u32_le(payload, offset));
    summary.spell_count = static_cast<std::int32_t>(read_u32_le(payload, offset));
    if (summary.spell_count < 0)
    {
        throw std::runtime_error("trainer list contains a negative spell count");
    }
    summary.spells.reserve(static_cast<std::size_t>(summary.spell_count));

    for (std::int32_t i = 0; i < summary.spell_count; ++i)
    {
        TrainerSpellSummary spell;
        spell.spell_id = static_cast<std::int32_t>(read_u32_le(payload, offset));
        spell.usable = read_u8(payload, offset);
        spell.money_cost = static_cast<std::int32_t>(read_u32_le(payload, offset));
        spell.point_cost[0] = static_cast<std::int32_t>(read_u32_le(payload, offset));
        spell.point_cost[1] = static_cast<std::int32_t>(read_u32_le(payload, offset));
        spell.req_level = read_u8(payload, offset);
        spell.req_skill_line = static_cast<std::int32_t>(read_u32_le(payload, offset));
        spell.req_skill_rank = static_cast<std::int32_t>(read_u32_le(payload, offset));
        spell.req_ability[0] = static_cast<std::int32_t>(read_u32_le(payload, offset));
        spell.req_ability[1] = static_cast<std::int32_t>(read_u32_le(payload, offset));
        spell.req_ability[2] = static_cast<std::int32_t>(read_u32_le(payload, offset));
        summary.spells.push_back(spell);
    }

    if (offset < payload.size())
    {
        summary.greeting = read_c_string(payload, offset);
    }
    if (offset != payload.size())
    {
        throw std::runtime_error("trainer list parser left trailing bytes");
    }
    summary.parsed = true;
    return summary;
}

TrainerBuyResponseSummary parse_trainer_buy_succeeded_response(std::span<const std::uint8_t> payload)
{
    std::size_t offset = 0;
    TrainerBuyResponseSummary summary;
    summary.payload_size = payload.size();
    summary.trainer_guid = read_u64_le(payload, offset);
    summary.spell_id = static_cast<std::int32_t>(read_u32_le(payload, offset));
    if (offset != payload.size())
    {
        throw std::runtime_error("trainer buy success parser left trailing bytes");
    }
    summary.succeeded = true;
    summary.parsed = true;
    return summary;
}

TrainerBuyResponseSummary parse_trainer_buy_failed_response(std::span<const std::uint8_t> payload)
{
    std::size_t offset = 0;
    TrainerBuyResponseSummary summary;
    summary.payload_size = payload.size();
    summary.trainer_guid = read_u64_le(payload, offset);
    summary.spell_id = static_cast<std::int32_t>(read_u32_le(payload, offset));
    summary.failure_reason = static_cast<std::int32_t>(read_u32_le(payload, offset));
    if (offset != payload.size())
    {
        throw std::runtime_error("trainer buy failure parser left trailing bytes");
    }
    summary.failed = true;
    summary.parsed = true;
    return summary;
}

UpdateObjectSummary parse_update_object_summary(
    std::span<const std::uint8_t> payload,
    bool compressed,
    std::uint64_t player_guid)
{
    UpdateObjectSummary summary;
    summary.seen = true;
    summary.compressed = compressed;
    summary.payload_size = payload.size();

    std::vector<std::uint8_t> inflated;
    std::span<const std::uint8_t> body = payload;
    if (compressed)
    {
        inflated = inflate_update_payload(payload, summary.uncompressed_size);
        body = inflated;
    }

    std::size_t offset = 0;
    summary.block_count = read_u32_le(body, offset);
    if (summary.block_count == 0 || offset >= body.size())
    {
        summary.visible_parse_complete = true;
        return summary;
    }

    try
    {
        for (std::uint32_t block = 0; block < summary.block_count && offset < body.size(); ++block)
        {
            std::uint8_t const update_type = read_u8(body, offset);
            if (block == 0)
            {
                summary.first_update_type = update_type;
            }

            if (update_type == 4)
            {
                std::uint32_t const out_of_range_count = read_u32_le(body, offset);
                for (std::uint32_t i = 0; i < out_of_range_count; ++i)
                {
                    (void)read_packed_guid(body, offset);
                }
                continue;
            }

            std::uint64_t const guid = read_packed_guid(body, offset);
            if (summary.first_guid == 0)
            {
                summary.first_guid = guid;
            }
            if (guid == player_guid)
            {
                summary.contains_player_guid = true;
            }

            if (update_type == 0)
            {
                std::vector<UpdateFieldValue> values = read_values_update(body, offset);
                if (high_guid_is_item(high_guid(guid)))
                {
                    summary.inventory_items.push_back(parse_inventory_item_object(guid, 0, values));
                }
                if (guid == player_guid)
                {
                    apply_player_inventory_values(summary.inventory, guid, values);
                }
                if (high_guid_has_entry(high_guid(guid)) && !high_guid_is_item(high_guid(guid)))
                {
                    summary.visible_objects.push_back(make_visible_object(update_type, guid, 0, {}, values));
                }
                continue;
            }

            if (update_type == 1)
            {
                (void)parse_movement_update(body, offset);
                continue;
            }

            if (update_type == 2 || update_type == 3)
            {
                std::uint8_t const object_type = read_u8(body, offset);
                ParsedMovementUpdate movement = parse_movement_update(body, offset);
                std::vector<UpdateFieldValue> values = read_values_update(body, offset);
                bool const item_object = object_type == 1 || object_type == 2 || high_guid_is_item(high_guid(guid));
                if (item_object)
                {
                    summary.inventory_items.push_back(parse_inventory_item_object(guid, object_type, values));
                }
                if (guid == player_guid)
                {
                    apply_player_inventory_values(summary.inventory, guid, values);
                }
                if (!item_object)
                {
                    summary.visible_objects.push_back(make_visible_object(update_type, guid, object_type, movement, values));
                }
                continue;
            }
        }
        summary.visible_parse_complete = offset <= body.size();
    }
    catch (std::exception const& exc)
    {
        summary.visible_parse_complete = false;
        summary.visible_parse_error = exc.what();
    }
    return summary;
}

bool world_packet_self_test()
{
    srp6::SessionKey session_key{};
    std::array<std::uint8_t, 4> server_seed{1, 2, 3, 4};
    std::array<std::uint8_t, 4> local_challenge{5, 6, 7, 8};
    auto addon_info = build_empty_addon_info();
    auto auth_payload = build_auth_session_payload("TEST", session_key, server_seed, local_challenge, 1, addon_info);
    auto auth_packet = build_client_packet(CMSG_AUTH_SESSION, auth_payload);
    if (auth_packet.size() != auth_payload.size() + 6)
    {
        return false;
    }
    if (auth_packet[2] != 0xED || auth_packet[3] != 0x01)
    {
        return false;
    }

    auto char_enum_packet = build_client_packet(CMSG_CHAR_ENUM, {});
    if (hex(char_enum_packet) != "000437000000")
    {
        return false;
    }

    auto login_packet = build_client_packet(CMSG_PLAYER_LOGIN, build_player_login_payload(0x1234));
    if (login_packet.size() != 14 || login_packet[2] != 0x3D)
    {
        return false;
    }

    MovementSample movement;
    movement.x = -8949.95f;
    movement.y = -132.493f;
    movement.z = 83.5312f;
    auto movement_packet = build_client_packet(MSG_MOVE_HEARTBEAT, build_movement_payload(0x1234, movement));
    if (movement_packet.size() != 6 + 1 + 2 + 4 + 2 + 4 + 16 + 4 || movement_packet[2] != 0xEE)
    {
        return false;
    }

    auto time_sync_payload = build_time_sync_response_payload(7, 123456);
    auto time_sync_packet = build_client_packet(CMSG_TIME_SYNC_RESP, time_sync_payload);
    if (parse_time_sync_counter(time_sync_payload) != 7
        || time_sync_payload.size() != 8
        || time_sync_packet.size() != 14
        || time_sync_packet[2] != 0x91
        || time_sync_packet[3] != 0x03)
    {
        return false;
    }

    auto chat_payload = build_chat_say_payload(LANG_COMMON, "hello");
    auto chat_packet = build_client_packet(CMSG_MESSAGECHAT, chat_payload);
    if (chat_packet.size() != 6 + 4 + 4 + 6 || chat_packet[2] != 0x95)
    {
        return false;
    }

    auto whisper_payload = build_chat_whisper_payload(LANG_COMMON, "SafeTest", "secret");
    auto whisper_packet = build_client_packet(CMSG_MESSAGECHAT, whisper_payload);
    if (whisper_packet.size() != 6 + 4 + 4 + 9 + 7 || whisper_packet[2] != 0x95)
    {
        return false;
    }

    auto cast_payload = build_cast_spell_payload(1, 2457, 0, 0);
    auto cast_packet = build_client_packet(CMSG_CAST_SPELL, cast_payload);
    if (cast_packet.size() != 6 + 1 + 4 + 1 + 4 || cast_packet[2] != 0x2E || cast_packet[3] != 0x01)
    {
        return false;
    }
    auto targeted_cast_payload = build_cast_spell_unit_payload(2, 78, 0, 0xF1300002D1000CEFULL);
    auto targeted_cast_packet = build_client_packet(CMSG_CAST_SPELL, targeted_cast_payload);
    if (targeted_cast_packet.size() <= cast_packet.size() || targeted_cast_packet[2] != 0x2E || targeted_cast_packet[3] != 0x01)
    {
        return false;
    }
    auto set_action_payload = build_set_action_button_payload(0, 78, 0);
    auto set_action_packet = build_client_packet(CMSG_SET_ACTION_BUTTON, set_action_payload);
    if (set_action_packet.size() != 6 + 1 + 4
        || set_action_packet[2] != 0x28
        || set_action_packet[3] != 0x01
        || set_action_packet[6] != 0
        || set_action_packet[7] != 78)
    {
        return false;
    }
    auto item_query_payload = build_item_query_single_payload(38);
    auto item_query_packet = build_client_packet(CMSG_ITEM_QUERY_SINGLE, item_query_payload);
    if (item_query_packet.size() != 10 || item_query_packet[2] != 0x56)
    {
        return false;
    }
    auto swap_inventory_payload = build_swap_inventory_item_payload(23, 25);
    auto swap_inventory_packet = build_client_packet(CMSG_SWAP_INV_ITEM, swap_inventory_payload);
    if (swap_inventory_packet.size() != 8
        || swap_inventory_packet[2] != 0x0D
        || swap_inventory_packet[3] != 0x01
        || swap_inventory_packet[6] != 25
        || swap_inventory_packet[7] != 23)
    {
        return false;
    }
    auto split_item_payload = build_split_item_payload(255, 23, 255, 25, 1);
    auto split_item_packet = build_client_packet(CMSG_SPLIT_ITEM, split_item_payload);
    if (split_item_packet.size() != 14
        || split_item_packet[2] != 0x0E
        || split_item_packet[3] != 0x01
        || split_item_packet[6] != 255
        || split_item_packet[7] != 23
        || split_item_packet[8] != 255
        || split_item_packet[9] != 25
        || split_item_packet[10] != 1
        || split_item_packet[11] != 0
        || split_item_packet[12] != 0
        || split_item_packet[13] != 0)
    {
        return false;
    }
    auto loot_payload = build_loot_payload(0xF130000026000001ULL);
    auto loot_packet = build_client_packet(CMSG_LOOT, loot_payload);
    if (loot_packet.size() != 14
        || loot_packet[2] != 0x5D
        || loot_packet[3] != 0x01
        || loot_payload.size() != 8)
    {
        return false;
    }
    auto loot_release_payload = build_loot_release_payload(0xF130000026000001ULL);
    auto loot_release_packet = build_client_packet(CMSG_LOOT_RELEASE, loot_release_payload);
    if (loot_release_packet.size() != 14
        || loot_release_packet[2] != 0x5F
        || loot_release_packet[3] != 0x01)
    {
        return false;
    }
    auto loot_item_payload = build_autostore_loot_item_payload(3);
    auto loot_item_packet = build_client_packet(CMSG_AUTOSTORE_LOOT_ITEM, loot_item_payload);
    if (loot_item_packet.size() != 7
        || loot_item_packet[2] != 0x08
        || loot_item_packet[3] != 0x01
        || loot_item_packet[6] != 3)
    {
        return false;
    }
    auto trainer_buy_payload = build_trainer_buy_spell_payload(0xF13000038F000001ULL, 6673);
    auto trainer_buy_packet = build_client_packet(CMSG_TRAINER_BUY_SPELL, trainer_buy_payload);
    if (trainer_buy_packet.size() != 18
        || trainer_buy_packet[2] != 0xB2
        || trainer_buy_packet[3] != 0x01
        || trainer_buy_payload.size() != 12)
    {
        return false;
    }

    auto create_payload = build_character_create_payload("Codextest");
    if (create_payload.empty() || create_payload.back() != 0)
    {
        return false;
    }

    std::vector<std::uint8_t> login_verify;
    append_u32_le(login_verify, 0);
    append_float_le(login_verify, -8949.95f);
    append_float_le(login_verify, -132.493f);
    append_float_le(login_verify, 83.5312f);
    append_float_le(login_verify, 0.1f);
    auto verify = parse_login_verify_world(login_verify);
    if (verify.map != 0 || verify.z < 83.0f)
    {
        return false;
    }

    std::vector<std::uint8_t> char_payload;
    append_u8(char_payload, 1);
    append_synthetic_character(char_payload);
    auto characters = parse_char_enum(char_payload);
    bool rejected_truncation = false;
    try
    {
        std::vector<std::uint8_t> truncated{1, 0x34, 0x12};
        (void)parse_char_enum(truncated);
    }
    catch (std::exception const&)
    {
        rejected_truncation = true;
    }

    std::vector<std::uint8_t> update_payload;
    constexpr std::uint64_t synthetic_item_guid = 0x40000000001F4538ULL;
    append_u32_le(update_payload, 2);
    append_u8(update_payload, 2); // create object
    append_packed_guid(update_payload, 0xF13000033700000BULL);
    append_u8(update_payload, 3); // unit object type
    append_u16_le(update_payload, 0x0060); // living and stationary flags
    append_u32_le(update_payload, 0); // movement flags
    append_u16_le(update_payload, 0); // movement flags 2
    append_u32_le(update_payload, 123);
    append_float_le(update_payload, -8946.3f);
    append_float_le(update_payload, -132.4f);
    append_float_le(update_payload, 83.5f);
    append_float_le(update_payload, 0.1f);
    append_u32_le(update_payload, 0); // fall time
    for (int i = 0; i < 9; ++i)
    {
        append_float_le(update_payload, 1.0f);
    }
    append_u8(update_payload, 37); // value update mask blocks through coinage
    std::vector<std::uint32_t> update_masks(37, 0);
    update_masks[PlayerFieldInvSlotHead / 32] |= 1u << (PlayerFieldInvSlotHead % 32);
    update_masks[(PlayerFieldInvSlotHead + 1) / 32] |= 1u << ((PlayerFieldInvSlotHead + 1) % 32);
    update_masks[PlayerFieldCoinage / 32] |= 1u << (PlayerFieldCoinage % 32);
    for (std::uint32_t mask : update_masks)
    {
        append_u32_le(update_payload, mask);
    }
    append_u32_le(update_payload, static_cast<std::uint32_t>(synthetic_item_guid & 0xFFFFFFFFu));
    append_u32_le(update_payload, static_cast<std::uint32_t>(synthetic_item_guid >> 32));
    append_u32_le(update_payload, 42);
    append_u8(update_payload, 2); // create item object
    append_packed_guid(update_payload, synthetic_item_guid);
    append_u8(update_payload, 1); // item object type
    append_u16_le(update_payload, 0); // no movement update fields
    append_u8(update_payload, 2); // value update mask blocks
    append_u32_le(update_payload, (1u << ObjectFieldEntry) | (1u << ItemFieldStackCount));
    append_u32_le(update_payload, (1u << (ItemFieldDurability - 32)) | (1u << (ItemFieldMaxDurability - 32)));
    append_u32_le(update_payload, 38);
    append_u32_le(update_payload, 1);
    append_u32_le(update_payload, 17);
    append_u32_le(update_payload, 42);
    auto update = parse_update_object_summary(update_payload, false, 0xF13000033700000BULL);

    std::vector<std::uint8_t> chat_response;
    append_u8(chat_response, CHAT_MSG_SAY);
    append_u32_le(chat_response, LANG_COMMON);
    append_u64_le(chat_response, 0x1234);
    append_u32_le(chat_response, 0);
    append_u64_le(chat_response, 0x1234);
    append_u32_le(chat_response, 6);
    chat_response.insert(chat_response.end(), {'h', 'e', 'l', 'l', 'o', 0});
    append_u8(chat_response, 0);
    ChatMessageSummary chat = parse_chat_message_summary(chat_response, false);

    std::vector<std::uint8_t> whisper_response;
    append_u8(whisper_response, CHAT_MSG_WHISPER);
    append_u32_le(whisper_response, LANG_UNIVERSAL);
    append_u64_le(whisper_response, 0x1234);
    append_u32_le(whisper_response, 0);
    append_u64_le(whisper_response, 0x1234);
    append_u32_le(whisper_response, 7);
    whisper_response.insert(whisper_response.end(), {'s', 'e', 'c', 'r', 'e', 't', 0});
    append_u8(whisper_response, 0);
    ChatMessageSummary whisper = parse_chat_message_summary(whisper_response, false);

    std::vector<std::uint8_t> initial_spells_payload;
    append_u8(initial_spells_payload, 0);
    append_u16_le(initial_spells_payload, 2);
    append_u32_le(initial_spells_payload, 78);
    append_u16_le(initial_spells_payload, 0);
    append_u32_le(initial_spells_payload, 6603);
    append_u16_le(initial_spells_payload, 0);
    append_u16_le(initial_spells_payload, 0);
    InitialSpellsSummary spellbook = parse_initial_spells_summary(initial_spells_payload);

    std::vector<std::uint8_t> action_buttons_payload;
    append_u8(action_buttons_payload, 1);
    for (std::size_t button = 0; button < MaxActionButtons; ++button)
    {
        std::uint32_t packed = 0;
        if (button == 0)
        {
            packed = 78;
        }
        if (button == 1)
        {
            packed = 6948 | (0x80u << 24);
        }
        append_u32_le(action_buttons_payload, packed);
    }
    ActionButtonsSummary action_buttons = parse_action_buttons_summary(action_buttons_payload);

    std::vector<std::uint8_t> item_template_payload;
    append_u32_le(item_template_payload, 38);
    append_u32_le(item_template_payload, 2);
    append_u32_le(item_template_payload, 7);
    append_u32_le(item_template_payload, 0);
    item_template_payload.insert(item_template_payload.end(), {'R', 'e', 'c', 'r', 'u', 'i', 't', '\'', 's', ' ', 'S', 'h', 'i', 'r', 't', 0});
    append_u8(item_template_payload, 0);
    append_u8(item_template_payload, 0);
    append_u8(item_template_payload, 0);
    append_u32_le(item_template_payload, 123);
    append_u32_le(item_template_payload, 1);
    append_u32_le(item_template_payload, 0);
    append_u32_le(item_template_payload, 0);
    append_u32_le(item_template_payload, 10);
    append_u32_le(item_template_payload, 1);
    append_u32_le(item_template_payload, 4);
    append_u32_le(item_template_payload, 0xFFFFFFFFu);
    append_u32_le(item_template_payload, 0xFFFFFFFFu);
    append_u32_le(item_template_payload, 1);
    append_u32_le(item_template_payload, 1);
    ItemTemplateSummary item_template = parse_item_query_single_response(item_template_payload);

    std::vector<std::uint8_t> attacker_state_payload;
    append_u32_le(attacker_state_payload, 0x00000002); // affects victim
    append_packed_guid(attacker_state_payload, 0x1234);
    append_packed_guid(attacker_state_payload, 0xF1300002D1000CEFULL);
    append_u32_le(attacker_state_payload, 12);
    append_u32_le(attacker_state_payload, 0);
    append_u8(attacker_state_payload, 1);
    append_u32_le(attacker_state_payload, 1);
    append_float_le(attacker_state_payload, 12.0f);
    append_u32_le(attacker_state_payload, 12);
    append_u8(attacker_state_payload, 0);
    append_u32_le(attacker_state_payload, 0);
    append_u32_le(attacker_state_payload, 0);
    AttackerStateUpdateSummary attacker_state = parse_attacker_state_update(attacker_state_payload);

    std::vector<std::uint8_t> spell_go_payload;
    append_packed_guid(spell_go_payload, 0x1234);
    append_packed_guid(spell_go_payload, 0x1234);
    append_u8(spell_go_payload, 1);
    append_u32_le(spell_go_payload, 2457);
    append_u32_le(spell_go_payload, 0x200);
    SpellCastResponseSummary spell_go = parse_spell_cast_response(SMSG_SPELL_GO, spell_go_payload);

    std::vector<std::uint8_t> cast_failed_payload;
    append_u8(cast_failed_payload, 1);
    append_u32_le(cast_failed_payload, 78);
    append_u8(cast_failed_payload, 2);
    SpellCastResponseSummary cast_failed = parse_spell_cast_response(SMSG_CAST_FAILED, cast_failed_payload);

    std::vector<std::uint8_t> loot_error_payload;
    append_u64_le(loot_error_payload, 0xF130000026000001ULL);
    append_u8(loot_error_payload, 0);
    append_u8(loot_error_payload, 4);
    LootResponseSummary loot_error = parse_loot_response(loot_error_payload);

    std::vector<std::uint8_t> loot_response_payload;
    append_u64_le(loot_response_payload, 0xF130000026000001ULL);
    append_u8(loot_response_payload, 1);
    append_u32_le(loot_response_payload, 1234);
    append_u8(loot_response_payload, 1);
    append_u8(loot_response_payload, 0);
    append_u32_le(loot_response_payload, 25);
    append_u32_le(loot_response_payload, 2);
    append_u32_le(loot_response_payload, 777);
    append_u32_le(loot_response_payload, 0);
    append_u32_le(loot_response_payload, 0);
    append_u8(loot_response_payload, 0);
    LootResponseSummary loot_response = parse_loot_response(loot_response_payload);

    std::vector<std::uint8_t> trainer_list_payload;
    append_u64_le(trainer_list_payload, 0xF13000038F000001ULL);
    append_u32_le(trainer_list_payload, 0);
    append_u32_le(trainer_list_payload, 1);
    append_u32_le(trainer_list_payload, 78);
    append_u8(trainer_list_payload, 0);
    append_u32_le(trainer_list_payload, 100);
    append_u32_le(trainer_list_payload, 0);
    append_u32_le(trainer_list_payload, 0);
    append_u8(trainer_list_payload, 1);
    append_u32_le(trainer_list_payload, 0);
    append_u32_le(trainer_list_payload, 0);
    append_u32_le(trainer_list_payload, 0);
    append_u32_le(trainer_list_payload, 0);
    append_u32_le(trainer_list_payload, 0);
    trainer_list_payload.insert(trainer_list_payload.end(), {'T', 'r', 'a', 'i', 'n', ' ', 'w', 'e', 'l', 'l', '.', 0});
    TrainerListSummary trainer_list = parse_trainer_list_response(trainer_list_payload);

    std::vector<std::uint8_t> trainer_buy_success_payload;
    append_u64_le(trainer_buy_success_payload, 0xF13000038F000001ULL);
    append_u32_le(trainer_buy_success_payload, 6673);
    TrainerBuyResponseSummary trainer_buy_success = parse_trainer_buy_succeeded_response(trainer_buy_success_payload);

    std::vector<std::uint8_t> trainer_buy_failure_payload;
    append_u64_le(trainer_buy_failure_payload, 0xF13000038F000001ULL);
    append_u32_le(trainer_buy_failure_payload, 6673);
    append_u32_le(trainer_buy_failure_payload, 1);
    TrainerBuyResponseSummary trainer_buy_failure = parse_trainer_buy_failed_response(trainer_buy_failure_payload);

    return rejected_truncation
        && characters.size() == 1
        && characters[0].guid == 0x1234
        && characters[0].name == "SafeTest"
        && characters[0].level == 80
        && characters[0].zone == 12
        && characters[0].map == 0
        && update.visible_parse_complete
        && update.visible_objects.size() == 1
        && update.visible_objects[0].guid == 0xF13000033700000BULL
        && update.visible_objects[0].entry == 823
        && update.visible_objects[0].object_type == 3
        && update.visible_objects[0].has_position
        && update.visible_objects[0].x < -8946.0f
        && update.inventory.seen
        && update.inventory.player_guid == 0xF13000033700000BULL
        && update.inventory.coinage_seen
        && update.inventory.coinage == 42
        && update.inventory.slots.size() == PlayerInventorySnapshotSlots
        && update.inventory.slots[0].populated
        && update.inventory.slots[0].item_guid == synthetic_item_guid
        && update.inventory_items.size() == 1
        && update.inventory_items[0].guid == synthetic_item_guid
        && update.inventory_items[0].entry == 38
        && update.inventory_items[0].stack_count == 1
        && update.inventory_items[0].durability == 17
        && update.inventory_items[0].max_durability == 42
        && chat.parsed
        && chat.chat_type == CHAT_MSG_SAY
        && chat.language == LANG_COMMON
        && chat.sender_guid == 0x1234
        && chat.receiver_guid == 0x1234
        && chat.message == "hello"
        && whisper.parsed
        && whisper.chat_type == CHAT_MSG_WHISPER
        && whisper.language == LANG_UNIVERSAL
        && whisper.message == "secret"
        && spellbook.seen
        && spellbook.spells.size() == 2
        && spellbook.spells[0].spell_id == 78
        && spellbook.spells[1].spell_id == 6603
        && spellbook.cooldown_count == 0
        && action_buttons.seen
        && action_buttons.state == 1
        && action_buttons.buttons.size() == MaxActionButtons
        && action_buttons.populated_count == 2
        && action_buttons.buttons[0].action == 78
        && action_buttons.buttons[0].type == 0
        && action_buttons.buttons[1].action == 6948
        && action_buttons.buttons[1].type == 0x80
        && item_template.parsed
        && item_template.entry == 38
        && item_template.name == "Recruit's Shirt"
        && item_template.quality == 1
        && item_template.inventory_type == 4
        && item_template.item_level == 1
        && attacker_state.parsed
        && attacker_state.hit_info == 0x00000002
        && attacker_state.attacker_guid == 0x1234
        && attacker_state.target_guid == 0xF1300002D1000CEFULL
        && attacker_state.total_damage == 12
        && attacker_state.sub_damages.size() == 1
        && attacker_state.sub_damages[0].school_mask == 1
        && attacker_state.sub_damages[0].damage == 12
        && spell_go.parsed
        && spell_go.spell_go
        && spell_go.spell_id == 2457
        && spell_go.cast_count == 1
        && spell_go.caster_guid == 0x1234
        && cast_failed.parsed
        && cast_failed.cast_failed
        && cast_failed.spell_id == 78
        && cast_failed.fail_reason == 2
        && loot_error.parsed
        && loot_error.error
        && loot_error.guid == 0xF130000026000001ULL
        && loot_error.error_code == 4
        && loot_response.parsed
        && !loot_response.error
        && loot_response.guid == 0xF130000026000001ULL
        && loot_response.loot_type == 1
        && loot_response.gold == 1234
        && loot_response.item_count == 1
        && loot_response.items.size() == 1
        && loot_response.items[0].slot == 0
        && loot_response.items[0].item_id == 25
        && loot_response.items[0].count == 2
        && trainer_list.parsed
        && trainer_list.trainer_guid == 0xF13000038F000001ULL
        && trainer_list.spell_count == 1
        && trainer_list.spells.size() == 1
        && trainer_list.spells[0].spell_id == 78
        && trainer_list.spells[0].money_cost == 100
        && trainer_list.spells[0].req_level == 1
        && trainer_list.greeting == "Train well."
        && trainer_buy_success.parsed
        && trainer_buy_success.succeeded
        && !trainer_buy_success.failed
        && trainer_buy_success.trainer_guid == 0xF13000038F000001ULL
        && trainer_buy_success.spell_id == 6673
        && trainer_buy_failure.parsed
        && trainer_buy_failure.failed
        && !trainer_buy_failure.succeeded
        && trainer_buy_failure.trainer_guid == 0xF13000038F000001ULL
        && trainer_buy_failure.spell_id == 6673
        && trainer_buy_failure.failure_reason == 1
        && loot_response.items[0].display_id == 777
        && loot_response.items[0].slot_type == 0;
}
