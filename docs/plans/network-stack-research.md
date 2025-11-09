# Network Stack Research for OGP Multi-Path UDP Protocol

**Date**: November 8, 2025  
**Purpose**: Research libraries and approaches for building a multi-path UDP protocol with network simulation capabilities

## Project Goals

1. Open multiple UDP streams between client and server
2. Send packets simultaneously across all streams (multi-path)
3. Easy-to-use socket abstraction classes
4. Protocol layer that splits/reassembles messages across UDP streams
5. Duplicate data across unreliable links for speed and reliability
6. Simulate network conditions (latency, packet loss) for testing

---

## Socket Library Options

### Option 1: Raw POSIX Sockets (BSD Sockets API)

**Pros:**
- No external dependencies
- Available on all Unix-like systems (macOS, Linux)
- Direct control over socket behavior
- Lightweight and well-understood
- Already available through `<sys/socket.h>`, `<netinet/in.h>`, `<arpa/inet.h>`

**Cons:**
- More boilerplate code
- Manual error handling
- Platform-specific quirks (though mostly compatible)
- Need to handle non-blocking I/O manually

**Best for:** Maximum control, minimal dependencies, learning low-level networking

**Example approach:**
```cpp
// Wrapper class for UDP socket
class UdpSocket {
  int sock_fd_;
  sockaddr_in addr_;
public:
  bool Open(uint16_t port);
  ssize_t SendTo(const void* data, size_t len, const sockaddr_in& dest);
  ssize_t RecvFrom(void* buffer, size_t len, sockaddr_in& src);
  void SetNonBlocking();
};
```

### Option 2: Boost.Asio

**Website:** https://www.boost.org/doc/libs/release/doc/html/boost_asio.html

**Pros:**
- Header-only option available (or compiled library)
- Cross-platform (Windows, Linux, macOS)
- Excellent async I/O support with coroutines (C++20)
- Well-tested and widely used
- Provides timers, strand synchronization
- Good UDP multicast support
- Can use `async_send_to()` and `async_receive_from()` for non-blocking operations

**Cons:**
- Large library (though can use just networking parts)
- Steeper learning curve for async patterns
- Overkill for simple synchronous use cases

**Best for:** Production-quality async networking, complex event-driven architectures

**Example approach:**
```cpp
#include <boost/asio.hpp>

class UdpSocket {
  boost::asio::io_context& io_context_;
  boost::asio::ip::udp::socket socket_;
public:
  void AsyncSend(const std::vector<uint8_t>& data, 
                 const boost::asio::ip::udp::endpoint& dest);
  void AsyncReceive(std::function<void(const std::vector<uint8_t>&)> callback);
};
```

### Option 3: libuv

**Website:** https://libuv.org/

**Pros:**
- Event loop based (like Node.js uses)
- Cross-platform
- Good performance
- C API with modern C++ wrappers available
- Widely deployed and tested

**Cons:**
- C API can be verbose
- Event loop model may be overkill
- Not as C++-idiomatic as Boost.Asio

**Best for:** If you want Node.js-style event loop, cross-platform portability

### Option 4: POCO C++ Libraries

**Website:** https://pocoproject.org/

**Pros:**
- Comprehensive network library
- Easy-to-use C++ API
- Includes UDP multicast support
- Good documentation

**Cons:**
- Less commonly used than Boost
- Another dependency to manage
- May have more than needed

**Best for:** Rapid development with batteries-included approach

---

## Recommended Approach for OGP

### **Primary Recommendation: Raw POSIX Sockets with select/epoll**

**Rationale:**
1. **Minimal dependencies** - Aligns with project goal of learning and control
2. **Sufficient for UDP** - UDP is simpler than TCP; doesn't need complex async framework
3. **Clear code path** - Easy to understand exactly what's happening
4. **Bazel-friendly** - No external library integration needed
5. **Educational** - Learn networking fundamentals

