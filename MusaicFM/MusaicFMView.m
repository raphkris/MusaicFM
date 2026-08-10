//
//  MusaicFMView.m
//  MusaicFM
//
//  Created by Dennis Oberhoff on 13/11/2016.
//  Copyright © 2016 Dennis Oberhoff. All rights reserved.
//

@import QuartzCore;
#import <ApplicationServices/ApplicationServices.h>
#import <SDWebImage/SDWebImage.h>

#import "MusaicFMView.h"
#import "MusaicItem.h"
#import "Manager.h"
#import "NSMutableArray+Shuffle.h"
#import "Artwork.h"
#import "PreferencesViewController.h"
#import "Preferences.h"

@interface MusaicFMView () <NSCollectionViewDataSource>

@property (nonatomic, readwrite, strong) NSArray* currentItems;
@property (nonatomic, readwrite, strong) NSArray* totalItems;
@property (nonatomic, readwrite, strong) NSTimer* timer;
@property (nonatomic, readwrite, assign) NSInteger lastCellIndex;

@property (nonatomic, readwrite, strong) Manager* manager;
@property (nonatomic, readwrite, strong) NSCollectionView* collectionView;
@property (nonatomic, readwrite, strong) NSCollectionViewFlowLayout* collectionViewLayout;
@property (nonatomic, readwrite, strong) PreferencesViewController* prefencesViewController;

@property (nonatomic, readwrite, assign) BOOL didCommonInit;
@property (nonatomic, readwrite, assign) BOOL installedLifecycleObservers;

@end

@implementation MusaicFMView

+ (BOOL)isTahoeOrNewer
{
    NSOperatingSystemVersion version = NSProcessInfo.processInfo.operatingSystemVersion;
    return version.majorVersion >= 26;
}

+ (BOOL)isScreenLocked
{
    CFDictionaryRef dict = CGSessionCopyCurrentDictionary();
    if (!dict) {
        return NO;
    }

    BOOL locked = NO;
    const void* value = CFDictionaryGetValue(dict, CFSTR("CGSSessionScreenIsLocked"));
    if (value) {
        locked = CFBooleanGetValue(value);
    }
    CFRelease(dict);
    return locked;
}

- (BOOL)isGhostInstanceFrame:(NSRect)frame
{
    return NSWidth(frame) < 1.0 || NSHeight(frame) < 1.0;
}

// On Tahoe, System Settings preview often reports isPreview=NO. Only treat the
// locked-screen session as a real screensaver for process-killing workarounds.
- (BOOL)shouldInstallLifecycleWorkarounds
{
    if ([[self class] isTahoeOrNewer]) {
        return [[self class] isScreenLocked];
    }
    return !self.isPreview;
}

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        // macOS Tahoe spawns a zero-frame "ghost" instance while opening Screen
        // Saver settings. Keep it inert so layout math cannot hang the appex
        // and hide the Options button.
        if (![self isGhostInstanceFrame:frame]) {
            [self commonInitInstallingLifecycleObservers:YES];
        }
    }
    return self;
}

