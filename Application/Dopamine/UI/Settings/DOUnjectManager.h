//
//  DOUnjectManager.h
//  Dopamine
//
//  Unject selective injection blacklist
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DOUnjectApp : NSObject
@property (nonatomic, copy) NSString *bundleIdentifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *executableName;
@property (nonatomic, copy, nullable) NSString *bundlePath;
@property (nonatomic, assign, getter=isSystemApp) BOOL systemApp;
- (UIImage *)icon;
- (UIImage *)cachedIcon;
@end

@interface DOUnjectManager : NSObject

+ (instancetype)sharedManager;

@property (nonatomic, readonly) BOOL enabled;
@property (nonatomic, readonly) NSArray<DOUnjectApp *> *installedApps;

- (void)setEnabled:(BOOL)enabled;
- (void)reloadInstalledApps;

- (NSUInteger)blacklistedCount;
- (NSSet<NSString *> *)blacklistedBundleIdentifiers;
- (NSArray<NSString *> *)blacklistedExecutables;
- (BOOL)isAppBlacklisted:(DOUnjectApp *)app;
- (BOOL)setApp:(DOUnjectApp *)app blacklisted:(BOOL)blacklisted;

@end

NS_ASSUME_NONNULL_END
