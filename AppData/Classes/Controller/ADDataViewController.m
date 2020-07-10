//
//  ADDataViewController.m
//  AppData
//
//  Created by Fouad Raheb on 6/29/20.
//

#import "ADDataViewController.h"
#import "ADDataPresentationManager.h"
#import "ADAlertViewController.h"
#import <objc/runtime.h>

@interface ADDataViewController () <UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate>

@property (nonatomic, strong) ADDataPresentationManager *presentationManager;

@property (nonatomic, strong) UIVisualEffectView *contentView;

@property (nonatomic, strong) ADAppData *appData;
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UIButton *nameLabel;
@property (nonatomic, strong) UIButton *nameEditButton;
@property (nonatomic, strong) UIButton *identifierLabel;
@property (nonatomic, strong) UIButton *identifierCopyButton;
@property (nonatomic, strong) UILabel *versionLabel;
@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) UIButton *appStoreButton;

@property (nonatomic, assign) BOOL isCopyingIdentifier;

@end

@implementation ADDataViewController

- (instancetype)initWithAppData:(ADAppData *)data {
    if (self = [super init]) {
        ADDataPresentationConfiguration *config = [[ADDataPresentationConfiguration alloc] init];
        
        self.presentationManager = [[ADDataPresentationManager alloc] initWithConfiguration:config];
        
        self.transitioningDelegate = self.presentationManager;
        self.modalPresentationStyle = UIModalPresentationCustom;
        
        self.appData = data;

        [self initializeViews];
        
        [self configureViewWithAppData];
    }
    return self;
}

+ (void)presentControllerFromSBIconView:(SBIconView *)iconView fromContextMenu:(BOOL)contextMenu {
    if (!iconView) return;
    
    // Find Icon Image View
    SBIconImageView *_iconImageView = nil;
    if ([iconView respondsToSelector:@selector(_iconImageView)]) {
        _iconImageView = [iconView _iconImageView];
    } else {
        _iconImageView = object_getIvar(iconView, class_getInstanceVariable(object_getClass(iconView), [@"_iconImageView" UTF8String]));
    }
    if (!_iconImageView) {
        for (UIView *subview in iconView.subviews) {
            if ([subview isKindOfClass:NSClassFromString(@"SBIconImageView")]) {
                _iconImageView = (SBIconImageView *)subview;
                break;
            }
        }
    }
    
    [self presentControllerFromSBIconImageView:_iconImageView fromContextMenu:contextMenu];
}

+ (void)presentControllerFromSBIconImageView:(SBIconImageView *)iconImageView fromContextMenu:(BOOL)contextMenu {
    NSLog(@"iconImageView: %@",iconImageView);
    
    UIViewController *rootController = [iconImageView _viewControllerForAncestor];
    NSLog(@"rootController: %@",rootController);
        
    SBIconView *iconView = (SBIconView *)[iconImageView superview];
    if (![iconView isKindOfClass:NSClassFromString(@"SBIconView")]) {
        NSLog(@"iconView: %@",iconView);
        iconView = (SBIconView *)[iconView superview];
    }
    
    if ([iconView respondsToSelector:@selector(icon)]
        && [iconView.icon respondsToSelector:@selector(applicationBundleID)]
        && [iconImageView respondsToSelector:@selector(contentsImage)]) {
        SBIcon *icon = iconView.icon;
        NSString *bundleID = icon.applicationBundleID;
        ADAppData *appData = [ADAppData appDataForBundleIdentifier:bundleID iconImage:iconImageView.contentsImage];
        if (appData) {
            appData.iconView = iconView;
            
            [[UISelectionFeedbackGenerator new] selectionChanged];
            
            ADDataViewController *dataViewController = [[ADDataViewController alloc] initWithAppData:appData];
            // dataViewController.presentationManager.configuration.animationDuration = 3;
            
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                dataViewController.contentView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
                dataViewController.presentationManager.configuration.fadeAnimationAlpha = 0;
                dataViewController.presentationManager.configuration.fadeAnimation = YES;
                dataViewController.presentationManager.configuration.customFrameHandler = ^CGRect(UIView *containerView) {
                    CGSize size = CGSizeMake(containerView.frame.size.width * 0.5, containerView.frame.size.height * 0.5);
                    return CGRectMake(containerView.frame.size.width/2 - size.width/2,
                                      containerView.frame.size.height/2 - size.height/2,
                                      size.width, size.height);
                };
                if (contextMenu) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.4 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                        [ADHelper.sharedInstance.dockViewController?:rootController presentViewController:dataViewController animated:YES completion:nil];
                    });
                } else {
                    [ADHelper.sharedInstance.dockViewController?:rootController presentViewController:dataViewController animated:YES completion:nil];
                }
            } else {
                [rootController presentViewController:dataViewController animated:YES completion:nil];
            }
        }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismiss)];
    tapGesture.delegate = self;
    [self.view addGestureRecognizer:tapGesture];
    
    UISwipeGestureRecognizer *swipeUpDownGesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(dismiss)];
    swipeUpDownGesture.delegate = self;
    [swipeUpDownGesture setDirection:UISwipeGestureRecognizerDirectionDown | UISwipeGestureRecognizerDirectionUp];
    [self.view addGestureRecognizer:swipeUpDownGesture]; 
}

