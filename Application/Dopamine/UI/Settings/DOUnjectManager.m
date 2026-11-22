//
//  DOUnjectManager.m
//  Dopamine
//
//  Unject selective injection blacklist
//

#import "DOUnjectManager.h"
#import "DOEnvironmentManager.h"
#import "DOUIManager.h"

#import <objc/runtime.h>
#import <sys/stat.h>
#import <unistd.h>
#import <libjailbreak/util.h>

#define UNJECT_CONFIG_PATH JBROOT_PATH("/basebin/unject.plist")

static NSString *DOUnjectConfigFilePath(void)
{
    return [NSString stringWithUTF8String:UNJECT_CONFIG_PATH];
}

@interface DOUnjectManager (Private)
+ (UIImage *)iconForBundleIdentifier:(NSString *)bundleIdentifier;
+ (UIImage *)placeholderIconWithName:(NSString *)name;
+ (UIImage *)resizedIcon:(UIImage *)icon size:(CGSize)size;
- (void)scanApplicationDirectoriesInto:(NSMutableDictionary<NSString *, DOUnjectApp *> *)appsByIdentifier;
@end

@implementation DOUnjectApp
{
    UIImage *_icon;
}

- (UIImage *)cachedIcon
{
    @synchronized (self) {
        return _icon;
    }
}

- (UIImage *)icon
{
    @synchronized (self) {
        if (_icon) return _icon;
        UIImage *icon = [DOUnjectManager iconForBundleIdentifier:self.bundleIdentifier];
        if (icon) {
            icon = [DOUnjectManager resizedIcon:icon size:CGSizeMake(29, 29)];
        }
        else {
            icon = [DOUnjectManager placeholderIconWithName:self.name];
        }
        _icon = icon;
        return _icon;
    }
}

@end

@implementation DOUnjectManager
{
    NSArray<DOUnjectApp *> *_installedApps;
}

+ (instancetype)sharedManager
{
    static DOUnjectManager *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[DOUnjectManager alloc] init];
    });
    return shared;
}

#pragma mark - Config file

- (NSMutableDictionary *)config
{
    __block NSDictionary *config = nil;
    [[DOEnvironmentManager sharedManager] runUnsandboxed:^{
        config = [NSDictionary dictionaryWithContentsOfFile:DOUnjectConfigFilePath()];
    }];
    if (![config isKindOfClass:[NSDictionary class]]) {
        config = nil;
    }
    return [config mutableCopy] ?: [NSMutableDictionary dictionary];
}

- (BOOL)writeConfig:(NSDictionary *)config
{
    NSError *error = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:config format:NSPropertyListXMLFormat_v1_0 options:0 error:&error];
    if (!data) return NO;

    __block BOOL success = NO;
    NSString *path = DOUnjectConfigFilePath();
    [[DOEnvironmentManager sharedManager] runAsRoot:^{
        [[DOEnvironmentManager sharedManager] runUnsandboxed:^{
            NSString *directory = [path stringByDeletingLastPathComponent];
            [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
            success = [data writeToFile:path atomically:YES];
            if (success) {
                chmod(path.fileSystemRepresentation, 0644);
                chown(path.fileSystemRepresentation, 0, 0);
            }
        }];
    }];
    return success;
}

#pragma mark - State

- (BOOL)enabled
{
    return [[self config][@"Enabled"] boolValue];
}

- (void)setEnabled:(BOOL)enabled
{
    NSMutableDictionary *config = [self config];
    config[@"Enabled"] = @(enabled);
    [self writeConfig:config];
}

- (NSUInteger)blacklistedCount
{
    NSDictionary *apps = [self config][@"Apps"];
    if (![apps isKindOfClass:[NSDictionary class]]) return 0;
    return apps.count;
}

- (NSArray<NSString *> *)blacklistedExecutables
{
    NSArray *executables = [self config][@"Executables"];
    if (![executables isKindOfClass:[NSArray class]]) return @[];
    return executables;
}

- (NSSet<NSString *> *)blacklistedBundleIdentifiers
{
    NSDictionary *apps = [self config][@"Apps"];
    if (![apps isKindOfClass:[NSDictionary class]]) return [NSSet set];
    return [NSSet setWithArray:apps.allKeys];
}

