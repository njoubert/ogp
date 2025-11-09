#include <iostream>
#include "src/protocol/protocol.h"

int main(int argc, char* argv[]) {
    std::cout << "OGP Server starting..." << std::endl;
    
    ogp::Protocol protocol;
    std::cout << "Protocol version: " << protocol.GetVersion() << std::endl;
    
    // TODO: Implement server logic
    
    std::cout << "OGP Server ready" << std::endl;
    return 0;
}
