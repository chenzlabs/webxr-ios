#import "MessageController.h"
#import "XRViewer-Swift.h"
#import <PopupDialog/PopupDialog-Swift.h>

#include "Constants.h"

#warning LOCALIZATION

@interface MessageController ()
@property(nonatomic, weak) UIViewController *viewController;
@property(nonatomic, weak) PopupDialog *arPopup;
@end

@implementation MessageController

- (void)dealloc
{
    DDLogDebug(@"MessageController dealloc");
}

- (instancetype)initWithViewController:(UIViewController *)vc
{
    self = [super init];
    
    if (self)
    {
        [self setViewController:vc];
        
        [self setupAppearance];
    }
    
    return self;
}

- (void)clean
{
    if ([self arPopup])
    {
        [[self arPopup] dismissViewControllerAnimated:NO completion:NULL];
        
        [self setArPopup:nil];
    }
    
    if ([[self viewController] presentedViewController])
    {
        [[[self viewController] presentedViewController] dismissViewControllerAnimated:NO completion:NULL];
    }
}

- (BOOL)arMessageShowing
{
    return [self arPopup] != nil;
}

- (void)showMessageAboutWebError:(NSError *)error withCompletion:(void(^)(BOOL reload))reloadCompletion;
{
    PopupDialog *popup = [[PopupDialog alloc] initWithTitle:@"Can not open the page"
                                                    message:@"Please check the URL and try again"
                                                      image:nil
                                            buttonAlignment:UILayoutConstraintAxisHorizontal
                                            transitionStyle:PopupDialogTransitionStyleBounceUp
                                             preferredWidth:200.0
                                           gestureDismissal:NO
                                              hideStatusBar:TRUE
                                                 completion:^{}
                          ];
    
    DestructiveButton *cancel = [[DestructiveButton alloc] initWithTitle:@"Ok" height:40 dismissOnTap:YES action:^
                                 {
                                     reloadCompletion(NO);
                                     
                                     [self didHideMessageByUser]();
                                 }];
    
    DefaultButton *ok = [[DefaultButton alloc] initWithTitle:@"Reload" height:40 dismissOnTap:YES action:^
                         {
                             reloadCompletion(YES);
                             
                             [self didHideMessageByUser]();
                         }];
    
    [popup addButtons: @[cancel, ok]];
    
    [[self viewController] presentViewController:popup animated:YES completion:nil];
    
    [self didShowMessage]();
}

- (void)showMessageAboutARInterruption:(BOOL)interrupt
{
    if (interrupt && _arPopup == nil)
    {
        PopupDialog *popup = [[PopupDialog alloc] initWithTitle:@"AR Interruption Occurred"
                                                        message:@"Please wait, it would be fixed automatically"
                                                          image:nil
                                                buttonAlignment:UILayoutConstraintAxisHorizontal
                                                transitionStyle:PopupDialogTransitionStyleBounceUp
                                                 preferredWidth:200.0
                                               gestureDismissal:NO
                                                  hideStatusBar:TRUE
                                                     completion:^{}
                              ];
        
        [self setArPopup:popup];
        
        [[self viewController] presentViewController:popup animated:YES completion:nil];
        
        [self didShowMessage]();
    }
    else if (interrupt == NO && _arPopup)
    {
        [_arPopup dismissViewControllerAnimated:YES completion:NULL];
        
        [self setArPopup:nil];
        
        [self didHideMessage]();
    }
}

- (void)showMessageWithTitle:(NSString*)title message:(NSString*)message hideAfter:(NSInteger)seconds {
    PopupDialog *popup = [[PopupDialog alloc] initWithTitle:title
                                                    message:message
                                                      image:nil
                                            buttonAlignment:UILayoutConstraintAxisHorizontal
                                            transitionStyle:PopupDialogTransitionStyleZoomIn
                                             preferredWidth:200.0
                                           gestureDismissal:NO
                                              hideStatusBar:TRUE
                                                 completion:^{}
                          ];
    
    [[self viewController] presentViewController:popup animated:YES completion:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [popup dismissViewControllerAnimated:YES completion:nil];
    });
}