- (BOOL)isAppBlacklisted:(DOUnjectApp *)app
{
    if (!app.bundleIdentifier) return NO;
    NSDictionary *apps = [self config][@"Apps"];
    if (![apps isKindOfClass:[NSDictionary class]]) return NO;
    return apps[app.bundleIdentifier] != nil;
}

- (BOOL)setApp:(DOUnjectApp *)app blacklisted:(BOOL)blacklisted
{
    if (!app.bundleIdentifier.length) return NO;

    NSMutableDictionary *config = [self config];
    NSDictionary *existingApps = config[@"Apps"];
    NSMutableDictionary *apps = [existingApps isKindOfClass:[NSDictionary class]] ? [existingApps mutableCopy] : [NSMutableDictionary dictionary];

    // Remember which executables the previous App entries were responsible for,
    // so that manually added entries inside "Executables" survive the rewrite.
    NSMutableSet<NSString *> *previousDerived = [NSMutableSet set];
    for (NSDictionary *info in apps.allValues) {
        if ([info isKindOfClass:[NSDictionary class]] && [info[@"Executable"] isKindOfClass:[NSString class]]) {
            [previousDerived addObject:info[@"Executable"]];
        }
    }

    if (blacklisted) {
        NSMutableDictionary *info = [NSMutableDictionary dictionary];
        info[@"Name"] = app.name ?: @"";
        if (app.executableName.length) info[@"Executable"] = app.executableName;
        if (app.bundlePath.length) info[@"Path"] = app.bundlePath;
        apps[app.bundleIdentifier] = info;
    }
    else {
        [apps removeObjectForKey:app.bundleIdentifier];
    }

    NSMutableArray<NSString *> *executables = [NSMutableArray array];
    NSArray *existingExecutables = config[@"Executables"];
    if ([existingExecutables isKindOfClass:[NSArray class]]) {
        for (NSString *executable in existingExecutables) {
            if (![executable isKindOfClass:[NSString class]]) continue;
            if ([previousDerived containsObject:executable]) continue;
            if (![executables containsObject:executable]) [executables addObject:executable];
        }
    }
    for (NSDictionary *info in apps.allValues) {
        if (![info isKindOfClass:[NSDictionary class]]) continue;
        NSString *executable = info[@"Executable"];
        if (![executable isKindOfClass:[NSString class]] || !executable.length) continue;
        if (![executables containsObject:executable]) [executables addObject:executable];
    }

    if (apps.count) {
        config[@"Apps"] = apps;
    }
    else {
        [config removeObjectForKey:@"Apps"];
    }
    if (executables.count) {
        config[@"Executables"] = executables;
    }
    else {
        [config removeObjectForKey:@"Executables"];
    }

    return [self writeConfig:config];
}

#pragma mark - Installed apps

- (NSArray<DOUnjectApp *> *)installedApps
{
    if (!_installedApps) {
        [self reloadInstalledApps];
    }
    return _installedApps ?: @[];
}

