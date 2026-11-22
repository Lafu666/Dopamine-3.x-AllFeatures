//
//  DONavigationController.m
//  Dopamine
//
//  Created by tomt000 on 04/01/2024.
//

#import "DONavigationController.h"
#import <objc/runtime.h>
#import "DOModalBackAction.h"
#import "DOGlobalAppearance.h"
#import "DOThemeManager.h"

@interface DONavigationController () <UIGestureRecognizerDelegate>

@property (nonatomic) UIImageView *backgroundImageView;
@property (nonatomic) UIView *backgroundDimView;
@property (nonatomic) CGSize lastBackgroundSize;
@property (nonatomic) DOMainViewController *mainView;
@property (nonatomic) DOModalBackAction *backAction;
@property (nonatomic) BOOL backgroundPopInProgress;

- (BOOL)isShowingMainView;
- (void)updateBackActionGeometry;
- (void)popFromBackground;
- (void)backgroundTapped:(UITapGestureRecognizer *)gestureRecognizer;

@end

@interface UINavigationController (Private)
-(CGRect)_frameForViewController:(id)arg1;
@end

@implementation DONavigationController

- (void)viewDidLoad
{
    [self setupBackground];
    [super viewDidLoad];
    [self setNavigationBarHidden:YES];
    [self pushViewController:(self.mainView = [[DOMainViewController alloc] init]) animated:NO];
    [self setDelegate:self];
    [self setOverrideUserInterfaceStyle:UIUserInterfaceStyleDark];
}

- (void)setupBackground
{
    DOTheme *theme = [[DOThemeManager sharedInstance] enabledTheme];
    
    self.view.backgroundColor = [UIColor blackColor];
    self.backgroundImageView = [[UIImageView alloc] init];
    self.backgroundImageView.image = [theme imageForSize:self.view.bounds.size];
    self.backgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.backgroundImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundImageView.userInteractionEnabled = NO;
    self.backgroundImageView.layer.zPosition = -2;

    [self.view insertSubview:self.backgroundImageView atIndex:0];

    // Slightly dims bright wallpapers so that the white labels stay readable
    self.backgroundDimView = [[UIView alloc] init];
    self.backgroundDimView.backgroundColor = [UIColor blackColor];
    self.backgroundDimView.alpha = theme.dimAlpha;
    self.backgroundDimView.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundDimView.userInteractionEnabled = NO;
    self.backgroundDimView.layer.zPosition = -1;

    [self.view insertSubview:self.backgroundDimView atIndex:1];

    [NSLayoutConstraint activateConstraints:@[
        [self.backgroundImageView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.backgroundImageView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.backgroundImageView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-100],
        [self.backgroundImageView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:100],
        [self.backgroundDimView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.backgroundDimView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.backgroundDimView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.backgroundDimView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    __weak typeof(self) weakSelf = self;
    self.backAction = [[DOModalBackAction alloc] initWithAction:^{
        [weakSelf popFromBackground];
    }];
    self.backAction.translatesAutoresizingMaskIntoConstraints = NO;
    self.backAction.hidden = YES;
    
    [self.view insertSubview:self.backAction atIndex:2];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.backAction.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.backAction.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.backAction.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.backAction.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    // The modal pages draw their own back button, and pages that do not have one
    // are supposed to be dismissed by tapping the empty area around them. The
    // navigation controller's transition view sits above the back action, so a
    // tap gesture on the root view is used as a fallback for those pages.
    UITapGestureRecognizer *backgroundTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTapped:)];
    backgroundTapRecognizer.cancelsTouchesInView = NO;
    backgroundTapRecognizer.delegate = self;
    [self.view addGestureRecognizer:backgroundTapRecognizer];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    // Swap between portrait and landscape artwork when the window size changes
    CGSize size = self.view.bounds.size;
    if (!CGSizeEqualToSize(size, self.lastBackgroundSize)) {
        self.lastBackgroundSize = size;
        self.backgroundImageView.image = [[[DOThemeManager sharedInstance] enabledTheme] imageForSize:size];
    }

    [self updateBackActionGeometry];
}

- (BOOL)isShowingMainView
{
    return self.topViewController == self.mainView;
}

- (void)updateBackActionGeometry
{
    // The navigation transition view is added on top of the background views when
    // a page is pushed, which would swallow the taps meant for the back action
    if (self.view.subviews.lastObject != self.backAction) {
        [self.view bringSubviewToFront:self.backAction];
    }

    UIView *topView = self.topViewController.view;
    if (!topView || [self isShowingMainView]) return;

    // Use the actual on screen frame of the page instead of the private
    // _frameForViewController: value, which is not always up to date yet
    CGRect pageFrame = [topView convertRect:topView.bounds toView:self.view];
    if (!CGRectIsEmpty(pageFrame)) {
        self.backAction.ignoreFrame = pageFrame;
    }
}

- (void)popFromBackground
{
    // Both the back action view and the fallback tap gesture can fire for the
    // same touch, make sure the page is only popped once
    if (self.backgroundPopInProgress) return;
    if (self.viewControllers.count <= 1 || [self isShowingMainView]) return;

    self.backgroundPopInProgress = YES;
    [self popViewControllerAnimated:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.backgroundPopInProgress = NO;
    });
}

