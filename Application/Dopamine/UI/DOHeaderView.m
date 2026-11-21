//
//  DOHeaderView.m
//  Dopamine
//
//  Created by tomt000 on 04/01/2024.
//

#import "DOHeaderView.h"
#import "DOThemeManager.h"
#import "DOUIManager.h"
#import <sys/sysctl.h>
#import <sys/time.h>
#import <time.h>

@interface DOHeaderView ()

@property (nonatomic) UIImageView *logoView;
@property (nonatomic) UILabel *uptimeLabel;
@property (nonatomic, copy) NSDictionary<NSAttributedStringKey, id> *uptimeAttributes;
@property (nonatomic) NSTimer *uptimeTimer;

@end

@implementation DOHeaderView

-(id)initWithImage:(UIImage *)image subtitles:(NSArray<NSAttributedString *> *)subtitles {
    return [self initWithImage:image subtitles:subtitles uptimeSubtitleIndex:NSNotFound];
}

-(id)initWithImage:(UIImage *)image subtitles:(NSArray<NSAttributedString *> *)subtitles uptimeSubtitleIndex:(NSInteger)uptimeSubtitleIndex {
    if (self = [super init]) {
        UIStackView *stackView = [[UIStackView alloc] init];
        stackView.axis = UILayoutConstraintAxisVertical;
        stackView.spacing = 2;
        stackView.translatesAutoresizingMaskIntoConstraints = NO;
        stackView.alignment = UIStackViewAlignmentLeading;

        [self addSubview:stackView];

        [NSLayoutConstraint activateConstraints:@[
            [stackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [stackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [stackView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [stackView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];

        //1 - Add the logo to our stack
        self.logoView = [[UIImageView alloc] init];
        self.logoView.translatesAutoresizingMaskIntoConstraints = NO;
        self.logoView.image = [image imageWithAlignmentRectInsets:UIEdgeInsetsMake(7, 0, -7, 0)];
        [stackView addArrangedSubview:self.logoView];

        [NSLayoutConstraint activateConstraints:@[
            [self.logoView.heightAnchor constraintEqualToConstant:40],
            [self.logoView.widthAnchor constraintEqualToAnchor:self.logoView.heightAnchor multiplier:image.size.width / image.size.height],
        ]];

        //3 - Add our subtitles to our stack
        [subtitles enumerateObjectsUsingBlock:^(NSAttributedString *formatedText, NSUInteger idx, BOOL *stop) {
            UILabel *label = [[UILabel alloc] init];
            label.attributedText = formatedText;
            label.translatesAutoresizingMaskIntoConstraints = NO;
            label.adjustsFontSizeToFitWidth = YES;
            label.minimumScaleFactor = 0.75;
            label.lineBreakMode = NSLineBreakByClipping;
            [stackView addArrangedSubview:label];

            [NSLayoutConstraint activateConstraints:@[
                [label.widthAnchor constraintLessThanOrEqualToAnchor:stackView.widthAnchor]
            ]];

            if ((NSInteger)idx == uptimeSubtitleIndex) {
                self.uptimeLabel = label;
                self.uptimeAttributes = formatedText.attributes;
            }
        }];

        self.translatesAutoresizingMaskIntoConstraints = NO;

        DOTheme *theme = [[DOThemeManager sharedInstance] enabledTheme];
        if (theme.titleShadow)
        {
            self.layer.shadowColor = [UIColor blackColor].CGColor;
            self.layer.shadowOffset = CGSizeZero;
            self.layer.shadowRadius = 30;
            self.layer.shadowOpacity = 0.3;
        }

        if (self.uptimeLabel) {
            [self updateUptimeLabel];

            __weak typeof(self) weakSelf = self;
            NSTimer *uptimeTimer = [NSTimer timerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
                [weakSelf updateUptimeLabel];
            }];
            uptimeTimer.tolerance = 0.1;
            [[NSRunLoop mainRunLoop] addTimer:uptimeTimer forMode:NSRunLoopCommonModes];
            self.uptimeTimer = uptimeTimer;
        }
    }
    return self;
}

- (void)dealloc
{
    [self.uptimeTimer invalidate];
}

- (void)updateUptimeLabel
{
    if (!self.uptimeLabel || !self.uptimeAttributes) return;

    // Use plain text here so adjustsFontSizeToFitWidth keeps working on small devices
    UIFont *font = self.uptimeAttributes[NSFontAttributeName];
    UIColor *color = self.uptimeAttributes[NSForegroundColorAttributeName];
    if (font) self.uptimeLabel.font = font;
    if (color) self.uptimeLabel.textColor = color;
    self.uptimeLabel.text = [DOHeaderView uptimeString];
}

+ (NSString *)uptimeString
{
    long long uptime = 0;

    struct timeval bootTime;
    size_t bootTimeSize = sizeof(bootTime);
    if (sysctlbyname("kern.boottime", &bootTime, &bootTimeSize, NULL, 0) == 0 && bootTime.tv_sec > 0) {
        uptime = (long long)time(NULL) - (long long)bootTime.tv_sec;
    }
    else {
        struct timespec ts;
        clock_gettime(CLOCK_MONOTONIC, &ts);
        uptime = ts.tv_sec;
    }
    if (uptime < 0) uptime = 0;

    int days = (int)(uptime / 86400);
    int hours = (int)((uptime % 86400) / 3600);
    int minutes = (int)((uptime % 3600) / 60);
    int seconds = (int)(uptime % 60);

    return [NSString stringWithFormat:DOLocalizedString(@"System_Uptime_Format"), days, hours, minutes, seconds];
}

@end