- (void)reloadInstalledApps
{
    NSMutableDictionary<NSString *, DOUnjectApp *> *appsByIdentifier = [NSMutableDictionary dictionary];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (workspaceClass) {
        id workspace = [workspaceClass performSelector:@selector(defaultWorkspace)];
        if (workspace) {
            NSArray<NSString *> *selectors = @[@"allInstalledApplications", @"allApplications"];
            for (NSString *selectorName in selectors) {
                SEL selector = NSSelectorFromString(selectorName);
                if (![workspace respondsToSelector:selector]) continue;

                NSArray *proxies = [workspace performSelector:selector];
                if (![proxies isKindOfClass:[NSArray class]]) continue;

                for (id proxy in proxies) {
                    if (![proxy respondsToSelector:@selector(bundleIdentifier)]) continue;

                    NSString *bundleIdentifier = [proxy performSelector:@selector(bundleIdentifier)];
                    if (![bundleIdentifier isKindOfClass:[NSString class]] || !bundleIdentifier.length) continue;
                    if (appsByIdentifier[bundleIdentifier]) continue;

                    DOUnjectApp *app = [[DOUnjectApp alloc] init];
                    app.bundleIdentifier = bundleIdentifier;

                    NSString *localizedName = nil;
                    if ([proxy respondsToSelector:@selector(localizedName)]) {
                        localizedName = [proxy performSelector:@selector(localizedName)];
                    }
                    app.name = [localizedName isKindOfClass:[NSString class]] && localizedName.length ? localizedName : bundleIdentifier;

                    NSString *bundleExecutable = nil;
                    if ([proxy respondsToSelector:@selector(bundleExecutable)]) {
                        bundleExecutable = [proxy performSelector:@selector(bundleExecutable)];
                    }

                    NSURL *bundleURL = nil;
                    if ([proxy respondsToSelector:@selector(bundleURL)]) {
                        bundleURL = [proxy performSelector:@selector(bundleURL)];
                    }
                    if ([bundleURL isKindOfClass:[NSURL class]]) {
                        app.bundlePath = bundleURL.path;
                    }

                    if ([bundleExecutable isKindOfClass:[NSString class]] && bundleExecutable.length) {
                        app.executableName = bundleExecutable;
                    }
                    else if (app.bundlePath.length) {
                        app.executableName = app.bundlePath.lastPathComponent.stringByDeletingPathExtension;
                    }

                    // Skip entries without an executable (web clips and other non-binary bundles)
                    if (!app.executableName.length) continue;

                    NSString *applicationType = nil;
                    if ([proxy respondsToSelector:@selector(applicationType)]) {
                        applicationType = [proxy performSelector:@selector(applicationType)];
                    }
                    app.systemApp = [applicationType isKindOfClass:[NSString class]] && [applicationType isEqualToString:@"System"];

                    appsByIdentifier[bundleIdentifier] = app;
                }
            }
        }
    }

#pragma clang diagnostic pop

    if (appsByIdentifier.count == 0) {
        [self scanApplicationDirectoriesInto:appsByIdentifier];
    }

    _installedApps = [appsByIdentifier.allValues sortedArrayUsingComparator:^NSComparisonResult(DOUnjectApp *app1, DOUnjectApp *app2) {
        if (app1.isSystemApp != app2.isSystemApp) {
            return app1.isSystemApp ? NSOrderedDescending : NSOrderedAscending;
        }
        return [app1.name localizedStandardCompare:app2.name];
    }];
}

- (void)scanApplicationDirectoriesInto:(NSMutableDictionary<NSString *, DOUnjectApp *> *)appsByIdentifier
{
    // LSApplicationWorkspace is not reachable from every process, walk the app
    // bundle directories instead so the list is never empty on a jailbroken device
    NSArray<NSString *> *directories = @[@"/var/containers/Bundle/Application", @"/Applications"];

    __block NSArray<NSDictionary *> *found = nil;
    [[DOEnvironmentManager sharedManager] runUnsandboxed:^{
        NSMutableArray<NSDictionary *> *results = [NSMutableArray array];
        NSFileManager *fileManager = [NSFileManager defaultManager];

        for (NSString *directory in directories) {
            NSArray<NSString *> *containers = [fileManager contentsOfDirectoryAtPath:directory error:nil];
            for (NSString *container in containers) {
                NSString *containerPath = [directory stringByAppendingPathComponent:container];
                NSArray<NSString *> *bundleNames = [fileManager contentsOfDirectoryAtPath:containerPath error:nil];
                for (NSString *bundleName in bundleNames) {
                    if (![bundleName hasSuffix:@".app"]) continue;

                    NSString *bundlePath = [containerPath stringByAppendingPathComponent:bundleName];
                    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[bundlePath stringByAppendingPathComponent:@"Info.plist"]];
                    if (![info isKindOfClass:[NSDictionary class]]) continue;

                    NSString *identifier = info[@"CFBundleIdentifier"];
                    if (![identifier isKindOfClass:[NSString class]] || !identifier.length) continue;

                    NSString *name = info[@"CFBundleDisplayName"];
                    if (![name isKindOfClass:[NSString class]] || !name.length) name = info[@"CFBundleName"];
                    if (![name isKindOfClass:[NSString class]] || !name.length) name = [bundleName stringByDeletingPathExtension];

                    NSString *executable = info[@"CFBundleExecutable"];
                    if (![executable isKindOfClass:[NSString class]]) executable = @"";

                    [results addObject:@{
                        @"identifier": identifier,
                        @"name": name,
                        @"executable": executable,
                        @"path": bundlePath,
                    }];
                }
            }
        }

        found = results;
    }];

    for (NSDictionary *entry in found) {
        NSString *identifier = entry[@"identifier"];
        if (appsByIdentifier[identifier]) continue;

        DOUnjectApp *app = [[DOUnjectApp alloc] init];
        app.bundleIdentifier = identifier;
        app.name = entry[@"name"];
        app.executableName = entry[@"executable"];
        app.bundlePath = entry[@"path"];
        if (!app.executableName.length) {
            app.executableName = [app.bundlePath.lastPathComponent stringByDeletingPathExtension];
        }
        if (!app.executableName.length) continue;

        appsByIdentifier[identifier] = app;
    }
}

