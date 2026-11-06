//
//  YouTubeKidsFix
//  YouTube Kids compatibility package
//
//  Google never shipped a backend replacement for the old YouTube Kids app,
//  and the client/server protocol it used is gone. There is therefore no
//  native fix comparable to TubeReplacer for regular YouTube.
//
//  Instead this package hands the app over to YouTube Kids' own web client,
//  rendered in an in-app browser. See WebFallback.m and the WebFallback keys in
//  the configuration plist. Set WebFallback=false to keep the native UI.
//

#import <Foundation/Foundation.h>
#import "LFEngine.h"

#ifdef __cplusplus
extern "C" {
#endif
extern void LFYouTubeKidsInstallFallback(void);
#ifdef __cplusplus
}
#endif

%ctor {
    LFStart(@"com.google.ios.youtubekids");
    LFYouTubeKidsInstallFallback();
}