**Implementation approach:**
```cpp
// Core abstraction
class UdpEndpoint {
  int socket_fd_;
  sockaddr_in local_addr_;
  bool non_blocking_;
  
public:
  bool Bind(uint16_t port);
  ssize_t SendTo(const uint8_t* data, size_t len, 
                 const std::string& dest_ip, uint16_t dest_port);
  ssize_t ReceiveFrom(uint8_t* buffer, size_t max_len,
                      std::string& src_ip, uint16_t& src_port);
  void SetNonBlocking(bool enabled);
  int GetFileDescriptor() const { return socket_fd_; }
};

// Multi-socket manager using select() or epoll()
class MultiPathManager {
  std::vector<std::unique_ptr<UdpEndpoint>> endpoints_;
  
public:
  void AddEndpoint(std::unique_ptr<UdpEndpoint> endpoint);
  void Poll(int timeout_ms);  // Uses select() or epoll()
  void SendAcrossAll(const std::vector<uint8_t>& data);
};
```

### **Alternative Recommendation: Boost.Asio (if async becomes important)**

If you find you need:
- Sophisticated async I/O patterns
- Built-in timers and schedulers
- Coroutine support (C++20)

Then switch to Boost.Asio. It's well-supported and can be added to Bazel easily.

---

## Network Simulation Options

### Option 1: Linux tc (Traffic Control) + netem

**Platform:** Linux only

**Pros:**
- Built into Linux kernel
- Very realistic simulation
- Can simulate latency, jitter, packet loss, reordering, duplication
- Works at system level (affects all traffic through interface)

**Cons:**
- Linux only (not macOS)
- Requires root/sudo privileges
- Affects entire network interface
- **Cannot target specific sockets directly**

**Per-Socket Workaround:**
You CAN simulate different paths by using network namespaces or binding each socket to a different IP address/interface, then applying tc rules per interface:

```bash
# Create virtual interfaces for testing
sudo ip link add veth0 type veth peer name veth0-peer
sudo ip link add veth1 type veth peer name veth1-peer
sudo ip link add veth2 type veth peer name veth2-peer
sudo ip link add veth3 type veth peer name veth3-peer

# Apply different netem rules to each
sudo tc qdisc add dev veth0 root netem delay 10ms loss 1%    # Good path
sudo tc qdisc add dev veth1 root netem delay 50ms loss 5%    # LTE path
sudo tc qdisc add dev veth2 root netem delay 500ms loss 2%   # Satellite path
sudo tc qdisc add dev veth3 root netem delay 100ms loss 15%  # Poor path

# Bind your 4 UDP sockets to different interfaces
# Socket 1 → veth0
# Socket 2 → veth1
# Socket 3 → veth2
# Socket 4 → veth3
```

**Complexity:** High - requires Linux networking knowledge and setup scripts

**Usage example (simple case, affects all localhost traffic):**
```bash
# Add 100ms latency with 10% packet loss
sudo tc qdisc add dev lo root netem delay 100ms loss 10%

# Remove rules
sudo tc qdisc del dev lo root
```

**Best for:** Linux integration testing, realistic simulation if you can set up virtual interfaces

### Option 2: macOS Network Link Conditioner

**Platform:** macOS only

**Pros:**
- Built into macOS (part of Xcode Additional Tools)
- GUI interface
- Presets for various network conditions (3G, LTE, WiFi, etc.)
- System-wide or per-application

**Cons:**
- macOS only
- GUI-based (not scriptable)
- Coarse-grained control

**Best for:** Manual testing on macOS, quick experimentation

### Option 3: Application-Level Simulation (Roll Your Own) ⭐ RECOMMENDED

**Pros:**
- Cross-platform
- **Fine-grained control per socket** - Each socket can have different conditions
- No special privileges needed
- Can be deterministic for testing
- Integrated into your code
- Easy to simulate 4 different network paths with different characteristics

**Cons:**
- Need to implement yourself
- May not catch OS-level behaviors
- Adds code complexity

