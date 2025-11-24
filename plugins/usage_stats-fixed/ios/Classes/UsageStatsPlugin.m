#import "UsageStatsPlugin.h"
#if __has_include(<usage_stats/usage_stats-Swift.h>)
#import <usage_stats/usage_stats-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "usage_stats-Swift.h"
#endif

@implementation UsageStatsPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftUsageStatsPlugin registerWithRegistrar:registrar];
}
@end
