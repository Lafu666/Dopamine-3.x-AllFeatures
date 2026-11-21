//
//  DOUnjectController.h
//  Dopamine
//
//  Unject selective injection blacklist
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DOUnjectController : UIViewController

@property (nonatomic, copy, nullable) void (^onChange)(void);

@end

NS_ASSUME_NONNULL_END