- (void)dismiss {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([touch.view isKindOfClass:NSClassFromString(@"UITableViewCellContentView")]) {
        return NO;
    }
    return YES;
}

- (void)configureViewWithAppData {
    self.iconImageView.image = self.appData.iconImage;
    self.appStoreButton.hidden = ![self.appData hasAppStoreApp];
    
    if ([self.appData isApplication]) {
        NSString *customIconName = self.appData.customIconName;
        [self.nameLabel setTitle:customIconName?:self.appData.name forState:UIControlStateNormal];
        [self.identifierLabel setTitle:self.appData.bundleIdentifier forState:UIControlStateNormal];
        if (self.appData.diskUsage > 0 && self.appData.diskUsageString) {
            self.versionLabel.text = [self.appData.version stringByAppendingFormat:@"  —  %@",self.appData.diskUsageString];
        } else {
            self.versionLabel.text = self.appData.version;
        }
    } else {
        [self.nameLabel setTitle:@"Not an Application" forState:UIControlStateNormal];
        [self.nameLabel setEnabled:NO];
        
        [self.identifierLabel setTitle:@"No Bundle Identifier" forState:UIControlStateNormal];
        [self.identifierLabel setEnabled:NO];
        
        [self.versionLabel setText:@"—"];
        
        self.identifierCopyButton.hidden = YES;
        self.nameEditButton.hidden = YES;
    }
}

- (void)initializeViews {
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]; // UIBlurEffectStyleRegular - Auto
    self.contentView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentView.clipsToBounds = YES;
    self.contentView.layer.cornerRadius = 15;
    self.contentView.layer.maskedCorners = kCALayerMaxXMinYCorner | kCALayerMinXMinYCorner;
    [self.view addSubview:self.contentView];
    [self pinView:self.contentView toAnchorsOfView:self.view];
    
    UIView *containerView = [UIView new];
    containerView.backgroundColor = [UIColor clearColor];
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView.contentView addSubview:containerView];
    [self pinView:containerView toAnchorsOfView:self.contentView.contentView];

    [self addSubviewsToContainer:containerView];
}

