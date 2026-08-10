//
//  Preferences.m
//  MusaicFM
//
//  Created by Dennis Oberhoff on 14/11/2016.
//  Copyright © 2016 Dennis Oberhoff. All rights reserved.
//

@import ScreenSaver;

#import "Preferences.h"

@implementation Preferences

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.rows = 4;
        self.delays = 5;
        self.lastfmUser = @"obrhoff";
        self.lastfmTag = @"HipHop";
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder*)decoder
{
    self = [super init];
    if (self) {
        self.lastfmUser = [decoder decodeObjectForKey:@"lastfmUser"];
        self.rows = [decoder decodeIntegerForKey:@"rows"];
        self.delays = [decoder decodeIntegerForKey:@"delays"];
        self.lastfmWeekly = [decoder decodeIntegerForKey:@"lastfmWeekly"];
        self.lastfmTag = [decoder decodeObjectForKey:@"lastfmTag"];
        self.mode = [decoder decodeIntegerForKey:@"mode"];
        self.artworks = [decoder decodeObjectForKey:@"artworks"];
        self.spotifyCode = [decoder decodeObjectForKey:@"spotifyCode"];
        self.spotifyToken = [decoder decodeObjectForKey:@"spotifyToken"];
        self.spotifyRefresh = [decoder decodeObjectForKey:@"spotifyRefresh"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder*)encoder
{
    [encoder encodeInteger:self.mode forKey:@"mode"];
    [encoder encodeObject:self.artworks forKey:@"artworks"];
    [encoder encodeObject:self.lastfmUser forKey:@"lastfmUser"];
    [encoder encodeObject:self.lastfmTag forKey:@"lastfmTag"];
    [encoder encodeObject:self.spotifyCode forKey:@"spotifyCode"];
    [encoder encodeObject:self.spotifyToken forKey:@"spotifyToken"];
    [encoder encodeObject:self.spotifyRefresh forKey:@"spotifyRefresh"];
    [encoder encodeInteger:self.rows forKey:@"rows"];
    [encoder encodeInteger:self.delays forKey:@"delays"];
    [encoder encodeInteger:self.lastfmWeekly forKey:@"lastfmWeekly"];
}

- (void)clear
{
    self.artworks = nil;
    self.spotifyToken = nil;
    self.spotifyRefresh = nil;
    self.spotifyCode = nil;
}

- (void)mirrorPreferencesIntoLegacyScreenSaverContainer
{
    // MusaicFMPreferences.app writes ScreenSaverDefaults to the user ByHost
    // domain, while legacyScreenSaver reads the sandboxed copy. Mirror after
    // companion-app saves so settings apply without a manual plist copy.
    NSString* home = NSHomeDirectory();
    if ([home containsString:@"/Containers/com.apple.ScreenSaver"]) {
        return;
    }

    NSString* module = @"com.obrhoff.musaicfm.preferences";
    NSString* byHost = [home stringByAppendingPathComponent:@"Library/Preferences/ByHost"];
    NSString* containerByHost = [home stringByAppendingPathComponent:
                                  @"Library/Containers/com.apple.ScreenSaver.Engine.legacyScreenSaver/Data/Library/Preferences/ByHost"];

    NSFileManager* fileManager = NSFileManager.defaultManager;
    BOOL isDirectory = NO;
    if (![fileManager fileExistsAtPath:containerByHost isDirectory:&isDirectory] || !isDirectory) {
        return;
    }

    NSArray<NSString*>* files = [fileManager contentsOfDirectoryAtPath:byHost error:nil];
    for (NSString* file in files) {
        if (![file hasPrefix:module] || ![file hasSuffix:@".plist"]) {
            continue;
        }
        NSString* source = [byHost stringByAppendingPathComponent:file];
        NSString* destination = [containerByHost stringByAppendingPathComponent:file];
        [fileManager removeItemAtPath:destination error:nil];
        [fileManager copyItemAtPath:source toPath:destination error:nil];
    }
}

- (void)synchronize
{
    ScreenSaverDefaults* defaults = [ScreenSaverDefaults defaultsForModuleWithName:@"com.obrhoff.musaicfm.preferences"];
    NSData* stored = [NSKeyedArchiver archivedDataWithRootObject:self];
    [defaults setObject:stored forKey:@"settings"];
    [defaults synchronize];
    [self mirrorPreferencesIntoLegacyScreenSaverContainer];
}

+ (Preferences*)preferences
{

    static Preferences* preferences;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ScreenSaverDefaults* defaults = [ScreenSaverDefaults defaultsForModuleWithName:@"com.obrhoff.musaicfm.preferences"];
        NSData* prefData = [defaults objectForKey:@"settings"];
        if ([prefData isKindOfClass:[NSData class]] && prefData.length) {
            @try {
                preferences = [NSKeyedUnarchiver unarchiveObjectWithData:prefData];
            } @catch (__unused NSException* exception) {
                preferences = nil;
            }
        }
        if (!preferences)
            preferences = [Preferences new];
        if (preferences.rows < 1) {
            preferences.rows = 4;
        }
        if (preferences.delays < 1) {
            preferences.delays = 5;
        }
    });
    return preferences;
}

@end
