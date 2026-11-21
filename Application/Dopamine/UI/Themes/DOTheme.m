//
//  DOTheme.m
//  Dopamine
//
//  Created by tomt000 on 14/02/2024.
//

#import "DOTheme.h"
#import "UIImage+Blur.h"

@interface DOTheme ()
@property (nonatomic, retain) NSString *imageName;
@property (nonatomic, retain) NSString *landscapeImageName;
@end

@implementation DOTheme

- (id)initWithDictionary: (NSDictionary *)dictionary
{
    self = [super init];
    if (self) {
        self.key = [dictionary objectForKey:@"key"];

        // Theme names are localized by key, falling back to the English name
        // stored in Themes.plist when a translation is not available
        NSString *defaultName = [dictionary objectForKey:@"name"];
        NSString *localizationKey = [NSString stringWithFormat:@"Theme_Name_%@", self.key];
        self.name = [[NSBundle mainBundle] localizedStringForKey:localizationKey value:defaultName table:nil];

        self.icon = [dictionary objectForKey:@"icon"];
        self.imageName = [dictionary objectForKey:@"image"];
        self.landscapeImageName = [dictionary objectForKey:@"imageLandscape"];
        self.windowColor = [self colorFromHexString:[dictionary objectForKey:@"windowColor"]];
        self.actionMenuColor = [self colorFromHexString:[dictionary objectForKey:@"actionMenuColor"]];
        self.blur = [[dictionary objectForKey:@"blur"] floatValue];
        self.dimAlpha = [[dictionary objectForKey:@"dimAlpha"] floatValue];
        self.titleShadow = [[dictionary objectForKey:@"titleShadow"] boolValue];
    }
    return self;
}

- (UIColor*)colorFromHexString:(NSString*)hexString
{
    unsigned int hexInt = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner scanHexInt:&hexInt];
    return [UIColor colorWithRed:((CGFloat)((hexInt & 0xFF0000) >> 16))/255.0 green:((CGFloat)((hexInt & 0xFF00) >> 8))/255.0 blue:((CGFloat)(hexInt & 0xFF))/255.0 alpha:((CGFloat)((hexInt & 0xFF000000) >> 24))/255.0];
}

- (UIImage *)image
{
    if (_image == nil)
        _image = [[UIImage imageNamed:self.imageName] imageWithBlur:self.blur];
    return _image;
}

- (UIImage *)landscapeImage
{
    if (_landscapeImage == nil && self.landscapeImageName)
        _landscapeImage = [[UIImage imageNamed:self.landscapeImageName] imageWithBlur:self.blur];
    return _landscapeImage;
}

- (UIImage *)imageForSize:(CGSize)size
{
    // Themes may ship a dedicated landscape artwork, otherwise use the
    // portrait / universal one and let aspect fill crop it
    if (size.width > size.height && self.landscapeImage)
        return self.landscapeImage;
    return self.image;
}

- (UIImage *)generateBootLogo
{
    UIImage *backgroundImage = [self image];
    CGSize canvasSize = backgroundImage.size;

    UIImage *overlayImage = [UIImage imageNamed:@"DopamineLogo"];

    // Keep the logo inside the canvas, portrait artwork can be narrower than 350pt
    CGFloat overlaySide = 350;
    CGFloat maxSide = fmin(canvasSize.width, canvasSize.height) * 0.8;
    if (overlaySide > maxSide)
        overlaySide = maxSide;

    CGSize overlaySize = CGSizeMake(overlaySide, overlaySide);
    CGPoint overlayOrigin = CGPointMake((canvasSize.width - overlaySize.width) / 2.0,
                                        (canvasSize.height - overlaySize.height) / 2.0);

    UIGraphicsBeginImageContextWithOptions(canvasSize, NO, backgroundImage.scale);

    [backgroundImage drawInRect:CGRectMake(0, 0, canvasSize.width, canvasSize.height)];

    // Render overlay (Dopamine Logo) in center of background for boot logo
    [overlayImage drawInRect:CGRectMake(overlayOrigin.x, overlayOrigin.y, overlaySize.width, overlaySize.height)];

    UIImage *finalImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return finalImage;
}

@end
