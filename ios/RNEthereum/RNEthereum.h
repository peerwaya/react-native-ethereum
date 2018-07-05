
#if __has_include("RCTBridgeModule.h")
#import "RCTBridgeModule.h"
#else
#import <React/RCTBridgeModule.h>
#endif

@interface RNEthereum : NSObject <RCTBridgeModule>
{
    NSString *_nodeUrl;
}
@end
  
