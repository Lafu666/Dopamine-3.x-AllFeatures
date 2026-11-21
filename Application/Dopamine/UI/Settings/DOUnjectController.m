//
//  DOUnjectController.m
//  Dopamine
//
//  Unject selective injection blacklist
//

#import "DOUnjectController.h"
#import "DOUnjectManager.h"
#import "DOUIManager.h"

@interface DOUnjectAppCell : UITableViewCell
@property (nonatomic, strong) UISwitch *toggle;
@property (nonatomic, copy) NSString *bundleIdentifier;
@property (nonatomic, copy) void (^onToggle)(BOOL enabled);
- (void)configureWithApp:(DOUnjectApp *)app blacklisted:(BOOL)blacklisted;
- (void)setIconImage:(UIImage *)image;
@end

@implementation DOUnjectAppCell
{
    UIImageView *_iconView;
    UILabel *_nameLabel;
    UILabel *_identifierLabel;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];

        _iconView = [[UIImageView alloc] init];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
        _iconView.layer.cornerRadius = 6.5;
        _iconView.layer.masksToBounds = YES;
        [self.contentView addSubview:_iconView];

        _nameLabel = [[UILabel alloc] init];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _nameLabel.font = [UIFont systemFontOfSize:16];
        _nameLabel.textColor = [UIColor labelColor];
        [self.contentView addSubview:_nameLabel];

        _identifierLabel = [[UILabel alloc] init];
        _identifierLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _identifierLabel.font = [UIFont systemFontOfSize:12];
        _identifierLabel.textColor = [UIColor secondaryLabelColor];
        _identifierLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [self.contentView addSubview:_identifierLabel];

        _toggle = [[UISwitch alloc] init];
        _toggle.translatesAutoresizingMaskIntoConstraints = NO;
        [_toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
        [self.contentView addSubview:_toggle];

        [NSLayoutConstraint activateConstraints:@[
            [_iconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_iconView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_iconView.widthAnchor constraintEqualToConstant:29],
            [_iconView.heightAnchor constraintEqualToConstant:29],

            [_nameLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:12],
            [_nameLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
            [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_toggle.leadingAnchor constant:-12],

            [_identifierLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_identifierLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:2],
            [_identifierLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_toggle.leadingAnchor constant:-12],
            [_identifierLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10],

            [_toggle.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_toggle.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        ]];
    }
    return self;
}

- (void)configureWithApp:(DOUnjectApp *)app blacklisted:(BOOL)blacklisted
{
    self.bundleIdentifier = app.bundleIdentifier;
    _nameLabel.text = app.name;
    _identifierLabel.text = app.bundleIdentifier;
    _iconView.image = [app cachedIcon];
    _toggle.on = blacklisted;
    _toggle.onTintColor = [UIColor colorWithRed:71.0/255.0 green:169.0/255.0 blue:135.0/255.0 alpha:1.0];
}

- (void)setIconImage:(UIImage *)image
{
    _iconView.image = image;
}

- (void)toggleChanged:(UISwitch *)toggle
{
    if (self.onToggle) {
        self.onToggle(toggle.isOn);
    }
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.bundleIdentifier = nil;
    _iconView.image = nil;
    self.onToggle = nil;
}

@end

@interface DOUnjectController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) DOUnjectManager *manager;
@property (nonatomic, strong) NSArray<DOUnjectApp *> *apps;
@property (nonatomic, strong) NSArray<DOUnjectApp *> *filteredApps;
@property (nonatomic, strong) NSMutableSet<NSString *> *blacklistedIdentifiers;
@property (nonatomic, assign) BOOL enabled;

@end

@implementation DOUnjectController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.view.backgroundColor = [UIColor colorWithWhite:0.07 alpha:1.0];
    self.title = DOLocalizedString(@"Unject_Title");

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(donePressed)];

    _manager = [DOUnjectManager sharedManager];
    _enabled = _manager.enabled;
    [_manager reloadInstalledApps];
    _apps = _manager.installedApps;
    _filteredApps = _apps;
    _blacklistedIdentifiers = [[_manager blacklistedBundleIdentifiers] mutableCopy] ?: [NSMutableSet set];

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 60;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [_tableView registerClass:[DOUnjectAppCell class] forCellReuseIdentifier:@"app"];
    [self.view addSubview:_tableView];

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 52)];
    _searchBar.delegate = self;
    _searchBar.searchBarStyle = UISearchBarStyleMinimal;
    _searchBar.placeholder = DOLocalizedString(@"Unject_Search");
    _searchBar.tintColor = [UIColor colorWithRed:71.0/255.0 green:169.0/255.0 blue:135.0/255.0 alpha:1.0];
    _tableView.tableHeaderView = _searchBar;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    UIView *header = _tableView.tableHeaderView;
    if (header) {
        CGFloat width = _tableView.bounds.size.width;
        CGSize size = [header systemLayoutSizeFittingSize:CGSizeMake(width, CGFLOAT_MAX)];
        if (header.frame.size.width != width || header.frame.size.height != size.height) {
            header.frame = CGRectMake(0, 0, width, MAX(size.height, 52));
            _tableView.tableHeaderView = header;
        }
    }
}