**Key Insight for Multi-Path:** Each `SimulatedUdpSocket` gets its own `NetworkSimulator` instance with independent settings. This perfectly models having 4 different physical network interfaces!

**Implementation approach:**
```cpp
// Represents network characteristics for ONE path/interface
struct NetworkConditions {
  float packet_loss_rate = 0.0f;      // 0.0 to 1.0
  std::chrono::milliseconds min_latency{0};
  std::chrono::milliseconds max_latency{0};
  float jitter_factor = 0.0f;          // 0.0 to 1.0
  float duplicate_rate = 0.0f;         // Sometimes packets duplicate
  float reorder_rate = 0.0f;           // Packets arrive out of order
};

// Simulates network behavior for ONE socket/path
class NetworkSimulator {
  NetworkConditions conditions_;
  std::mt19937 rng_;
  
  struct DelayedPacket {
    std::vector<uint8_t> data;
    sockaddr_in dest;
    std::chrono::steady_clock::time_point send_time;
    
    bool operator<(const DelayedPacket& other) const {
      return send_time > other.send_time;  // Min heap
    }
  };
  std::priority_queue<DelayedPacket> delayed_packets_;

public:
  explicit NetworkSimulator(const NetworkConditions& conditions, 
                           uint32_t seed = std::random_device{}())
    : conditions_(conditions), rng_(seed) {}
  
  void SetConditions(const NetworkConditions& conditions) {
    conditions_ = conditions;
  }
  
  // Returns true if packet should be sent (possibly delayed)
  // Returns false if packet was dropped
  bool SimulateSend(const uint8_t* data, size_t len, 
                    const sockaddr_in& dest);
  
  // Process delayed packets and actually send them
  void ProcessDelayedPackets(IUdpSocket* underlying_socket);
  
private:
  std::chrono::milliseconds CalculateDelay();
  bool ShouldDropPacket();
  bool ShouldDuplicatePacket();
};

// Wraps a real UDP socket with simulation
class SimulatedUdpSocket : public IUdpSocket {
  std::unique_ptr<IUdpSocket> underlying_socket_;
  NetworkSimulator simulator_;
  
public:
  SimulatedUdpSocket(std::unique_ptr<IUdpSocket> socket,
                     const NetworkConditions& conditions)
    : underlying_socket_(std::move(socket)),
      simulator_(conditions) {}
  
  ssize_t SendTo(const uint8_t* data, size_t len,
                 const sockaddr_in& dest) override {
    if (simulator_.SimulateSend(data, len, dest)) {
      // Packet accepted (will be sent with delay)
      return len;
    }
    // Packet dropped by simulation
    return len;  // Return success but don't actually send
  }
  
  ssize_t ReceiveFrom(uint8_t* buffer, size_t max_len,
                      sockaddr_in& src) override {
    // First process any delayed outgoing packets
    simulator_.ProcessDelayedPackets(underlying_socket_.get());
    
    // Then receive from real socket
    return underlying_socket_->ReceiveFrom(buffer, max_len, src);
  }
  
  void SetConditions(const NetworkConditions& conditions) {
    simulator_.SetConditions(conditions);
  }
};
```

