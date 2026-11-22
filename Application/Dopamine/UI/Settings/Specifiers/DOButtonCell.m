//
//  DOButtonCell.m
//  Dopamine
//
//  Created by tomt000 on 26/01/2024.
//

#import "DOButtonCell.h"
#import "DOActionMenuButton.h"
#import "DOGlobalAppearance.h"
#import "DOUIManager.h"

@implementation DOButtonCell

- (id)initWithStyle:(long long)arg1 reuseIdentifier:(id)arg2 specifier:(PSSpecifier *)specifier
{
    self = [super init];
    if (self)
    {
        UIAction *action = [UIAction actionWithTitle:DOLocalizedString([specifier propertyForKey:@"title"]) image:[UIImage systemImageNamed:[specifier propertyForKey:@"image"] withConfiguration:[DOGlobalAppearance smallIconImageConfiguration]] identifier:[specifier propertyForKey:@"key"] handler:^(__kindof UIAction * _Nonnull action) {
            NSString *actionName = [specifier propertyForKey:@"action"];
            if (!actionName.length) return;

            // Accept both "- (void)foo" and "- (void)foo:(PSSpecifier *)specifier".
            // The plain name used to silently do nothing whenever the target method
            // took a specifier argument, because the selector didn't match.
            SEL selectorWithArgument = NSSelectorFromString([actionName stringByAppendingString:@":"]);
            SEL selector = NSSelectorFromString(actionName);
            id target = [specifier target];

            if ([target respondsToSelector:selectorWithArgument]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [target performSelector:selectorWithArgument withObject:specifier];
#pragma clang diagnostic pop
            }
            else if ([target respondsToSelector:selector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [target performSelector:selector];
#pragma clang diagnostic pop
            }
        }];

        DOActionMenuButton *button = [DOActionMenuButton buttonWithAction:action chevron:NO];

        button.translatesAutoresizingMaskIntoConstraints = NO;
        [button setContentHorizontalAlignment:UIControlContentHorizontalAlignmentCenter];
        button.layer.cornerRadius = 10;
        button.layer.masksToBounds = YES;
        button.layer.cornerCurve = kCACornerCurveContinuous;
        button.layer.borderWidth = 1;
        button.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.15].CGColor;

        [self.contentView addSubview:button];

        [NSLayoutConstraint activateConstraints:@[
            [button.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
            [button.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
            [button.topAnchor constraintEqualToAnchor:self.topAnchor constant:4],
            [button.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-4],
        ]];
    }
    return self;
}

@end
