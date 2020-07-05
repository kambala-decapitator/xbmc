/*
 *  Copyright (C) 2010-2018 Team Kodi
 *  This file is part of Kodi - https://kodi.tv
 *
 *  SPDX-License-Identifier: GPL-2.0-or-later
 *  See LICENSES/README.md for more information.
 */

#import "XBMCApplication.h"

#import "IOSScreenManager.h"
#import "XBMCController.h"

#import "platform/darwin/NSLogDebugHelpers.h"

#import <AVFoundation/AVAudioSession.h>

#include "AppInboundProtocol.h"
#include "AppParamParser.h"
#include "Application.h"
#include "messaging/ApplicationMessenger.h"
#include "ServiceBroker.h"
#include "settings/AdvancedSettings.h"
#include "settings/SettingsComponent.h"
#import "platform/darwin/ios-common/AnnounceReceiver.h"

@interface KodiSplashScreen : UIViewController
@end
@implementation KodiSplashScreen
- (void)loadView
{
    auto imagePath = [NSBundle.mainBundle pathForResource:@"splash" ofType:@"jpg"];
    auto imageView = [[UIImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:imagePath]];
    imageView.frame = UIApplication.sharedApplication.delegate.window.bounds;
    self.view = imageView;

    auto l = [[UILabel alloc] initWithFrame:CGRectMake(30, 30, 0, 0)];
    l.text = @"splash";
    l.textColor = UIColor.whiteColor;
    [l sizeToFit];
    [imageView addSubview:l];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    NSLog(@"%@\n%@", UIApplication.sharedApplication.delegate.window, self.view);
}
@end

@interface KodiThreadHandler : NSObject
@property (nonatomic, strong) NSConditionLock* lock;
@property (nonatomic, strong) NSThread* kodiThread;
- (void)stop;
@end


@implementation XBMCApplicationDelegate
{
    KodiThreadHandler *_th;
}

// - iOS6 rotation API - will be called on iOS7 runtime!--------
// - on iOS7 first application is asked for supported orientation
// - then the controller of the current view is asked for supported orientation
// - if both say OK - rotation is allowed
- (NSUInteger)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window
{
  return [[window rootViewController] supportedInterfaceOrientations];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
  PRINT_SIGNATURE();

  [g_xbmcController pauseAnimation];
  [g_xbmcController becomeInactive];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
  PRINT_SIGNATURE();

  [g_xbmcController resumeAnimation];
  [g_xbmcController enterForeground];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
  PRINT_SIGNATURE();

  if (application.applicationState == UIApplicationStateBackground)
  {
    // the app is turn into background, not in by screen lock which has app state inactive.
    [g_xbmcController enterBackground];
  }
}

- (void)applicationWillTerminate:(UIApplication *)application
{
  PRINT_SIGNATURE();

//  [g_xbmcController stopAnimation];
    [_th stop];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
  PRINT_SIGNATURE();
}

- (void)screenDidConnect:(NSNotification *)aNotification
{
  [IOSScreenManager updateResolutions];
}

- (void)screenDidDisconnect:(NSNotification *)aNotification
{
  [[IOSScreenManager sharedInstance] screenDisconnect];
}