- (void)showMessageAboutFailSessionWithMessage: (NSString*)message completion:(void(^)(void))completion
{
    PopupDialog *popup = [[PopupDialog alloc] initWithTitle:@"AR Session Failed"
                                                    message:message
                                                      image:nil
                                            buttonAlignment:UILayoutConstraintAxisHorizontal
                                            transitionStyle:PopupDialogTransitionStyleBounceUp
                                             preferredWidth:200.0
                                           gestureDismissal:NO
                                              hideStatusBar:TRUE
                                                 completion:^{}
    ];

    DefaultButton *ok = [[DefaultButton alloc] initWithTitle:@"Ok" height:40 dismissOnTap:YES action:^
    {
        [popup dismissViewControllerAnimated:YES completion:NULL];

        [self didHideMessageByUser]();

        completion();
    }];

    [popup addButtons: @[ok]];

    [[self viewController] presentViewController:popup animated:YES completion:nil];

    [self didShowMessage]();

}

- (void)showMessageAboutFailSessionWithCompletion:(void(^)(void))completion
{
    PopupDialog *popup = [[PopupDialog alloc] initWithTitle:@"AR Session Failed"
                                                    message:@"Tap 'Ok' to restart the session"
                                                      image:nil
                                            buttonAlignment:UILayoutConstraintAxisHorizontal
                                            transitionStyle:PopupDialogTransitionStyleBounceUp
                                             preferredWidth:200.0
                                           gestureDismissal:NO
                                              hideStatusBar:TRUE
                                                 completion:^{}
                          ];
    
    DefaultButton *ok = [[DefaultButton alloc] initWithTitle:@"Ok" height:40 dismissOnTap:YES action:^
                         {
                             [popup dismissViewControllerAnimated:YES completion:NULL];
                             
                             [self didHideMessageByUser]();
                             
                             completion();
                         }];
    
    [popup addButtons: @[ok]];
    
    [[self viewController] presentViewController:popup animated:YES completion:nil];
    
    [self didShowMessage]();
    
}

- (void)showMessageAboutMemoryWarningWithCompletion:(void(^)(void))completion
{
    PopupDialog *popup = [[PopupDialog alloc] initWithTitle:@"Memory Issue Occurred"
                                                    message:@"There was not enough memory for the application to keep working"
                                                      image:nil
                                            buttonAlignment:UILayoutConstraintAxisHorizontal
                                            transitionStyle:PopupDialogTransitionStyleBounceUp
                                             preferredWidth:200.0
                                           gestureDismissal:NO
                                              hideStatusBar:TRUE
                                                 completion:^{}
                          ];
    
    DefaultButton *ok = [[DefaultButton alloc] initWithTitle:@"Ok" height:40 dismissOnTap:YES action:^
                         {
                             [popup dismissViewControllerAnimated:YES completion:NULL];
                             
                             if (completion)
                             {
                                 completion();
                             }
                             
                             [self didHideMessageByUser]();
                         }];
    
    [popup addButtons: @[ok]];
    
    [[self viewController] presentViewController:popup animated:YES completion:nil];
    
    [self didShowMessage]();
}

- (void)showMessageAboutConnectionRequired
{
    PopupDialog *popup = [[PopupDialog alloc] initWithTitle:@"Internet connection is not available now"
                                                    message:@"Application will be started automatically when connection become available"
                                                      image:nil
                                            buttonAlignment:UILayoutConstraintAxisHorizontal
                                            transitionStyle:PopupDialogTransitionStyleBounceUp
                                             preferredWidth:200.0
                                           gestureDismissal:NO
                                              hideStatusBar:TRUE
                                                 completion:^{}
                          ];
    
    DefaultButton *ok = [[DefaultButton alloc] initWithTitle:@"Ok" height:40 dismissOnTap:YES action:^
                         {
                             [popup dismissViewControllerAnimated:YES completion:NULL];
                             
                             [self didHideMessageByUser]();
                         }];
    
    [popup addButtons: @[ok]];
    
    [[self viewController] presentViewController:popup animated:YES completion:nil];
    
    [self didShowMessage]();
}