#pragma mark - Actions

- (void)donePressed
{
    [self notifyChange];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)notifyChange
{
    if (self.onChange) self.onChange();
}

- (void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;
    [self.manager setEnabled:enabled];
    [self notifyChange];
}

- (void)setApp:(DOUnjectApp *)app blacklisted:(BOOL)blacklisted
{
    NSString *identifier = app.bundleIdentifier;
    if (!identifier.length) return;

    BOOL wasBlacklisted = [self.blacklistedIdentifiers containsObject:identifier];
    if (wasBlacklisted == blacklisted) return;

    if (blacklisted) {
        [self.blacklistedIdentifiers addObject:identifier];
    }
    else {
        [self.blacklistedIdentifiers removeObject:identifier];
    }

    BOOL success = [self.manager setApp:app blacklisted:blacklisted];
    if (!success) {
        if (wasBlacklisted) {
            [self.blacklistedIdentifiers addObject:identifier];
        }
        else {
            [self.blacklistedIdentifiers removeObject:identifier];
        }
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:DOLocalizedString(@"Log_Error") message:DOLocalizedString(@"Alert_Unject_Write_Failed") preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:DOLocalizedString(@"Button_Cancel") style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
    [self.tableView reloadData];
    [self notifyChange];
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) return 1;
    return self.filteredApps.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0) return nil;
    return [NSString stringWithFormat:DOLocalizedString(@"Unject_Count"), (unsigned long)self.blacklistedIdentifiers.count];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 0) return nil;
    return DOLocalizedString(@"Unject_Footer");
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"toggle"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"toggle"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
            cell.textLabel.text = DOLocalizedString(@"Settings_Unject_Enabled");
            UISwitch *toggle = [[UISwitch alloc] init];
            toggle.onTintColor = [UIColor colorWithRed:71.0/255.0 green:169.0/255.0 blue:135.0/255.0 alpha:1.0];
            [toggle addTarget:self action:@selector(globalToggleChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
        }
        UISwitch *toggle = (UISwitch *)cell.accessoryView;
        toggle.on = self.enabled;
        return cell;
    }

    DOUnjectAppCell *cell = [tableView dequeueReusableCellWithIdentifier:@"app" forIndexPath:indexPath];
    DOUnjectApp *app = self.filteredApps[indexPath.row];
    BOOL blacklisted = [self.blacklistedIdentifiers containsObject:app.bundleIdentifier];
    [cell configureWithApp:app blacklisted:blacklisted];

    __weak typeof(self) weakSelf = self;
    __weak DOUnjectAppCell *weakCell = cell;
    cell.onToggle = ^(BOOL enabled) {
        [weakSelf setApp:app blacklisted:enabled];
    };

    if (![app cachedIcon]) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            UIImage *icon = [app icon];
            dispatch_async(dispatch_get_main_queue(), ^{
                DOUnjectAppCell *visibleCell = weakCell;
                if (visibleCell && [visibleCell.bundleIdentifier isEqualToString:app.bundleIdentifier]) {
                    [visibleCell setIconImage:icon];
                }
            });
        });
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) return;

    DOUnjectApp *app = self.filteredApps[indexPath.row];
    [self setApp:app blacklisted:![self.blacklistedIdentifiers containsObject:app.bundleIdentifier]];
}

- (void)globalToggleChanged:(UISwitch *)toggle
{
    self.enabled = toggle.isOn;
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - Search

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    NSString *query = [searchText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!query.length) {
        self.filteredApps = self.apps;
    }
    else {
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(DOUnjectApp *app, NSDictionary *bindings) {
            return [app.name localizedCaseInsensitiveContainsString:query] || [app.bundleIdentifier localizedCaseInsensitiveContainsString:query];
        }];
        self.filteredApps = [self.apps filteredArrayUsingPredicate:predicate];
    }
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
}

@end
