#include "protocol.h"

namespace ogp {

Protocol::Protocol() {}

Protocol::~Protocol() {}

uint16_t Protocol::GetVersion() const {
    return kProtocolVersion;
}

std::string Protocol::Serialize(const std::string& message) {
    // TODO: Implement serialization logic
    return message;
}

std::string Protocol::Deserialize(const std::string& data) {
    // TODO: Implement deserialization logic
    return data;
}

}  // namespace ogp
