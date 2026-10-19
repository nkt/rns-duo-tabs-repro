// Plain UIKit reproduction (no React Native): the side-rail tab bar is missing after a cold launch on
// the unfolded iPhone Duo simulator (Xcode 27.1, iOS 27.1).
//
// It mirrors the order react-native-screens uses for its tabs host:
//   1. a UITabBarController is created detached, its view is loaded (UIKit sizes it to the main screen,
//      which is the 466x678 cover display) and its tabs are set;
//   2. the controller is added as a child of a container that is already on screen, its view is added to
//      a host subview WITHOUT setting a frame first, and pinned to the host with Auto Layout.
// The later resize to the 951x669 inner display changes no size class, and UIKit never builds the rail's
// floating bar (_UIFloatingBarContainerView under _UITabContainerView).
//
// Launch with the environment variable PREFRAME=1 to set tbc.view.frame = host.bounds before the
// addSubview: the rail tab bar then shows up on every launch.
//
// Build: ./build.sh   Run: ./run.sh <simulator-udid>   (see README.md)

#import <UIKit/UIKit.h>

static NSFileHandle *gLog = nil;

static void Log(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);
static void Log(NSString *fmt, ...)
{
  va_list ap;
  va_start(ap, fmt);
  NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
  va_end(ap);
  NSLog(@"REPRO %@", msg);
  [gLog writeData:[[msg stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
}

static BOOL PreframeEnabled(void)
{
  return [NSProcessInfo.processInfo.environment[@"PREFRAME"] isEqualToString:@"1"];
}

static UIView *FindViewOfClass(UIView *root, NSString *className)
{
  if ([NSStringFromClass(root.class) isEqualToString:className]) return root;
  for (UIView *subview in root.subviews) {
    UIView *found = FindViewOfClass(subview, className);
    if (found) return found;
  }
  return nil;
}

static NSArray<UITab *> *MakeTabs(void)
{
  NSArray *titles = @[ @"Home", @"Search", @"Settings" ];
  NSArray *symbols = @[ @"house", @"magnifyingglass", @"gear" ];
  NSMutableArray *tabs = [NSMutableArray array];
  for (NSUInteger i = 0; i < titles.count; i++) {
    UIViewController *vc = [UIViewController new];
    vc.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    UILabel *label = [UILabel new];
    label.text = [NSString stringWithFormat:@"%@ (PREFRAME=%d)", titles[i], PreframeEnabled()];
    label.font = [UIFont boldSystemFontOfSize:28];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
      [label.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
      [label.centerYAnchor constraintEqualToAnchor:vc.view.centerYAnchor],
    ]];
    UITab *tab = [[UITab alloc] initWithTitle:titles[i]
                                        image:[UIImage systemImageNamed:symbols[i]]
                                   identifier:titles[i]
                       viewControllerProvider:^UIViewController *(UITab *t) { return vc; }];
    tab.preferredPlacement = UITabPlacementFixed;  // as react-native-screens does
    [tabs addObject:tab];
  }
  return tabs;
}

#pragma mark - Container (stands in for RNSTabsHostComponentView and its parent)

@interface Container : UIViewController
@property (nonatomic, strong) UITabBarController *tbc;
@end

@implementation Container

- (void)viewDidLoad
{
  [super viewDidLoad];
  UIView *host = [[UIView alloc] initWithFrame:self.view.bounds];
  host.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [self.view addSubview:host];

  [self addChildViewController:self.tbc];
  Log(@"attach: tbc.view.frame=%@ host.bounds=%@ PREFRAME=%d", NSStringFromCGRect(self.tbc.view.frame),
      NSStringFromCGRect(host.bounds), PreframeEnabled());
  if (PreframeEnabled()) {
    self.tbc.view.frame = host.bounds;  // <- the fix
  }
  [host addSubview:self.tbc.view];
  self.tbc.view.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [self.tbc.view.topAnchor constraintEqualToAnchor:host.topAnchor],
    [self.tbc.view.bottomAnchor constraintEqualToAnchor:host.bottomAnchor],
    [self.tbc.view.leadingAnchor constraintEqualToAnchor:host.leadingAnchor],
    [self.tbc.view.trailingAnchor constraintEqualToAnchor:host.trailingAnchor],
  ]];
  [self.tbc didMoveToParentViewController:self];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
    // Health check. Do not use tabBar.subviews.count: a healthy rail bar can report 0 subviews too.
    UIView *floatingBar = FindViewOfClass(self.tbc.view, @"_UIFloatingBarContainerView");
    Log(@"RESULT %@ window=%@ tabBar.frame=%@ hidden=%d", floatingBar ? @"HEALTHY" : @"BROKEN",
        NSStringFromCGRect(self.view.window.bounds), NSStringFromCGRect(self.tbc.tabBar.frame),
        self.tbc.isTabBarHidden);
  });
}

@end

#pragma mark - Scene delegate

@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation SceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options
{
  self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
  Log(@"launch: window.bounds=%@ main screen=%@", NSStringFromCGRect(self.window.bounds),
      NSStringFromCGRect(UIScreen.mainScreen.bounds));

  // The app's root navigation controller is on screen first (like a native stack / splash).
  UIViewController *placeholder = [UIViewController new];
  placeholder.view.backgroundColor = UIColor.systemGrayColor;
  UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:placeholder];
  nav.navigationBarHidden = YES;
  self.window.rootViewController = nav;
  [self.window makeKeyAndVisible];

  dispatch_async(dispatch_get_main_queue(), ^{
    // Tabs installed while the controller is detached, its view already loaded.
    UITabBarController *tbc = [UITabBarController new];
    [tbc loadViewIfNeeded];
    [tbc setTabs:MakeTabs() animated:NO];
    Container *container = [Container new];
    container.tbc = tbc;
    [nav setViewControllers:@[ container ] animated:NO];
  });
}

@end

#pragma mark - App delegate

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  return YES;
}

- (UISceneConfiguration *)application:(UIApplication *)application
    configurationForConnectingSceneSession:(UISceneSession *)session
                                   options:(UISceneConnectionOptions *)options
{
  UISceneConfiguration *config = [[UISceneConfiguration alloc] initWithName:@"Default" sessionRole:session.role];
  config.delegateClass = SceneDelegate.class;
  return config;
}

@end

int main(int argc, char *argv[])
{
  @autoreleasepool {
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    [NSFileManager.defaultManager createDirectoryAtPath:docs withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *path = [docs stringByAppendingPathComponent:@"log.txt"];
    [NSFileManager.defaultManager createFileAtPath:path contents:nil attributes:nil];  // truncated per launch
    gLog = [NSFileHandle fileHandleForWritingAtPath:path];
    return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class));
  }
}