- (void)addSubviewsToContainer:(UIView *)containerView {
    
    UIColor *secondaryLabelsColor = [UIColor colorWithRed:0.922 green:0.922 blue:0.961 alpha:0.6];
    UIColor *buttonsSymbolColor = secondaryLabelsColor; //[UIColor colorWithRed:127/255.f green:140/255.f blue:141/255.f alpha:0.6];
    
    self.appStoreButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.appStoreButton setImage:[[ADHelper imageNamed:@"AppStoreButton"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    [self.appStoreButton setTintColor:buttonsSymbolColor];
    [self.appStoreButton addTarget:self action:@selector(didTapAppStoreButton:) forControlEvents:UIControlEventTouchUpInside];
    self.appStoreButton.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:self.appStoreButton];
    [self.appStoreButton.topAnchor constraintEqualToAnchor:containerView.topAnchor constant:9].active = YES;
    [self.appStoreButton.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-9].active = YES;
    [self.appStoreButton setContentEdgeInsets:UIEdgeInsetsMake(6, 6, 6, 6)];
    [self.appStoreButton.heightAnchor constraintEqualToConstant:30].active = YES;
    [self.appStoreButton.widthAnchor constraintEqualToConstant:30].active = YES;
    
    self.iconImageView = [[UIImageView alloc] init];
    [self.iconImageView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [containerView addSubview:self.iconImageView];
    [self.iconImageView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:15].active = YES;
    [self.iconImageView.topAnchor constraintEqualToAnchor:containerView.topAnchor constant:15].active = YES;
    [self.iconImageView.widthAnchor constraintEqualToConstant:58].active = YES;
    [self.iconImageView.heightAnchor constraintEqualToConstant:58].active = YES;
    
    self.nameLabel = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.nameLabel addTarget:self action:@selector(didTapNameButton:) forControlEvents:UIControlEventTouchUpInside];
    self.nameLabel.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.nameLabel.titleLabel.font = [UIFont systemFontOfSize:17];
    [self.nameLabel setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.nameLabel setTitle:@"-" forState:UIControlStateNormal];
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:self.nameLabel];
    [self.nameLabel.topAnchor constraintEqualToAnchor:containerView.topAnchor constant:15].active = YES;
    [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.iconImageView.trailingAnchor constant:11].active = YES;
    [self.nameLabel.heightAnchor constraintEqualToConstant:22].active = YES;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithWeight:UIImageSymbolWeightBold];
        UIImage *image = [[UIImage systemImageNamed:@"square.and.pencil" withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.nameEditButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [self.nameEditButton setImage:image forState:UIControlStateNormal];
        [self.nameEditButton setTintColor:buttonsSymbolColor];
        [self.nameEditButton addTarget:self action:@selector(didTapNameButton:) forControlEvents:UIControlEventTouchUpInside];
        [self.nameEditButton setTranslatesAutoresizingMaskIntoConstraints:NO];
        [containerView addSubview:self.nameEditButton];
        [self.nameEditButton setContentEdgeInsets:UIEdgeInsetsMake(4.75, 4.75, 4.75, 4.75)];
        [self.nameEditButton.heightAnchor constraintEqualToConstant:22].active = YES;
        [self.nameEditButton.widthAnchor constraintEqualToConstant:22].active = YES;
        [self.nameEditButton.centerYAnchor constraintEqualToAnchor:self.nameLabel.centerYAnchor].active = YES;
        [self.nameEditButton.leadingAnchor constraintEqualToAnchor:self.nameLabel.trailingAnchor constant:2].active = YES;
        
        [self.nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.appStoreButton.leadingAnchor constant:- (22 + 11)].active = YES;
    } else {
        [self.nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.appStoreButton.trailingAnchor constant:- 11].active = YES;
    }
    
    self.identifierLabel = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.identifierLabel addTarget:self action:@selector(didTapIdentifierButton:) forControlEvents:UIControlEventTouchUpInside];
    self.identifierLabel.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.identifierLabel setTitleColor:secondaryLabelsColor forState:UIControlStateNormal];
    [self.identifierLabel setTitle:@"-" forState:UIControlStateNormal];
    self.identifierLabel.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.identifierLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:self.identifierLabel];
    [self.identifierLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:2].active = YES;
    [self.identifierLabel.leadingAnchor constraintEqualToAnchor:self.iconImageView.trailingAnchor constant:11].active = YES;
    [self.identifierLabel.heightAnchor constraintEqualToConstant:20.16].active = YES;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithWeight:UIImageSymbolWeightBold];
        UIImage *image = [[UIImage systemImageNamed:@"doc.on.clipboard" withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.identifierCopyButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [self.identifierCopyButton setImage:image forState:UIControlStateNormal];
        [self.identifierCopyButton setTintColor:buttonsSymbolColor];
        [self.identifierCopyButton addTarget:self action:@selector(didTapIdentifierButton:) forControlEvents:UIControlEventTouchUpInside];
        [self.identifierCopyButton setTranslatesAutoresizingMaskIntoConstraints:NO];
        [containerView addSubview:self.identifierCopyButton];
        [self.identifierCopyButton setContentEdgeInsets:UIEdgeInsetsMake(5, 5, 5, 5)];
        [self.identifierCopyButton.heightAnchor constraintEqualToConstant:22].active = YES;
        [self.identifierCopyButton.widthAnchor constraintEqualToConstant:22].active = YES;
        [self.identifierCopyButton.centerYAnchor constraintEqualToAnchor:self.identifierLabel.centerYAnchor].active = YES;
        [self.identifierCopyButton.leadingAnchor constraintEqualToAnchor:self.identifierLabel.trailingAnchor constant:1].active = YES;
        
        [self.identifierLabel.trailingAnchor constraintLessThanOrEqualToAnchor:containerView.trailingAnchor constant:- (22 + 11)].active = YES;
    } else {
        [self.identifierLabel.trailingAnchor constraintLessThanOrEqualToAnchor:containerView.trailingAnchor constant:- 11].active = YES;
    }
    
    self.versionLabel = [[UILabel alloc] init];
    self.versionLabel.font = [UIFont systemFontOfSize:13];
    self.versionLabel.textColor = secondaryLabelsColor;
    self.versionLabel.text = @"-";
    self.versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:self.versionLabel];
    [self.versionLabel.topAnchor constraintEqualToAnchor:self.identifierLabel.bottomAnchor].active = YES;
    [self.versionLabel.leadingAnchor constraintEqualToAnchor:self.iconImageView.trailingAnchor constant:11].active = YES;
    [self.versionLabel.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-11].active = YES;
    [self.versionLabel.heightAnchor constraintEqualToConstant:20.16].active = YES;
    
    // Create Table View
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    // self.tableView.bounces = NO;
    self.tableView.separatorColor = [UIColor colorWithRed:0.329 green:0.329 blue:0.345 alpha:0.6];
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.tableFooterView = [UIView new];
    [containerView addSubview:self.tableView];
    [self.tableView.topAnchor constraintEqualToAnchor:self.iconImageView.bottomAnchor constant:15].active = YES;
    [self.tableView.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor].active = YES;
    [self.tableView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor].active = YES;
    [self.tableView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor].active = YES;
}

