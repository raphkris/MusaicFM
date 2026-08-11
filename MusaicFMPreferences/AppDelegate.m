//
//  AppDelegate.m
//  MusaicFMPreferences
//
//  Created by Dennis Oberhoff on 14/11/2016.
//  Copyright © 2016 Dennis Oberhoff. All rights reserved.
//

#import "AppDelegate.h"
#import "PreferencesViewController.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow* window;
@property (nonatomic, readwrite, strong) PreferencesViewController* preferences;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification*)aNotification
{
    self.preferences = [PreferencesViewController new];
    [self.preferences loadWindow];

    NSWindow* preferencesWindow = self.preferences.window;
    preferencesWindow.styleMask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable;
    preferencesWindow.title = @"MusaicFM";
    [preferencesWindow center];
    [preferencesWindow makeKeyAndOrderFront:self];

    // Hide the empty placeholder window from MainMenu.xib.
    [self.window close];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender
{
    return YES;
}

- (void)applicationWillTerminate:(NSNotification*)aNotification
{
}

@end
