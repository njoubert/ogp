#ifndef OGP_PROTOCOL_H_
#define OGP_PROTOCOL_H_

#include <string>
#include <cstdint>

namespace ogp {

// Protocol version
constexpr uint16_t kProtocolVersion = 1;

// Basic protocol interface
class Protocol {
public:
    Protocol();
    ~Protocol();

    // Get protocol version
    uint16_t GetVersion() const;

    // Serialize a message
    std::string Serialize(const std::string& message);

    // Deserialize a message
    std::string Deserialize(const std::string& data);
};

}  // namespace ogp

#endif  // OGP_PROTOCOL_H_