- (void)pinView:(UIView *)view toAnchorsOfView:(UIView *)superview {
    [view.topAnchor constraintEqualToAnchor:superview.topAnchor].active = YES;
    [view.bottomAnchor constraintEqualToAnchor:superview.bottomAnchor].active = YES;
    [view.leadingAnchor constraintEqualToAnchor:superview.leadingAnchor].active = YES;
    [view.trailingAnchor constraintEqualToAnchor:superview.trailingAnchor].active = YES;
}

- (void)didTapNameButton:(UIButton *)button {
    [[UISelectionFeedbackGenerator new] selectionChanged];
    [self showCustomIconNameInterface];
}

- (void)didTapIdentifierButton:(UIButton *)button {
    if (!self.isCopyingIdentifier) {
        self.isCopyingIdentifier = YES;
        
        NSString *currentTitle = self.identifierLabel.titleLabel.text;
        [[UIPasteboard generalPasteboard] setString:currentTitle?:@""];
        
        [self.identifierLabel setTitle:@"Copied to clipboard" forState:UIControlStateNormal];
        
        [[UINotificationFeedbackGenerator new] notificationOccurred:UINotificationFeedbackTypeSuccess];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.7 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self.identifierLabel setTitle:currentTitle forState:UIControlStateNormal];
            self.isCopyingIdentifier = NO;
        });
    }
}

- (void)didTapAppStoreButton:(UIButton *)button {
    [self.appData openInAppStore];
}

#pragma mark - UITableView Delegate/DataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (!self.appData) {
        return 0;
    }
    return 3;
}

- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ([self isContainersSection:section]) {
        NSInteger rows = 0;
        if (self.appData.bundleContainerURL) rows++;
        if (self.appData.dataContainerURL) rows++;
        return rows;
    } else if ([self isAppGroupsSection:section]) {
        return self.appData.appGroups.count;
    } else if ([self isManageSection:section]) {
        return 2;
    }
    return 0;
}

- (BOOL)isManageSection:(NSInteger)section {
    return section == 0;
}
- (BOOL)isContainersSection:(NSInteger)section {
    return section == 1;
}
- (BOOL)isAppGroupsSection:(NSInteger)section {
    return section == 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isContainersSection:indexPath.section] || [self isAppGroupsSection:indexPath.section]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"InfoCellIdentifier"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"InfoCellIdentifier"];
            [self applySharedStylesToCell:cell];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
            cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
            cell.detailTextLabel.textColor = [UIColor colorWithRed:0.922 green:0.922 blue:0.961 alpha:0.6];
        }
        if ([self isContainersSection:indexPath.section]) {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Bundle";
                cell.detailTextLabel.text = self.appData.bundleContainerURL.path;
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"Data";
                cell.detailTextLabel.text = self.appData.dataContainerURL.path;
            }
        } else if ([self isAppGroupsSection:indexPath.section]) {
            ADAppDataGroup *group = [self.appData.appGroups objectAtIndex:indexPath.row];
            cell.textLabel.text = group.identifier;
            cell.detailTextLabel.text = group.url.path;
        }
        return cell;
    } else if ([self isManageSection:indexPath.section]) {
        if (indexPath.row == 0) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CachesCellIdentifier"];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"CachesCellIdentifier"];
                [self applySharedStylesToCell:cell];
                UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
                [activityIndicatorView startAnimating];
                cell.accessoryView = activityIndicatorView;
                [self.appData getCachesDirectorySizeWithCompletion:^(NSString *formattedSize) {
                    cell.detailTextLabel.text = formattedSize;
                    [activityIndicatorView stopAnimating];
                    [activityIndicatorView removeFromSuperview];
                    cell.accessoryView = nil;
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                }];
            }
            cell.textLabel.text = @"Clear Caches";
            return cell;
        } else {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ManageCellIdentifier"];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"ManageCellIdentifier"];
                [self applySharedStylesToCell:cell];
            }
            if (indexPath.row == 1) {
                cell.textLabel.text = @"Clear Badge";
                NSInteger badgeCount = [self.appData appBadgeCount];
                cell.detailTextLabel.text = badgeCount == 0 ? @"" : [NSString stringWithFormat:@"%td",badgeCount];
            }
            return cell;
        }
    }
    return nil;
}