- (void)showSettingsPopup:(void (^)(BOOL))responseBlock {
    PopupDialog *popup = [[PopupDialog alloc] initWithTitle:@"Open iOS Settings"
                                                    message:@"Opening iOS Settings will cause the current AR Session to be restarted when you come back"
                                                      image:nil
                                            buttonAlignment:UILayoutConstraintAxisHorizontal
                                            transitionStyle:PopupDialogTransitionStyleBounceUp
                                             preferredWidth:200.0
                                           gestureDismissal:NO
                                              hideStatusBar:TRUE
                                                 completion:^{}
    ];

    DefaultButton *ok = [[DefaultButton alloc] initWithTitle:@"OK" height:40 dismissOnTap:YES action:^{
        responseBlock(true);
    }];
    ok.titleColor = UIColor.blueColor;

    DefaultButton *cancel = [[DefaultButton alloc] initWithTitle:@"Cancel" height:40 dismissOnTap:YES action:^{
        responseBlock(false);
    }];

    [popup addButtons: @[cancel, ok]];

    [[self viewController] presentViewController:popup animated:YES completion:nil];
}

- (void)showMessageAboutResetTracking:(void (^)(ResetTrackigOption))responseBlock {
    PopupDialog *popup = [[PopupDialog alloc] initWithTitle:@"Reset tracking"
                                                    message:@"Please select one of the options below"
                                                      image:nil
                                            buttonAlignment:UILayoutConstraintAxisVertical
                                            transitionStyle:PopupDialogTransitionStyleBounceUp
                                             preferredWidth:200.0
                                           gestureDismissal:NO
                                              hideStatusBar:TRUE
                                                 completion:^{}
    ];

    DefaultButton *resetTracking = [[DefaultButton alloc] initWithTitle:@"Completely restart tracking" height:40 dismissOnTap:YES action:^{
        responseBlock(ResetTracking);
    }];
    resetTracking.titleColor = resetTracking.tintColor;

    DefaultButton *removeExistingAnchors = [[DefaultButton alloc] initWithTitle:@"Remove known anchors" height:40 dismissOnTap:YES action:^{
        responseBlock(RemoveExistingAnchors);
    }];
    removeExistingAnchors.titleColor = removeExistingAnchors.tintColor;

    CancelButton * cancelButton = [[CancelButton alloc] initWithTitle:@"Cancel" height:40 dismissOnTap:YES action:^{}];
    cancelButton.titleColor = cancelButton.tintColor;
    
    [popup addButtons: @[resetTracking, removeExistingAnchors, cancelButton]];

    [[self viewController] presentViewController:popup animated:YES completion:nil];
}

- (void)showMessageAboutAccessingTheCapturedImage:(void (^)(BOOL))granted {
    PopupDialog *popup = [[PopupDialog alloc] initWithTitle:@"Video Camera Image Access"
                                                    message:@"WebXR Viewer displays video from your camera without giving the web page access to the video.\n\nThis page is requesting access to images from the video camera. Allow?"
                                                      image:nil
                                            buttonAlignment:UILayoutConstraintAxisHorizontal
                                            transitionStyle:PopupDialogTransitionStyleBounceUp
                                             preferredWidth:340.0
                                           gestureDismissal:NO
                                              hideStatusBar:TRUE
                                                 completion:^{}
    ];

    DestructiveButton *ok = [[DestructiveButton alloc] initWithTitle:@"YES" height:40 dismissOnTap:YES action:^{
        granted(true);
    }];
    ok.titleColor = UIColor.blueColor;

    DefaultButton *cancel = [[DefaultButton alloc] initWithTitle:@"NO" height:40 dismissOnTap:YES action:^{
        granted(false);
    }];

    [popup addButtons: @[cancel, ok]];

    [[self viewController] presentViewController:popup animated:YES completion:nil];
}