#pragma mark - Icons

+ (UIImage *)iconForBundleIdentifier:(NSString *)bundleIdentifier
{
    if (!bundleIdentifier.length) return nil;

    // Preferred: UIKit's internal icon lookup, returns a properly sized icon
    SEL iconSelector = NSSelectorFromString(@"_applicationIconImageForBundleIdentifier:format:scale:");
    if ([[UIImage class] respondsToSelector:iconSelector]) {
        NSMethodSignature *signature = [[UIImage class] methodSignatureForSelector:iconSelector];
        if (signature) {
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setTarget:[UIImage class]];
            [invocation setSelector:iconSelector];
            NSString *identifier = bundleIdentifier;
            int format = 0;
            CGFloat scale = [UIScreen mainScreen].scale;
            [invocation setArgument:&identifier atIndex:2];
            [invocation setArgument:&format atIndex:3];
            [invocation setArgument:&scale atIndex:4];
            [invocation invoke];

            __unsafe_unretained UIImage *image = nil;
            [invocation getReturnValue:&image];
            if (image) return image;
        }
    }

    // Fallback: LSApplicationProxy icon data
    Class proxyClass = NSClassFromString(@"LSApplicationProxy");
    if (proxyClass) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        SEL proxySelector = NSSelectorFromString(@"applicationProxyForIdentifier:");
        if ([proxyClass respondsToSelector:proxySelector]) {
            id proxy = [proxyClass performSelector:proxySelector withObject:bundleIdentifier];
            SEL dataSelector = NSSelectorFromString(@"iconDataForVariant:");
            if (proxy && [proxy respondsToSelector:dataSelector]) {
                NSMethodSignature *signature = [proxy methodSignatureForSelector:dataSelector];
                if (signature && signature.numberOfArguments >= 3) {
                    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                    [invocation setTarget:proxy];
                    [invocation setSelector:dataSelector];
                    int variant = 2;
                    [invocation setArgument:&variant atIndex:2];
                    [invocation invoke];

                    __unsafe_unretained NSData *iconData = nil;
                    [invocation getReturnValue:&iconData];
                    if ([iconData isKindOfClass:[NSData class]] && iconData.length) {
                        UIImage *image = [UIImage imageWithData:iconData];
                        if (image) return image;
                    }
                }
            }
        }
#pragma clang diagnostic pop
    }

    return nil;
}

+ (UIImage *)resizedIcon:(UIImage *)icon size:(CGSize)size
{
    if (!icon) return nil;
    if (CGSizeEqualToSize(icon.size, size)) return icon;

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size.width, size.height) cornerRadius:6.5];
        [path addClip];
        [icon drawInRect:CGRectMake(0, 0, size.width, size.height)];
    }];
}

+ (UIImage *)placeholderIconWithName:(NSString *)name
{
    CGSize size = CGSizeMake(29, 29);
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size.width, size.height) cornerRadius:6.5];
        [[UIColor colorWithWhite:1.0 alpha:0.15] setFill];
        [path fill];

        NSString *letter = name.length ? [name substringToIndex:1] : @"?";
        UIFont *font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        NSDictionary *attributes = @{ NSFontAttributeName : font, NSForegroundColorAttributeName : [UIColor colorWithWhite:1.0 alpha:0.7] };
        CGSize letterSize = [letter sizeWithAttributes:attributes];
        [letter drawAtPoint:CGPointMake((size.width - letterSize.width) / 2.0, (size.height - letterSize.height) / 2.0) withAttributes:attributes];
    }];
}

@end
