// clang -g -O2  -Wall -framework Cocoa -framework Foundation -framework ApplicationServices ./drab.m -o drab
/*
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>color</key>
<array>
    <string>Terminal</string>
</array>
</dict>
</plist>
*/

#include <signal.h>
#include <stdio.h>

#import <ApplicationServices/ApplicationServices.h>
#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

CG_EXTERN bool CGDisplayUsesForceToGray(void);
CG_EXTERN void CGDisplayForceToGray(bool forceToGray);

typedef enum _event_t {
    launching = 0,
    launched,
    terminated,
    hidden,
    unhidden,
    activated,
    deactivated
} event_t;

@interface AppWatcher : NSObject
    - (id) init;
    - (void) dealloc;
    - (void) loadConfig;
    - (void) registerObserver;
    - (void) unregisterObserver;
    @property NSSet *colorApps;
@end

@implementation AppWatcher
- (id) init {
    if ( self = [super init] ) {
        self.colorApps = [[NSSet alloc] init];
        [self loadConfig];
    }
    if (!CGDisplayUsesForceToGray()) {
        CGDisplayForceToGray(true);
    }
    
    return self;
}

- (void) dealloc {
    [self.colorApps release];
    [super dealloc];
}

- (void) loadConfig {
    NSLog(@"DRAB_LOAD_CONFIG");

    NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"drab" ofType:@"plist"]];
    NSArray *colorAppsArray = [dictionary objectForKey:@"color"];
    self.colorApps = [NSSet setWithArray:colorAppsArray];
    
    for (id appName in [self.colorApps allObjects]) {
       NSLog(@"DRAB_COLOR_APP: %@", appName);
    }
}

- (void) callback:(NSDictionary*)userInfo withEvent:(event_t)event {
    if (event == launched || event == activated) {
        NSRunningApplication* app = [userInfo objectForKey:@"NSWorkspaceApplicationKey"];

        if (app == nil) {
            return;
        }

        NSString* appName = [app localizedName];

        if (appName == nil) {
            appName = [userInfo objectForKey:@"NSApplicationName"];
        }

        if ([self.colorApps containsObject: appName]) {
            NSLog(@"COLORY: %@", appName);
            CGDisplayForceToGray(false);
        } else {
            NSLog(@"DRABBY: %@", appName);
            if (!CGDisplayUsesForceToGray()) {
                CGDisplayForceToGray(true);
            }
        }
    }
}

- (void) applicationWillLaunch:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:launching];
}

- (void) applicationLaunched:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:launched];
}

- (void) applicationTerminated:(NSNotification*)notification {
    [self callback:[notification userInfo]  withEvent:terminated];
}

- (void) applicationHidden:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:hidden];
}

- (void) applicationUnhidden:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:unhidden];
}

- (void) applicationActivated:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:activated];
}

- (void) applicationDeactivated:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:deactivated];
}

- (void) registerObserver {
    NSNotificationCenter* center = [[NSWorkspace sharedWorkspace] notificationCenter];

    [center addObserver:self
               selector:@selector(applicationWillLaunch:)
                   name:NSWorkspaceWillLaunchApplicationNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(applicationLaunched:)
                   name:NSWorkspaceDidLaunchApplicationNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(applicationTerminated:)
                   name:NSWorkspaceDidTerminateApplicationNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(applicationHidden:)
                   name:NSWorkspaceDidHideApplicationNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(applicationUnhidden:)
                   name:NSWorkspaceDidUnhideApplicationNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(applicationActivated:)
                   name:NSWorkspaceDidActivateApplicationNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(applicationDeactivated:)
                   name:NSWorkspaceDidDeactivateApplicationNotification
                 object:nil];
}

- (void) unregisterObserver {
    NSNotificationCenter* center = [[NSWorkspace sharedWorkspace] notificationCenter];
    [center removeObserver:self name:NSWorkspaceWillLaunchApplicationNotification object:nil];
    [center removeObserver:self name:NSWorkspaceDidLaunchApplicationNotification object:nil];
    [center removeObserver:self name:NSWorkspaceDidTerminateApplicationNotification object:nil];
    [center removeObserver:self name:NSWorkspaceDidHideApplicationNotification object:nil];
    [center removeObserver:self name:NSWorkspaceDidUnhideApplicationNotification object:nil];
    [center removeObserver:self name:NSWorkspaceDidActivateApplicationNotification object:nil];
    [center removeObserver:self name:NSWorkspaceDidDeactivateApplicationNotification object:nil];
}
@end

AppWatcher *appWatch;

void hup() {
    [appWatch loadConfig];
}

int main(int argc, char** argv) {
    NSLog(@"DRAB");

    appWatch = [[AppWatcher alloc] init];
    
    if (signal(SIGHUP, hup) == SIG_IGN) {
        signal(SIGHUP, SIG_IGN);
    }

    [appWatch registerObserver];

    [[NSRunLoop currentRunLoop] run];
    return 0;
}