- (void)dealloc
{
    [self.timer invalidate];
    if (self.installedLifecycleObservers) {
        [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
        [NSDistributedNotificationCenter.defaultCenter removeObserver:self];
    }
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    // Configure-sheet / companion-app embed: never install exit(0) observers.
    [self commonInitInstallingLifecycleObservers:NO];
}

- (void)commonInitInstallingLifecycleObservers:(BOOL)installLifecycleObservers
{
    if (self.didCommonInit) {
        return;
    }
    self.didCommonInit = YES;

    self.wantsLayer = YES;
    self.animationTimeInterval = 60;
    self.manager = [Manager new];

    [self configureCollectionView];
    [self prepareLayout];
    [self fetchData];

    if (installLifecycleObservers && [self shouldInstallLifecycleWorkarounds]) {
        [NSWorkspace.sharedWorkspace.notificationCenter
         addObserver:self
         selector:@selector(onSleepNote:)
         name:NSWorkspaceWillSleepNotification
         object:nil];

        [NSDistributedNotificationCenter.defaultCenter
         addObserver:self
         selector:@selector(willStop:)
         name:@"com.apple.screensaver.willstop"
         object:nil];
        self.installedLifecycleObservers = YES;
    }
}

- (void)configureCollectionView
{
    self.collectionViewLayout = [NSCollectionViewFlowLayout new];
    self.collectionViewLayout.minimumInteritemSpacing = 0.0;
    self.collectionViewLayout.minimumLineSpacing = 0.0;

    self.collectionView = [[NSCollectionView alloc] initWithFrame:NSZeroRect];
    self.collectionView.collectionViewLayout = self.collectionViewLayout;
    [self.collectionView registerClass:[MusaicItem class] forItemWithIdentifier:NSStringFromClass([MusaicItem class])];

    self.collectionView.wantsLayer = YES;
    self.collectionView.dataSource = self;
    self.collectionView.backgroundColors = @[ [NSColor colorWithRed:0.11 green:0.11 blue:0.13 alpha:1.00] ];

    [self addSubview:self.collectionView];
}

- (void)prepareLayout
{
    if (!self.collectionView || !self.collectionViewLayout) {
        return;
    }

    NSInteger rows = MAX(1, [Preferences preferences].rows);
    CGFloat height = CGRectGetHeight(self.bounds);
    CGFloat width = CGRectGetWidth(self.bounds);
    if (height < 1.0 || width < 1.0) {
        return;
    }

    CGFloat size = height / (CGFloat)rows;
    if (size < 1.0) {
        return;
    }

    // Set itemSize before calculateFrameRect so we never loop on a zero stride.
    self.collectionViewLayout.itemSize = CGSizeMake(size, size);

    NSRect calculatedBounds = [self calculateFrameRect:self.bounds];
    CGFloat offsetY = (calculatedBounds.size.height - self.bounds.size.height) / 2;
    CGFloat offsetX = (calculatedBounds.size.width - self.bounds.size.width) / 2;

    self.collectionView.frame = NSOffsetRect(calculatedBounds, -offsetX, -offsetY);

    [self prepareData:self.totalItems];
}

- (void)prepareData:(NSArray*)items
{
    NSPredicate* removePredicate = [NSPredicate predicateWithFormat:@"artworkUrl.absoluteString.length > 0"];
    NSArray* newItems = [items filteredArrayUsingPredicate:removePredicate];

    if (newItems.count == 0) {
        return;
    }

    NSInteger maximalCount = [self maximalCount];
    if (maximalCount <= 0) {
        return;
    }

    NSMutableArray* artworks = [NSMutableArray arrayWithCapacity:(NSUInteger)maximalCount];

    while (artworks.count < maximalCount) {
        [artworks addObjectsFromArray:newItems];
    }

    NSMutableArray* shuffled = artworks.mutableCopy;
    [shuffled shuffle];
    [shuffled trim:maximalCount];

    self.totalItems = newItems;
    self.currentItems = shuffled.copy;
    [self.collectionView reloadData];
}

- (void)fetchData
{
    __weak typeof(self) weakSelf = self;

    void (^done)(NSArray* artworks) = ^void(NSArray* new) {
        [weakSelf prepareData:new];
    };

    void (^failure)(NSError* error) = ^void(NSError* error) {
        Preferences* preferences = [Preferences preferences];
        if (preferences.artworks.count)
            done(preferences.artworks);
    };

    switch ([Preferences preferences].mode) {
    case PreferencesModeLastFmUser:
        [self.manager performLastfmWeekly:done andFailure:failure];
        break;

    case PreferencesModeTag:
        [self.manager performLastfmTag:done andFailure:failure];
        break;

    case PreferencesModeSpotifyUser:
        [self.manager performSpotifyUserAlbums:done andFailure:failure];
        break;

    case PreferencesModeSpotifyReleases:
        [self.manager performSpotifyReleases:done andFailure:failure];
        break;

    case PreferencesModeSpotifyLikedSongs:
        [self.manager performSpotifyLikedSongs:done andFailure:failure];
        break;

    default:
        break;
    }
}

- (void)layout
{
    [super layout];
    if (!self.didCommonInit) {
        return;
    }
    [self prepareLayout];
}

- (void)animate
{
    NSMutableArray* current = self.currentItems.mutableCopy;
    NSMutableArray* totalItem = self.totalItems.mutableCopy;
    [totalItem removeObjectsInArray:current];

    if (!totalItem.count || !current.count)
        return;

    NSInteger currentIndex;
    NSInteger totalIndex = SSRandomIntBetween(0, (int)totalItem.count - 1);

    do {
        currentIndex = SSRandomIntBetween(0, (int)current.count - 1);
    } while (current.count > 1 && currentIndex == self.lastCellIndex);

    Artwork* newArtwork = [totalItem objectAtIndex:totalIndex];
    current[currentIndex] = newArtwork;

    MusaicItem* item = (MusaicItem*)[self.collectionView itemAtIndex:currentIndex];
    [self configure:item forUrl:newArtwork.artworkUrl andType:MusaicAnimationFlip];
    self.lastCellIndex = currentIndex;
    self.currentItems = current.copy;
}

- (CGRect)calculateFrameRect:(NSRect)bounds
{
    CGSize totalSize = self.bounds.size;
    CGFloat (^calculateBlock)(CGFloat size, CGFloat windowSize) = ^CGFloat(CGFloat size, CGFloat windowSize) {
        if (size <= 0.0 || windowSize <= 0.0) {
            return 0.0;
        }
        CGFloat current = 0.0;
        while (current < windowSize)
            current += size;
        return current;
    };
    CGFloat height = calculateBlock(self.collectionViewLayout.itemSize.height, totalSize.height);
    CGFloat width = calculateBlock(self.collectionViewLayout.itemSize.width, totalSize.width);
    return NSMakeRect(0, 0, width, height);
}

- (NSInteger)maximalCount
{
    CGSize itemSize = self.collectionViewLayout.itemSize;
    if (itemSize.width <= 0.0 || itemSize.height <= 0.0) {
        return 0;
    }

    CGSize size = [self calculateFrameRect:self.bounds].size;
    if (size.width <= 0.0 || size.height <= 0.0) {
        return 0;
    }

    CGFloat count = (size.width * size.height) / (itemSize.width * itemSize.height);
    return (NSInteger)ceilf(count);
}

- (BOOL)hasConfigureSheet
{
    return YES;
}

- (void)onSleepNote:(NSNotification*)inNotification
{
    if (@available(macOS 14.0, *)) {
        if (![self shouldInstallLifecycleWorkarounds]) {
            return;
        }
        exit(0);
    }
}

- (void)willStop:(NSNotification*)inNotification
{
    if (@available(macOS 14.0, *)) {
        if (![self shouldInstallLifecycleWorkarounds]) {
            return;
        }
        exit(0);
    }
}

- (NSWindow*)configureSheet
{
    if (!self.prefencesViewController) {
        self.prefencesViewController = [PreferencesViewController new];
    }
    if (!self.prefencesViewController.window) {
        [self.prefencesViewController loadWindow];
    }

    NSWindow* window = self.prefencesViewController.window;
    if (!window) {
        return nil;
    }
    window.styleMask = NSWindowStyleMaskTitled;
    return window;
}

- (NSCollectionViewItem*)collectionView:(NSCollectionView*)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath*)indexPath
{
    MusaicItem* item = [collectionView makeItemWithIdentifier:NSStringFromClass([MusaicItem class]) forIndexPath:indexPath];
    Artwork* artwork;
    if (self.currentItems.count > indexPath.item) artwork = self.currentItems[indexPath.item];
    [self configure:item forUrl:artwork.artworkUrl andType:MusaicAnimationFade];
    return item;
}