- (void)registerScreenNotifications:(BOOL)bRegister
{
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

  if( bRegister )
  {
    //register to screen notifications
    [nc addObserver:self selector:@selector(screenDidConnect:) name:UIScreenDidConnectNotification object:nil];
    [nc addObserver:self selector:@selector(screenDidDisconnect:) name:UIScreenDidDisconnectNotification object:nil];
  }
  else
  {
    //deregister from screen notifications
    [nc removeObserver:self name:UIScreenDidConnectNotification object:nil];
    [nc removeObserver:self name:UIScreenDidDisconnectNotification object:nil];
  }
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(nullable NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions
{
  PRINT_SIGNATURE();

    self.window = [UIWindow new];

//  g_xbmcController = [XBMCController new];
//  [g_xbmcController startAnimation];

    self.window.rootViewController = [KodiSplashScreen new];
    [self.window makeKeyAndVisible];
//  [self registerScreenNotifications:YES];

  NSError *err = nil;
  if (![[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&err])
  {
    ELOG(@"AVAudioSession setCategory failed: %@", err);
  }
  err = nil;
  if (![[AVAudioSession sharedInstance] setActive: YES error: &err])
  {
    ELOG(@"AVAudioSession setActive failed: %@", err);
  }

    _th = [KodiThreadHandler new];

    return YES;
}

- (void)kodiInitialized {
    KODI::MESSAGING::CApplicationMessenger::GetInstance();
    dispatch_sync(dispatch_get_main_queue(), ^{
        g_xbmcController = [XBMCController new];
        self.window.rootViewController = g_xbmcController;
    });
    [g_xbmcController performSelector:@selector(prepareGL)];
}

- (NSArray<UIKeyCommand*>*)keyCommands
{
  @autoreleasepool
  {
    return @[
      [UIKeyCommand keyCommandWithInput:UIKeyInputUpArrow
                          modifierFlags:kNilOptions
                                 action:@selector(upPressed)],
      [UIKeyCommand keyCommandWithInput:UIKeyInputDownArrow
                          modifierFlags:kNilOptions
                                 action:@selector(downPressed)],
      [UIKeyCommand keyCommandWithInput:UIKeyInputLeftArrow
                          modifierFlags:kNilOptions
                                 action:@selector(leftPressed)],
      [UIKeyCommand keyCommandWithInput:UIKeyInputRightArrow
                          modifierFlags:kNilOptions
                                 action:@selector(rightPressed)]
    ];
  }
}

- (void)upPressed
{
  [g_xbmcController sendKey:XBMCK_UP];
}

- (void)downPressed
{
  [g_xbmcController sendKey:XBMCK_DOWN];
}

- (void)leftPressed
{
  [g_xbmcController sendKey:XBMCK_LEFT];
}

- (void)rightPressed
{
  [g_xbmcController sendKey:XBMCK_RIGHT];
}

@end


@implementation KodiThreadHandler

@synthesize lock = m_lock;
@synthesize kodiThread = m_kodiThread;

- (instancetype)init
{
    if (!(self = [super init]))
        return nil;

    m_lock = [[NSConditionLock alloc] initWithCondition:0];
    m_kodiThread = [[NSThread alloc] initWithTarget:self
                                           selector:@selector(runAnimation:)
                                             object:m_lock];
    [m_kodiThread start];

    return self;
}

- (void) runAnimation:(id) arg
{
    @autoreleasepool
    {
        [[NSThread currentThread] setName:@"Kodi_Run"];

        // set up some xbmc specific relationships
        auto readyToRun = true;

        // signal we are alive
        NSConditionLock* myLock = arg;
        [myLock lock];

        CAppParamParser appParamParser;
        //#ifdef _DEBUG
        //        appParamParser.m_logLevel = LOG_LEVEL_DEBUG;
        //#else
        //        appParamParser.m_logLevel = LOG_LEVEL_NORMAL;
        //#endif

        // Prevent child processes from becoming zombies on exit if not waited upon. See also Util::Command
        struct sigaction sa;
        memset(&sa, 0, sizeof(sa));
        sa.sa_flags = SA_NOCLDWAIT;
        sa.sa_handler = SIG_IGN;
        sigaction(SIGCHLD, &sa, NULL);

        setlocale(LC_NUMERIC, "C");

//        g_application.Preflight();
        if (!g_application.Create(appParamParser))
        {
            readyToRun = false;
            ELOG(@"%sUnable to create application", __PRETTY_FUNCTION__);
        }

        CAnnounceReceiver::GetInstance()->Initialize();

        XBMCApplicationDelegate* __block ad;
        dispatch_sync(dispatch_get_main_queue(), ^{
            ad = (XBMCApplicationDelegate*)UIApplication.sharedApplication.delegate;
        });
        [ad kodiInitialized];

        if (!g_application.CreateGUI())
        {
            readyToRun = false;
            ELOG(@"%sUnable to create GUI", __PRETTY_FUNCTION__);
        }

        if (!g_application.Initialize())
        {
            readyToRun = false;
            ELOG(@"%sUnable to initialize application", __PRETTY_FUNCTION__);
        }

        if (readyToRun)
        {
            CServiceBroker::GetSettingsComponent()->GetAdvancedSettings()->m_startFullScreen = true;
            CServiceBroker::GetSettingsComponent()->GetAdvancedSettings()->m_canWindowed = false;
            //            xbmcAlive = TRUE;
            [g_xbmcController onXbmcAlive];
            try
            {
                @autoreleasepool
                {
                    g_application.Run(CAppParamParser());
                }
            }
            catch (...)
            {
                ELOG(@"%sException caught on main loop. Exiting", __PRETTY_FUNCTION__);
            }
        }

        // signal we are dead
        [myLock unlockWithCondition:1];

        // grrr, xbmc does not shutdown properly and leaves
        // several classes in an indeterminate state, we must exit and
        // reload Lowtide/AppleTV, boo.
        [g_xbmcController enableScreenSaver];
        [g_xbmcController enableSystemSleep];
        exit(0);
    }
}

- (void)stop {
    if (!g_application.m_bStop)
    {
        KODI::MESSAGING::CApplicationMessenger::GetInstance().PostMsg(TMSG_QUIT);
    }

    CAnnounceReceiver::GetInstance()->DeInitialize();

    // wait for animation thread to die
    if ([self.kodiThread isFinished] == NO)
        [self.lock lockWhenCondition:1];
}

@end


static void SigPipeHandler(int s)
{
  NSLog(@"We Got a Pipe Signal: %d____________", s);
}

int main(int argc, char *argv[]) {
  @autoreleasepool
  {
    int retVal = 0;

    signal(SIGPIPE, SigPipeHandler);

    @try
    {
      retVal = UIApplicationMain(argc, argv, nil, NSStringFromClass(XBMCApplicationDelegate.class));
    }
    @catch (id theException)
    {
      ELOG(@"%@", theException);
    }
    @finally
    {
      ILOG(@"This always happens.");
    }

    return retVal;
  }
}