**Usage example - Simulating 4 different network paths:**
```cpp
// Create 4 UDP sockets, each simulating a different network interface
std::vector<std::unique_ptr<IUdpSocket>> sockets;

// Path 1: Good WiFi (low latency, minimal loss)
NetworkConditions wifi{
  .packet_loss_rate = 0.01f,     // 1% loss
  .min_latency = std::chrono::milliseconds(10),
  .max_latency = std::chrono::milliseconds(30),
  .jitter_factor = 0.2f
};
auto socket1 = std::make_unique<RealUdpSocket>();
socket1->Bind(5001);
sockets.push_back(
  std::make_unique<SimulatedUdpSocket>(std::move(socket1), wifi)
);

// Path 2: Cellular/LTE (higher latency, moderate loss)
NetworkConditions lte{
  .packet_loss_rate = 0.05f,     // 5% loss
  .min_latency = std::chrono::milliseconds(50),
  .max_latency = std::chrono::milliseconds(150),
  .jitter_factor = 0.5f
};
auto socket2 = std::make_unique<RealUdpSocket>();
socket2->Bind(5002);
sockets.push_back(
  std::make_unique<SimulatedUdpSocket>(std::move(socket2), lte)
);

// Path 3: Satellite (very high latency, low bandwidth)
NetworkConditions satellite{
  .packet_loss_rate = 0.02f,     // 2% loss
  .min_latency = std::chrono::milliseconds(500),
  .max_latency = std::chrono::milliseconds(800),
  .jitter_factor = 0.3f
};
auto socket3 = std::make_unique<RealUdpSocket>();
socket3->Bind(5003);
sockets.push_back(
  std::make_unique<SimulatedUdpSocket>(std::move(socket3), satellite)
);

// Path 4: Poor WiFi (high loss, variable latency)
NetworkConditions poor_wifi{
  .packet_loss_rate = 0.15f,     // 15% loss!
  .min_latency = std::chrono::milliseconds(20),
  .max_latency = std::chrono::milliseconds(200),
  .jitter_factor = 0.8f,
  .reorder_rate = 0.05f          // 5% packets reordered
};
auto socket4 = std::make_unique<RealUdpSocket>();
socket4->Bind(5004);
sockets.push_back(
  std::make_unique<SimulatedUdpSocket>(std::move(socket4), poor_wifi)
);

// Now use these sockets in MultiPathManager
// Each path will have completely different behavior!
```

**How it works:**
1. Each `SimulatedUdpSocket` wraps a real UDP socket
2. Each has its own `NetworkSimulator` with independent conditions
3. When you send data through socket 1 (WiFi), it experiences WiFi conditions
4. When you send through socket 3 (Satellite), it experiences satellite latency
5. Your protocol layer doesn't know the difference - it just uses `IUdpSocket` interface
6. All 4 sockets can be on localhost but simulate different physical interfaces

**Benefits:**
- **Realistic multi-path testing** without needing 4 physical interfaces
- **Reproducible tests** with fixed random seeds
- **Dynamic conditions** - can change network quality during runtime
- **Perfect for development** - iterate quickly without real hardware

### Option 4: clumsy (Windows) / comcast (Cross-platform)

**clumsy:** https://jagt.github.io/clumsy/ (Windows GUI)  
**comcast:** https://github.com/tylertreat/comcast (CLI, Go-based)

**Pros:**
- User-space tools
- Can target specific processes/ports
- Scriptable (comcast)

**Cons:**
- External dependencies
- Platform-specific or requires Go runtime
- Less commonly used

### Option 5: Docker/Containers with Network Emulation

**Pros:**
- Isolated testing environments
- Can use tc/netem within container
- Reproducible setups
- Good for CI/CD testing

**Cons:**
- Overhead of containerization
- More complex setup

**Example:**
```dockerfile
# In container, set up network conditions
RUN tc qdisc add dev eth0 root netem delay 50ms loss 5%
```

---

## Recommended Network Simulation Approach

### **Primary Recommendation: Application-Level Simulation**

**Rationale:**
1. **Cross-platform** - Works on macOS and Linux
2. **No special privileges** - No sudo required
3. **Fine-grained control** - Can simulate different conditions per socket
4. **Deterministic testing** - Can use fixed random seeds
5. **Integration-friendly** - Part of your codebase

**Implementation strategy:**
```cpp
// Base interface
class IUdpSocket {
public:
  virtual ~IUdpSocket() = default;
  virtual ssize_t SendTo(const uint8_t* data, size_t len,
                         const sockaddr_in& dest) = 0;
  virtual ssize_t ReceiveFrom(uint8_t* buffer, size_t max_len,
                              sockaddr_in& src) = 0;
};

// Real socket
class RealUdpSocket : public IUdpSocket { ... };

// Simulated socket (wraps real socket)
class SimulatedUdpSocket : public IUdpSocket {
  std::unique_ptr<IUdpSocket> underlying_;
  NetworkSimulator simulator_;
  
public:
  ssize_t SendTo(const uint8_t* data, size_t len,
                 const sockaddr_in& dest) override {
    return simulator_.SimulateSend(underlying_.get(), data, len, dest);
  }
};
```