- (void)applySharedStylesToCell:(UITableViewCell *)cell {
    cell.detailTextLabel.textColor = [UIColor colorWithRed:0.557 green:0.557 blue:0.576 alpha:1.0];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.font = [UIFont systemFontOfSize:15];
    
    cell.backgroundColor = [UIColor clearColor];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    UIView *selectedBackgroundView = [[UIView alloc] init];
    selectedBackgroundView.backgroundColor = [[UIColor lightGrayColor] colorWithAlphaComponent:0.15];
    cell.selectedBackgroundView = selectedBackgroundView;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if ([self isContainersSection:section]) {
        return self.appData.isApplication ? @"Containers" : nil;
    } else if ([self isAppGroupsSection:section]) {
        return !self.appData.appGroups || self.appData.appGroups.count == 0 ? nil : @"App Groups";
    } else if ([self isManageSection:section]) {
        return @"Manage";
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isManageSection:indexPath.section]) {
        return 45;
    }
    return 50;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 25;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if ([self isContainersSection:indexPath.section] || [self isAppGroupsSection:indexPath.section]) {
        [self didSelectContainerOrAppGroupSectionAtIndexPath:indexPath];
    } else if ([self isManageSection:indexPath.section]) {
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        if (indexPath.row == 0) {
            UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
            [activityIndicatorView startAnimating];
            cell.accessoryView = activityIndicatorView;
            [self.appData clearAppCachesWithCompletion:^() {
                [self.appData getCachesDirectorySizeWithCompletion:^(NSString *formattedSize) {
                    cell.detailTextLabel.text = formattedSize;
                    cell.accessoryView = nil;
                }];
            }];
        } else if (indexPath.row == 1) {
            [self.appData setAppBadgeCount:0];
            cell.detailTextLabel.text = @"";
        }
    }
}

- (void)showCustomIconNameInterface {
    ADAlertViewController *controller = [[ADAlertViewController alloc] init];
    NSMutableArray *buttons = [NSMutableArray new];
    [buttons addObject:[ADAlertButton buttonWithTitle:@"Cancel" style:ADButtonStyleCancel handler:nil]];
    [buttons addObject:[ADAlertButton buttonWithTitle:@"Reset" style:ADButtonStyleDefault handler:^(UIButton *button) {
        [self.appData setCustomIconName:nil];
        [self.nameLabel setTitle:self.appData.name forState:UIControlStateNormal];
    }]];
    [buttons addObject:[ADAlertButton buttonWithTitle:@"Change" style:ADButtonStyleDefault handler:^(UIButton *button) {
        [self.appData setCustomIconName:controller.textfield.text];
        [self.nameLabel setTitle:self.appData.name forState:UIControlStateNormal];
    }]];
    controller.buttons = buttons;
    controller.titleText = @"Rename";
    controller.detailText = @"Enter an app icon name";
    [controller addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = self.nameLabel.titleLabel.text;
    }];
    
    ADAlertViewController __weak *weakController = controller;
    [controller.presentationManager.configuration setCustomFrameHandler:^CGRect(UIView *containerView) {
        CGSize size = CGSizeMake(300, [weakController requiredHeight]);
        return CGRectMake(containerView.frame.size.width/2 - size.width/2,
                          containerView.frame.size.height/2 - size.height/2,
                          size.width, size.height);
    }];
    [self presentViewController:controller animated:YES completion:nil];
}