- (void)configure:(MusaicItem*)item forUrl:(NSURL*)url andType:(MusaicAnimation)type
{

    __weak typeof(self) weakSelf = self;
    void (^completion)(NSImage* image, NSData* data, NSError* error, SDImageCacheType cacheType, BOOL finished, NSURL* imageURL) = ^void(NSImage* image, NSData* data, NSError* error, SDImageCacheType cacheType, BOOL finished, NSURL* imageURL) {
        if (!image)
            return;

        item.imageView.image = image;
        if (type == MusaicAnimationNone) {
            return;
        }

        CATransition* transition = [CATransition new];
        transition.type = type == MusaicAnimationFlip ? @"flip" : kCATransitionFade;
        transition.subtype = kCATransitionFromRight;
        transition.duration = type == MusaicAnimationFlip ? 0.75 : 0.3;
        [item.imageView.layer addAnimation:transition forKey:nil];
        [weakSelf.timer invalidate];
        weakSelf.timer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)[Preferences preferences].delays
                                                          target:self
                                                        selector:@selector(animate)
                                                        userInfo:nil
                                                         repeats:NO];

    };

    [[SDWebImageManager sharedManager] loadImageWithURL:url options:0 progress:nil completed:completion];
}

- (NSInteger)numberOfSectionsInCollectionView:(NSCollectionView*)collectionView
{
    return 1;
}

- (NSInteger)collectionView:(NSCollectionView*)collectionView numberOfItemsInSection:(NSInteger)section
{
    return [self maximalCount];
}

@end