### **Secondary Recommendation: Linux tc/netem for Integration Testing**

For more realistic end-to-end testing on Linux:
- Use tc/netem in a Docker container
- Create scripts to set up/tear down network conditions
- Run integration tests in this environment

---

## Architecture Sketch

```
┌─────────────────────────────────────────────────────────┐
│                    Application Layer                     │
│  (Your protocol logic: message splitting/reassembly)    │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│                 MultiPathProtocol                        │
│  - Message framing and sequencing                       │
│  - FEC (Forward Error Correction) optional              │
│  - Duplication strategy                                 │
│  - Reassembly logic                                     │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│              MultiPathManager                            │
│  - Manages N UDP sockets                                │
│  - Distributes packets across sockets                   │
│  - Receives from all sockets                            │
│  - Uses select/epoll for multiplexing                   │
└────────────────────┬────────────────────────────────────┘
                     │
          ┌──────────┼──────────┐
          │          │          │
┌─────────▼───┐ ┌───▼──────┐ ┌─▼──────────┐
│ UdpSocket 1 │ │ UdpSocket│ │ UdpSocket N│
│  (simulated)│ │     2    │ │  (simulated)│
└─────────────┘ └──────────┘ └────────────┘
```

---

## Additional Considerations

### Thread Safety
- Each UDP socket could be managed by its own thread
- Or use single-threaded event loop with select/epoll
- Recommendation: Start single-threaded, add threads if needed

### Testing Strategy
1. **Unit tests**: Test socket wrapper classes with mocked behavior
2. **Simulation tests**: Use application-level simulation for protocol logic
3. **Integration tests**: Client/server on localhost with simulation
4. **Real network tests**: Use tc/netem on Linux or Network Link Conditioner on macOS

### Performance Monitoring
- Track per-socket statistics (packets sent/received, bytes, errors)
- Monitor reassembly buffer usage
- Measure end-to-end latency

### Protocol Considerations for Multi-Path
- Sequence numbers (per-socket or global?)
- Acknowledgments and retransmission strategy
- Path quality measurement (RTT, loss rate per path)
- Load balancing across paths
- Congestion control (if needed)

---

## Next Steps

1. **Implement basic UdpSocket wrapper** with POSIX sockets
2. **Create NetworkSimulator class** for application-level simulation
3. **Build MultiPathManager** to handle multiple sockets with select()
4. **Design message framing protocol** (sequence numbers, packet format)
5. **Implement MultiPathProtocol** for splitting/reassembly
6. **Write tests** with various simulated network conditions

---

## References

- **POSIX Sockets**: `man socket`, `man sendto`, `man recvfrom`, `man select`
- **Boost.Asio**: https://www.boost.org/doc/libs/release/doc/html/boost_asio.html
- **Linux tc/netem**: https://wiki.linuxfoundation.org/networking/netem
- **QUIC Protocol**: https://www.rfc-editor.org/rfc/rfc9000.html (multi-path inspiration)
- **MPTCP**: https://www.rfc-editor.org/rfc/rfc8684.html (multi-path TCP)
- **Beej's Guide to Network Programming**: https://beej.us/guide/bgnet/

---

## Decision Summary

| Aspect | Recommendation | Alternative |
|--------|----------------|-------------|
| Socket Library | Raw POSIX sockets | Boost.Asio (if async needed) |
| Network Simulation | Application-level | Linux tc/netem for integration |
| Threading Model | Single-threaded + select() | Multi-threaded (later) |
| Testing | Unit + simulated integration | Real network (secondary) |
| Platform Support | macOS, Linux | (both covered) |