- (void)didSelectContainerOrAppGroupSectionAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isContainersSection:indexPath.section]) {
        if (indexPath.row == 0) {
            if (self.appData.bundleContainerURL) {
                [self openURL:self.appData.bundleContainerURL];
            }
        } else if (indexPath.row == 1) {
            if (self.appData.dataContainerURL) {
                [self openURL:self.appData.dataContainerURL];
            }
        }
    } else if ([self isAppGroupsSection:indexPath.section]) {
        ADAppDataGroup *group = [self.appData.appGroups objectAtIndex:indexPath.row];
        if (group.url) {
            [self openURL:group.url];
        }
    }
}

#pragma mark - Copy Action

- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    return (action == @selector(copy:));
}

- (void)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    if (action == @selector(copy:)) {
        if ([self isContainersSection:indexPath.section] || [self isAppGroupsSection:indexPath.section]) {
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            if (cell.detailTextLabel.text) [[UIPasteboard generalPasteboard] setString:cell.detailTextLabel.text];
        }
    }
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point  API_AVAILABLE(ios(13.0)) {
    if ([self isContainersSection:indexPath.section] || [self isAppGroupsSection:indexPath.section]) {
        UIContextMenuConfiguration *configuration = [UIContextMenuConfiguration configurationWithIdentifier:indexPath
                                                                                            previewProvider:nil
                                                                                             actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
            NSMutableArray *actions = [NSMutableArray new];
            [actions addObject:[UIAction actionWithTitle:@"Open in Filza" image:nil identifier:@"open-action" handler:^(__kindof UIAction * _Nonnull action) {
                [self didSelectContainerOrAppGroupSectionAtIndexPath:indexPath];
            }]];
            [actions addObject:[UIAction actionWithTitle:@"Copy Path" image:nil identifier:@"copy-action" handler:^(__kindof UIAction * _Nonnull action) {
                UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
                if (cell.detailTextLabel.text) [[UIPasteboard generalPasteboard] setString:cell.detailTextLabel.text];
            }]];
            if ([self isAppGroupsSection:indexPath.section]) {
                [actions addObject:[UIAction actionWithTitle:@"Copy Identifier" image:nil identifier:@"copy-action" handler:^(__kindof UIAction * _Nonnull action) {
                    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
                    if (cell.textLabel.text) [[UIPasteboard generalPasteboard] setString:cell.textLabel.text];
                }]];
            }
            NSString *title = @"";
            if ([self isContainersSection:indexPath.section]) {
                if (indexPath.row == 0) title = @"Bundle";
                else if (indexPath.row == 1) title = @"Data";
            } else if ([self isAppGroupsSection:indexPath.section]) {
                title = @"App Group";
            }
            return [UIMenu menuWithTitle:title children:actions];
        }];
        return configuration;
    }
    return nil;
}

- (UITargetedPreview *)tableView:(UITableView *)tableView previewForHighlightingContextMenuWithConfiguration:(UIContextMenuConfiguration *)configuration API_AVAILABLE(ios(13.0)) {
    NSIndexPath *indexPath = (NSIndexPath *)[configuration identifier];
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    UIPreviewParameters *parameters = [UIPreviewParameters new];
    parameters.backgroundColor = [UIColor clearColor];
    if ([self isAppGroupsSection:indexPath.section]) {
        return [[UITargetedPreview alloc] initWithView:cell parameters:parameters];
    } else {
        return [[UITargetedPreview alloc] initWithView:cell.detailTextLabel parameters:parameters];
    }
}

- (nullable UITargetedPreview *)tableView:(UITableView *)tableView previewForDismissingContextMenuWithConfiguration:(UIContextMenuConfiguration *)configuration API_AVAILABLE(ios(13.0)) {
    return [self tableView:tableView previewForHighlightingContextMenuWithConfiguration:configuration];
}

#pragma mark - Helper

- (void)openURL:(NSURL *)url {
    BOOL filzaInstalled = [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"filza://"]];
    BOOL ifileInstalled = [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"ifile://"]];
    if (filzaInstalled) {
        NSURL *filzaURL = [NSURL URLWithString:[@"filza://view" stringByAppendingString:url.path]];
        [[UIApplication sharedApplication] openURL:filzaURL options:@{} completionHandler:nil];
    } else if (ifileInstalled) {
        NSURL *ifileURL = [NSURL URLWithString:[@"ifile://file://" stringByAppendingString:url.path]];
        [[UIApplication sharedApplication] openURL:ifileURL options:@{} completionHandler:nil];
    }
}

@end
