//
//  ADHelper.m
//  AppData
//
//  Created by Fouad Raheb on 6/29/20.
//

#import "ADHelper.h"

@interface ADHelper ()
@property (nonatomic, strong) NSBundle *resoucesBundle;
@property (nonatomic, strong) NSUserDefaults *userDefaults;
@end

@implementation ADHelper

+ (instancetype)sharedInstance {
    static dispatch_once_t p = 0;
    __strong static id _sharedObject = nil;
    dispatch_once(&p, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (void)initialize {
    // Create resources bundle
    self.resoucesBundle = [NSBundle bundleWithPath:@"/Library/Application Support/AppData/Resources.bundle"];
    
    // Load tweak preferences
    self.userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.fouadraheb.appdata"];
    [self.userDefaults registerDefaults:@{
        kSwipeUpEnabled : @(YES),
        kForceTouchMenuEnabled : @(NO)
    }];

    [self.userDefaults addObserver:self forKeyPath:kSwipeUpEnabled options:NSKeyValueObservingOptionNew context:NULL];
}

#pragma mark - Preferences

- (void)observeValueForKeyPath:(NSString *) keyPath ofObject:(id) object change:(NSDictionary *) change context:(void *) context {
    if ([keyPath isEqualToString:kSwipeUpEnabled]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kAppDataForceTouchMenuPreferencesChangedNotification object:nil];
    }
}

+ (BOOL)swipeUpEnabled {
    return [[ADHelper.sharedInstance.userDefaults objectForKey:kSwipeUpEnabled] boolValue];
}

+ (BOOL)forceTouchMenuEnabled {
    return [[ADHelper.sharedInstance.userDefaults objectForKey:kForceTouchMenuEnabled] boolValue];
}

#pragma mark - Resources

+ (UIImage *)imageNamed:(NSString *)imageName {
    return [UIImage imageNamed:imageName inBundle:ADHelper.sharedInstance.resoucesBundle];
}

#pragma mark - Helpers

+ (SBSApplicationShortcutItem *)applicationShortcutItem {
    SBSApplicationShortcutItem *shortcutItem = [[NSClassFromString(@"SBSApplicationShortcutItem") alloc] init];
    shortcutItem.localizedTitle = @"AppData";
    shortcutItem.type = kSBApplicationShortcutItemType;
    
    NSData *imageData = nil;
    if (@available(iOS 13, *)) {
        if ([UITraitCollection currentTraitCollection].userInterfaceStyle == UIUserInterfaceStyleDark) {
            imageData = UIImagePNGRepresentation([[self imageNamed:@"AppDataIconWhite"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]);
        } else {
            imageData = UIImagePNGRepresentation([[self imageNamed:@"AppDataIcon"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]);
        }
    } else {
        imageData = UIImagePNGRepresentation([[self imageNamed:@"AppDataIcon12"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]);
    }
    if (imageData) {
        SBSApplicationShortcutCustomImageIcon *iconImage = [[NSClassFromString(@"SBSApplicationShortcutCustomImageIcon") alloc] initWithImagePNGData:imageData];
        [shortcutItem setIcon:iconImage];
    }
    return shortcutItem;
}

@end