- (void)showMessageAboutAccessingWorldSensingData:(void (^)(BOOL))granted url:(NSURL*)url {
    NSUserDefaults* standardUserDefaults = [NSUserDefaults standardUserDefaults];
    NSDictionary<NSString *,id>* allowedWorldSensingSites = [standardUserDefaults dictionaryForKey:allowedWorldSensingSitesKey];
    NSString* site = [[url host] stringByAppendingFormat:@":%@", [url port]];

    // Check global permission.
    if ([standardUserDefaults boolForKey:alwaysAllowWorldSensingKey]) {
        granted(true);
        return;
    }

    // Check per-site permission.
    if (allowedWorldSensingSites != nil) {
        if (allowedWorldSensingSites[site] != nil) {
            granted(true);
            return;
        }
    }
    
    PopupDialog *popup = [[PopupDialog alloc] initWithTitle:@"Access to World Sensing"
                                                    message:@"This webpage wants to use your camera to look for faces and things in the real world. (For details, see our Privacy Notice in Settings.) Allow?"
                                                      image:nil
                                            buttonAlignment:UILayoutConstraintAxisVertical // Horizontal
                                            transitionStyle:PopupDialogTransitionStyleBounceUp
                                             preferredWidth:340.0
                                           gestureDismissal:NO
                                              hideStatusBar:TRUE
                                                 completion:^{}
    ];
    
    DestructiveButton *always = [[DestructiveButton alloc] initWithTitle:@"Always for this site" height:40 dismissOnTap:YES action:^{
        
        // don't set global permission...
        // [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:alwaysAllowWorldSensingKey];
        
        // instead, encode the domain/site into the allowed list
        NSMutableDictionary* newDict;
        if (allowedWorldSensingSites == nil) {
            newDict = [NSMutableDictionary new];
        } else {
            newDict = [allowedWorldSensingSites mutableCopy];
        }
        newDict[site] = @"YES";
        [[NSUserDefaults standardUserDefaults] setObject:newDict forKey:allowedWorldSensingSitesKey];

        granted(true);
    }];

    DestructiveButton *ok = [[DestructiveButton alloc] initWithTitle:@"This time only" height:40 dismissOnTap:YES action:^{
        granted(true);
    }];
    ok.titleColor = UIColor.blueColor;

    DefaultButton *cancel = [[DefaultButton alloc] initWithTitle:@"NO" height:40 dismissOnTap:YES action:^{
        granted(false);
    }];

    [popup addButtons: @[cancel, ok, always]];

    [[self viewController] presentViewController:popup animated:YES completion:nil];
}

- (void)hideMessages {
    [[[self viewController] presentedViewController] dismissViewControllerAnimated:YES completion:nil];
}

- (void)showPermissionsPopup {
    RequestPermissionsViewController* viewController = [RequestPermissionsViewController new];
    viewController.view.translatesAutoresizingMaskIntoConstraints = true;
    [[viewController.view.heightAnchor constraintEqualToConstant:300.0] setActive:YES];
    
    PopupDialog *dialog = [[PopupDialog alloc] initWithViewController:viewController
                                                      buttonAlignment:UILayoutConstraintAxisVertical
                                                      transitionStyle:PopupDialogTransitionStyleBounceUp
                                                       preferredWidth:UIScreen.mainScreen.bounds.size.width/2.0
                                                     gestureDismissal:NO
                                                        hideStatusBar:YES
                                                           completion:^{}];
    
    [[self viewController] presentViewController:dialog animated:YES completion:nil];
}

#pragma mark private

- (void)setupAppearance
{
    [PopupDialogDefaultView appearance].backgroundColor = [UIColor clearColor];
    [PopupDialogDefaultView appearance].titleFont = [UIFont fontWithName:@"Myriad Pro Regular" size:14];
    [PopupDialogDefaultView appearance].titleColor = [UIColor blackColor];
    [PopupDialogDefaultView appearance].messageFont = [UIFont fontWithName:@"Myriad Pro Regular" size:12];
    [PopupDialogDefaultView appearance].messageColor = [UIColor grayColor];
    
    [PopupDialogOverlayView appearance].color = [UIColor colorWithWhite:0 alpha:0.5];
    [PopupDialogOverlayView appearance].blurRadius = 10;
    [PopupDialogOverlayView appearance].blurEnabled = YES;
    [PopupDialogOverlayView appearance].liveBlur = NO;
    [PopupDialogOverlayView appearance].opacity = .5;
    
    [DefaultButton appearance].titleFont = [UIFont fontWithName:@"Myriad Pro Regular" size:14];
    [DefaultButton appearance].titleColor = [UIColor grayColor];
    [DefaultButton appearance].buttonColor = [UIColor clearColor];
    [DefaultButton appearance].separatorColor = [UIColor colorWithWhite:0.8 alpha:1];
    
    [CancelButton appearance].titleColor = [UIColor grayColor];
    [DestructiveButton appearance].titleColor = [UIColor redColor];
}

@end

