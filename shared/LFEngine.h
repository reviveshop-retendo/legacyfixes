//
//  LFEngine.h
//  LegacyFixes shared runtime
//
//  One tiny runtime that every per-app package links against (compiled in,
//  so there is no extra package the user has to install).
//

#ifndef LFENGINE_H
#define LFENGINE_H

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Load the merged configuration for `bundleID`, install the generic
 * compatibility hooks, then install any config-driven method patches.
 *
 * Call this exactly once from your tweak's constructor.
 */
void LFStart(NSString *bundleID);

/** Append a timestamped line to the LegacyFixes log (and NSLog). */
void LFLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);

/** The merged configuration dictionary (nil before LFStart). */
NSDictionary *LFConfig(void);

/** Convenience accessor for a top-level configuration key. */
id LFConfigValue(NSString *key);

/** Absolute path of the log file currently being written. */
NSString *LFLogPath(void);

#ifdef __cplusplus
}
#endif

#endif /* LFENGINE_H */