- (void)backgroundTapped:(UITapGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state != UIGestureRecognizerStateEnded) return;
    [self popFromBackground];
}

- (void)setBackgroundDimmed:(BOOL)dimmed
{
    CGFloat dimAlpha = [[DOThemeManager sharedInstance] enabledTheme].dimAlpha;
    [UIView animateWithDuration:0.3 animations:^{
        self.backgroundImageView.alpha = dimmed ? 0.4 : 1;
        self.backgroundDimView.alpha = dimmed ? dimAlpha * 0.4 : dimAlpha;
    }];
    self.backgroundImageView.userInteractionEnabled = dimmed;
    self.backAction.hidden = !dimmed;
}

#pragma mark - Delegate

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController
           animationControllerForOperation:(UINavigationControllerOperation)operation
                        fromViewController:(UIViewController *)fromVC
                          toViewController:(UIViewController *)toVC {
    
    
    if (fromVC.class == DOMainViewController.class || toVC.class == DOMainViewController.class)
        return [[DOModalTransitionScale alloc] initForwards: operation == UINavigationControllerOperationPush];
    return [[DOModalTransitionPush alloc] initForwards: operation == UINavigationControllerOperationPush];
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    [self setBackgroundDimmed:![viewController isKindOfClass:[DOMainViewController class]]];
    [self updateBackActionGeometry];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if (self.viewControllers.count <= 1) return NO;
    if ([self isShowingMainView]) return NO;
    if (self.backAction.hidden) return NO;

    // Let touches inside the page through, only the surrounding area dismisses it
    CGRect pageFrame = self.backAction.ignoreFrame;
    if (CGRectIsEmpty(pageFrame)) {
        UIView *topView = self.topViewController.view;
        if (!topView) return NO;
        pageFrame = [topView convertRect:topView.bounds toView:self.view];
    }
    if (CGRectIsEmpty(pageFrame)) return NO;

    CGPoint point = [touch locationInView:self.view];
    return !CGRectContainsPoint(pageFrame, point);
}

#pragma mark - Overrides

-(CGRect)_frameForViewController:(id)viewController
{
    CGRect orig = [super _frameForViewController: viewController];
    if ([[viewController class] isEqual: [DOMainViewController class]])
        return orig;
    
    orig.size.width = fmin(orig.size.width - UI_MODAL_PADDING * 2, UI_IPAD_MAX_WIDTH);
    orig.size.height *= [DOGlobalAppearance isSmallDevice] ? 0.8 : 0.7;
    orig.origin.x = (self.view.frame.size.width - orig.size.width) / 2;
    orig.origin.y = (self.view.frame.size.height - orig.size.height) / 2;

    return orig;

}


@end
