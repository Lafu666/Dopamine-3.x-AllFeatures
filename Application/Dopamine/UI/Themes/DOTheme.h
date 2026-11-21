//
//  DOTheme.h
//  Dopamine
//
//  Created by tomt000 on 14/02/2024.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DOTheme : NSObject

@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *icon;
@property (nonatomic, retain) NSString *key;
@property (nonatomic, retain) UIColor *actionMenuColor;
@property (nonatomic, retain) UIColor *windowColor;
@property (nonatomic, retain) UIImage *image;
@property (nonatomic, retain) UIImage *landscapeImage;
@property (nonatomic, assign) float blur;
@property (nonatomic, assign) float dimAlpha;
@property (nonatomic, assign) BOOL titleShadow;

- (id)initWithDictionary: (NSDictionary *)dictionary;

- (UIImage *)imageForSize:(CGSize)size;

- (UIImage *)generateBootLogo;

@end


NS_ASSUME_NONNULL_END
