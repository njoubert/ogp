#include <iostream>
#include "src/protocol/protocol.h"

int main(int argc, char* argv[]) {
    std::cout << "OGP Client starting..." << std::endl;
    
    ogp::Protocol protocol;
    std::cout << "Protocol version: " << protocol.GetVersion() << std::endl;
    
    // TODO: Implement client logic
    
    std::cout << "OGP Client ready" << std::endl;
    return 0;
}
