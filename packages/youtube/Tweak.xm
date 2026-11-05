//
//  YouTubeFix
//  YouTube compatibility package
//
//  The shared engine does the generic work (update-nag suppression,
//  iOS/User-Agent spoofing, config-driven hooks, diagnostics).
//
//  App-specific fixes go below the constructor, e.g.:
//
//    %hook SomeClass
//    - (BOOL)someGate { return YES; }
//    %end
//
//  See docs/adding-a-fix.md for the workflow.
//

#import <Foundation/Foundation.h>
#import "LFEngine.h"

%ctor {
    LFStart(@"com.google.ios.youtube");
}
