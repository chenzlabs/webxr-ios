#import <Foundation/Foundation.h>
#import "WebController.h"
#import "WebARKHeader.h"
#import "ARKHelper.h"
#import "OverlayHeader.h"
#import "BarView.h"
#import "Constants.h"

@interface WebController () <WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler>

@property (nonatomic, weak) UIView *rootView;
@property (nonatomic, weak) WKWebView *webView;
@property (nonatomic, weak) WKUserContentController *contentController;
@property (nonatomic, copy) NSString *transferCallback;
@property (nonatomic, copy) NSString *lastURL;

@property (nonatomic, weak) BarView *barView;
@property (nonatomic, weak) NSLayoutConstraint* barViewTopAnchorConstraint;
@property (nonatomic, strong) NSString* documentReadyState;
@end

typedef void (^WebCompletion)(id _Nullable param, NSError * _Nullable error);

inline static WebCompletion debugCompletion(NSString *name)
{
    return ^(id  _Nullable param, NSError * _Nullable error)
    {
        DDLogDebug(@"%@ : %@", name, error ? @"error" : @"success");
    };
}

@implementation WebController

#pragma mark Interface

- (void)dealloc
{
    DDLogDebug(@"WebController dealloc");
}

- (instancetype)initWithRootView:(UIView *)rootView
{
    self = [super init];
    
    if (self)
    {
        [self setupWebViewWithRootView:rootView];
        [self setupWebContent];
        [self setupWebUI];
        [self setupBarView];
    }
    
    return self;
}

- (void)viewWillTransitionToSize:(CGSize)size
{
    [self layout];
    
    // This message is not being used by the polyfyill
    // [self callWebMethod:WEB_AR_IOS_VIEW_WILL_TRANSITION_TO_SIZE_MESSAGE param:NSStringFromCGSize(size) webCompletion:debugCompletion(@"viewWillTransitionToSize")];
}

- (void)clean
{
    [self cleanWebContent];
    
    [[self webView] stopLoading];
    
    [[[self webView] configuration] setProcessPool:[WKProcessPool new]];
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

- (BOOL)sendARData:(NSDictionary *)data
{
#define CHECK_UPDATE_CALL NO
    if ([self transferCallback] && data)
    {
        [self callWebMethod:[self transferCallback] paramJSON:data webCompletion:CHECK_UPDATE_CALL ? debugCompletion(@"sendARData") : NULL];
        
        return YES;
    }
    
    return NO;
}


- (void)sendComputerVisionData:(NSDictionary *)computerVisionData {
    [self callWebMethod:@"onComputerVisionData" paramJSON:computerVisionData webCompletion:^(id  _Nullable param, NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"Error onComputerVisionData: %@", [error localizedDescription]);
        }
    }];
}

- (void)sendNativeTime:(NSTimeInterval)nativeTime {
    //NSLog(@"Sending native time: %lf", nativeTime);
    NSDictionary* jsonData = @{@"nativeTime": [NSNumber numberWithDouble:nativeTime]};
    [self callWebMethod:@"setNativeTime" paramJSON:jsonData webCompletion:^(id  _Nullable param, NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"Error setNativeTime: %@", [error localizedDescription]);
        }
    }];
}


- (void)reload
{
    NSString *url = [[[self barView] urlFieldText] length] > 0 ? [[self barView] urlFieldText] : [self lastURL];
    [self loadURL:url];
}

- (void) goHome
{
    NSLog(@"going home");
    NSString* homeURL = [[NSUserDefaults standardUserDefaults] stringForKey:homeURLKey];
    if (homeURL && ![homeURL isEqualToString:@""]) {
        [self loadURL: homeURL];
    } else {
        [self loadURL:WEB_URL];
    }
}
- (void)loadURL:(NSString *)theUrl
{
    [self goFullScreen];
    
    NSURL *url;
    if([theUrl hasPrefix:@"http://"] || [theUrl hasPrefix:@"https://"]) {
        url = [NSURL URLWithString:theUrl];
    } else {
        url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@", theUrl]];
    }

    if (url)
    {
        NSString *scheme = [url scheme];
        
        if (scheme && [WKWebView handlesURLScheme:scheme])
        {
            NSURLRequest *r = [NSURLRequest requestWithURL:url
                                               cachePolicy:NSURLRequestReloadIgnoringCacheData
                                           timeoutInterval:60];
            
            [[NSURLCache sharedURLCache] removeAllCachedResponses];
            
            
            [[self webView] loadRequest:r];
            
            [self setLastURL:[url absoluteString]];
            
            return;
        }
    }
    
    if ([self onError])
    {
        [self onError](nil);
    }
}

- (void)loadBlankHTMLString {
    [[self webView] loadHTMLString:@"<html></html>" baseURL:[[self webView] URL]];
}

- (void)startRecording:(BOOL)start
{
    NSString *message = start ? WEB_AR_IOS_START_RECORDING_MESSAGE : WEB_AR_IOS_STOP_RECORDING_MESSAGE;
    
    [self callWebMethod:message param:@"" webCompletion:debugCompletion(@"setRecordState")];
}

- (void)setupForWebXR:(BOOL)webXR
{
    dispatch_async(dispatch_get_main_queue(), ^
    {
        [[self barView] hideKeyboard];
        [[self barView] setDebugVisible:webXR];
        [[self barView] setRestartTrackingVisible:webXR];
        float webViewTopAnchorConstraintConstant = webXR? 0.0f: URL_BAR_HEIGHT;
        [[self webViewTopAnchorConstraint] setConstant:webViewTopAnchorConstraintConstant];
        [[[self webView] superview] setNeedsLayout];
        [[[self webView] superview] layoutIfNeeded];
         
        UIColor *backColor = webXR ? [UIColor clearColor] : [UIColor whiteColor];
        [[[self webView] superview] setBackgroundColor:backColor];
        
        [[self animator] animate:[[self webView] superview] toColor:backColor];
    });
}

- (void)showBar:(BOOL)showBar
{
    NSLog(@"Show bar: %@", showBar? @"Yes": @"No");
    [[[self barView] superview] layoutIfNeeded];
    
    float topAnchorConstant = showBar ? 0.0f : 0.0f - URL_BAR_HEIGHT * 2;
    [[self barViewTopAnchorConstraint] setConstant:topAnchorConstant];
    
    [UIView animateWithDuration:URL_BAR_ANIMATION_TIME_IN_SECONDS animations:^{
        [[[self barView] superview] layoutIfNeeded];
    }];
}

- (void)showDebug:(BOOL)showDebug
{
    [self callWebMethod:WEB_AR_IOS_SHOW_DEBUG paramJSON:@{WEB_AR_UI_DEBUG_OPTION : (showDebug ? @YES : @NO)} webCompletion:debugCompletion(@"showDebug")];
}

- (void)wasARInterruption:(BOOL)interruption
{
    NSString *message = interruption ? WEB_AR_IOS_START_RECORDING_MESSAGE : WEB_AR_IOS_INTERRUPTION_ENDED_MESSAGE;
    
    [self callWebMethod:message param:@"" webCompletion:debugCompletion(@"ARinterruption")];
}

- (void)didBackgroundAction:(BOOL)background
{
    NSString *message = background ? WEB_AR_IOS_DID_MOVE_BACK_MESSAGE : WEB_AR_IOS_WILL_ENTER_FOR_MESSAGE;
    
    [self callWebMethod:message param:@"" webCompletion:debugCompletion(@"backgroundAction")];
}

- (void)didReceiveMemoryWarning
{
    [self callWebMethod:WEB_AR_IOS_DID_RECEIVE_MEMORY_WARNING_MESSAGE param:@"" webCompletion:debugCompletion(@"iosDidReceiveMemoryWarning")];
}

- (void)didChangeARTrackingState:(NSString *)state
{
    [self callWebMethod:WEB_AR_IOS_TRACKING_STATE_MESSAGE param:state webCompletion:debugCompletion(@"arkitDidChangeTrackingState")];
}

- (void)updateWindowSize {
    CGSize size = [self webView].frame.size;
    NSDictionary* sizeDictionary = @{
                                WEB_AR_IOS_SIZE_WIDTH_PARAMETER: @(size.width),
                                WEB_AR_IOS_SIZE_HEIGHT_PARAMETER: @(size.height),
                                };
    [self callWebMethod:WEB_AR_IOS_WINDOW_RESIZE_MESSAGE paramJSON:sizeDictionary webCompletion:debugCompletion(WEB_AR_IOS_WINDOW_RESIZE_MESSAGE)];
}

- (void)hideKeyboard {
    [[self barView] hideKeyboard];
}

- (void)didReceiveError:(NSError *)error {
    NSDictionary* errorDictionary = @{
            WEB_AR_IOS_ERROR_DOMAIN_PARAMETER: error.domain,
            WEB_AR_IOS_ERROR_CODE_PARAMETER: @(error.code),
            WEB_AR_IOS_ERROR_MESSAGE_PARAMETER: error.localizedDescription
    };
    [self callWebMethod:WEB_AR_IOS_ERROR_MESSAGE paramJSON:errorDictionary webCompletion:debugCompletion(WEB_AR_IOS_ERROR_MESSAGE)];
}

- (void)userGrantedComputerVisionData:(bool)granted {
    [self callWebMethod:WEB_AR_IOS_USER_GRANTED_CV_DATA paramJSON:@{@"granted": @(granted)} webCompletion:debugCompletion(WEB_AR_IOS_USER_GRANTED_CV_DATA)];
}

- (void)hideCameraFlipButton {
    [[self barView] hideCameraFlipButton];
}

- (BOOL)isDebugButtonSelected {
    return [[self barView] isDebugButtonSelected];
}

- (void)userGrantedSendingWorldSensingData:(BOOL)granted {
    [self callWebMethod:WEB_AR_IOS_USER_GRANTED_WORLD_SENSING_DATA paramJSON:@{@"granted": @(granted)} webCompletion:debugCompletion(WEB_AR_IOS_USER_GRANTED_CV_DATA)];
}

#pragma mark WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    //DDLogDebug(@"Received message: %@ , body: %@", [message name], [message body]);
    
    __weak typeof (self) blockSelf = self;
    
    if ([[message name] isEqualToString:WEB_AR_INIT_MESSAGE])
    {
        NSDictionary *params = @{ WEB_IOS_DEVICE_UUID_OPTION : [[[UIDevice currentDevice] identifierForVendor] UUIDString],
                                  WEB_IOS_IS_IPAD_OPTION : @([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad),
                                  WEB_IOS_SYSTEM_VERSION_OPTION : [[UIDevice currentDevice] systemVersion],
                                  WEB_IOS_SCREEN_SCALE_OPTION : @([[UIScreen mainScreen] nativeScale]),
                                  WEB_IOS_SCREEN_SIZE_OPTION : NSStringFromCGSize([[UIScreen mainScreen] nativeBounds].size)};
        
        DDLogDebug(@"Init AR send - %@", [params debugDescription]);
        
        [self callWebMethod:[[message body] objectForKey:WEB_AR_CALLBACK_OPTION]
                  paramJSON:params
              webCompletion:^(id  _Nullable param, NSError * _Nullable error)
         {
             DDLogDebug(@"Init AR %@", error ? @"error" : @"success");
             
             if (error == nil)
             {
                 [blockSelf onInitAR]([message body][WEB_AR_REQUEST_OPTION][WEB_AR_UI_OPTION]);
             }
             else
             {
                 [blockSelf onError](error);
             }
         }];
    }
    else if ([[message name] isEqualToString:WEB_AR_LOAD_URL_MESSAGE])
    {
        [self loadURL]([[message body] objectForKey:WEB_AR_URL_OPTION]);
    }
    else if ([[message name] isEqualToString:WEB_AR_START_WATCH_MESSAGE])
    {
        [self setTransferCallback:[[message body] objectForKey:WEB_AR_CALLBACK_OPTION]];
        
        [self onWatchAR]([[message body] objectForKey:WEB_AR_REQUEST_OPTION]);

    }
    else if ([[message name] isEqualToString:WEB_AR_ON_JS_UPDATE_MESSAGE])
    {
        [self sendARData:[blockSelf onJSUpdateData]()];
    }
    else if ([[message name] isEqualToString:WEB_AR_STOP_WATCH_MESSAGE])
    {
        [self setTransferCallback:nil];
        
        [self onStopAR]();

        [self callWebMethod:[[message body] objectForKey:WEB_AR_CALLBACK_OPTION] param:@"" webCompletion:NULL];
    }
    else if ([[message name] isEqualToString:WEB_AR_SET_UI_MESSAGE])
    {
        [self onSetUI]([message body]);
    }
    else if ([[message name] isEqualToString:WEB_AR_HIT_TEST_MESSAGE])
    {
        NSString *hitCallback = [[message body] objectForKey:WEB_AR_CALLBACK_OPTION];
        NSUInteger type = [[[message body] objectForKey:WEB_AR_TYPE_OPTION] integerValue];
        CGFloat x = [[[message body] objectForKey:WEB_AR_X_POSITION_OPTION] floatValue];
        CGFloat y = [[[message body] objectForKey:WEB_AR_Y_POSITION_OPTION] floatValue];
        
        [self onHitTest](type, x, y, ^(NSArray *results)
                         {
                             //DDLogDebug(@"Hit test - %@", [results debugDescription]);
                             [blockSelf callWebMethod:hitCallback paramJSON:results webCompletion:debugCompletion(@"onHitTest")];
                         });
    }
    else if ([[message name] isEqualToString:WEB_AR_ADD_ANCHOR_MESSAGE])
    {
        NSString *hitCallback = [[message body] objectForKey:WEB_AR_CALLBACK_OPTION];
        NSString *name = [[message body] objectForKey:WEB_AR_UUID_OPTION];
        NSArray *transform = [[message body] objectForKey:WEB_AR_TRANSFORM_OPTION];
        
        [self onAddAnchor](name, transform,^(NSDictionary *results)
                           {
                               [blockSelf callWebMethod:hitCallback paramJSON:results webCompletion:debugCompletion(@"onAddAnchor")];
                           });
    } else if ([[message name] isEqualToString:WEB_AR_REQUEST_CV_DATA_MESSAGE]) {
        if ([self onComputerVisionDataRequested]) {
            [self onComputerVisionDataRequested]();
        }
    } else if ([[message name] isEqualToString:WEB_AR_START_SENDING_CV_DATA_MESSAGE]) {
        if ([self onStartSendingComputerVisionData]) {
            [self onStartSendingComputerVisionData]();
        }
    } else if ([[message name] isEqualToString:WEB_AR_STOP_SENDING_CV_DATA_MESSAGE]) {
        if ([self onStopSendingComputerVisionData]) {
            [self onStopSendingComputerVisionData]();
        }
    } else if ([[message name] isEqualToString:WEB_AR_REMOVE_ANCHORS_MESSAGE]) {
        NSArray *anchorIDs = [message body];
        if ([self onRemoveObjects]) {
            [self onRemoveObjects](anchorIDs);
        }
    } else if ([[message name] isEqualToString:WEB_AR_ADD_IMAGE_ANCHOR]) {
        NSDictionary *imageAnchorInfoDictionary = [message body];
        NSString *createImageAnchorCallback = [[message body] objectForKey:WEB_AR_CALLBACK_OPTION];
        if ([self onAddImageAnchor]) {
            [self onAddImageAnchor](imageAnchorInfoDictionary, ^(NSDictionary *imageAnchor){
                [blockSelf callWebMethod:createImageAnchorCallback paramJSON:imageAnchor webCompletion:NULL];
            });
        }
    } else if ([[message name] isEqualToString:WEB_AR_CREATE_IMAGE_ANCHOR_MESSAGE]) {
        NSDictionary *imageAnchorInfoDictionary = [message body];
        NSString *createDetectionImageCallback = [[message body] objectForKey:WEB_AR_CALLBACK_OPTION];
        if ([self onCreateDetectionImage]) {
            [self onCreateDetectionImage](imageAnchorInfoDictionary, ^(BOOL success, NSString* errorString) {
                NSMutableDictionary* responseDictionary = [NSMutableDictionary new];
                responseDictionary[@"created"] = @(success);
                if (errorString) {
                    responseDictionary[@"error"] = errorString;
                }
                [blockSelf callWebMethod:createDetectionImageCallback paramJSON:responseDictionary webCompletion:NULL];
            });
        }
    } else if ([[message name] isEqualToString:WEB_AR_ACTIVATE_DETECTION_IMAGE_MESSAGE]) {
        NSDictionary *imageAnchorInfoDictionary = [message body];
        NSString *imageName = imageAnchorInfoDictionary[WEB_AR_DETECTION_IMAGE_NAME_OPTION];
        NSString *activateDetectionImageCallback = [[message body] objectForKey:WEB_AR_CALLBACK_OPTION];
        if ([self onActivateDetectionImage]) {
            [self onActivateDetectionImage](imageName, ^(BOOL success, NSString* errorString, NSDictionary* imageAnchor) {
                NSMutableDictionary* responseDictionary = [NSMutableDictionary new];
                responseDictionary[@"activated"] = @(success);
                if (errorString) {
                    responseDictionary[@"error"] = errorString;
                } else {
                    responseDictionary[@"imageAnchor"] = imageAnchor;
                }
                [blockSelf callWebMethod:activateDetectionImageCallback paramJSON:responseDictionary webCompletion:NULL];
            });
        }
    } else if ([[message name] isEqualToString:WEB_AR_DEACTIVATE_DETECTION_IMAGE_MESSAGE]) {
        NSDictionary *imageAnchorInfoDictionary = [message body];
        NSString *imageName = imageAnchorInfoDictionary[WEB_AR_DETECTION_IMAGE_NAME_OPTION];
        NSString *deactivateDetectionImageCallback = [[message body] objectForKey:WEB_AR_CALLBACK_OPTION];
        if ([self onDeactivateDetectionImage]) {
            [self onDeactivateDetectionImage](imageName, ^(BOOL success, NSString* errorString) {
                NSMutableDictionary* responseDictionary = [NSMutableDictionary new];
                responseDictionary[@"deactivated"] = @(success);
                if (errorString) {
                    responseDictionary[@"error"] = errorString;
                }
                [blockSelf callWebMethod:deactivateDetectionImageCallback paramJSON:responseDictionary webCompletion:NULL];
            });
        }
    } else if ([[message name] isEqualToString:WEB_AR_DESTROY_DETECTION_IMAGE_MESSAGE]) {
        NSDictionary *imageAnchorInfoDictionary = [message body];
        NSString *imageName = imageAnchorInfoDictionary[WEB_AR_DETECTION_IMAGE_NAME_OPTION];
        NSString *destroyDetectionImageCallback = [[message body] objectForKey:WEB_AR_CALLBACK_OPTION];
        if ([self onDestroyDetectionImage]) {
            [self onDestroyDetectionImage](imageName, ^(BOOL success, NSString* errorString) {
                NSMutableDictionary* responseDictionary = [NSMutableDictionary new];
                responseDictionary[@"destroyed"] = @(success);
                if (errorString) {
                    responseDictionary[@"error"] = errorString;
                }
                [blockSelf callWebMethod:destroyDetectionImageCallback paramJSON:responseDictionary webCompletion:NULL];
            });
        }
    } else if ([[message name] isEqualToString:WEB_AR_ADD_OBJECT_ANCHOR_MESSAGE]) {
        NSDictionary *objectAnchorInfoDictionary = [message body];
        NSString *createObjectAnchorCallback = [[message body] objectForKey:WEB_AR_CALLBACK_OPTION];
        if ([self onAddObjectAnchor]) {
            [self onAddObjectAnchor](objectAnchorInfoDictionary, ^(NSDictionary *objectAnchor){
                [blockSelf callWebMethod:createObjectAnchorCallback paramJSON:objectAnchor webCompletion:NULL];
            });
        }
    } else if ([[message name] isEqualToString:WEB_AR_CREATE_OBJECT_ANCHOR_MESSAGE]) {
        NSMutableDictionary *objectAnchorInfoDictionary = [[message body] mutableCopy];
        NSString *createDetectionObjectCallback = [[message body] objectForKey:WEB_AR_CALLBACK_OPTION];
        
        NSURLSessionDownloadTask* dl =
            [[NSURLSession sharedSession]
                downloadTaskWithURL:[NSURL URLWithString:objectAnchorInfoDictionary[@"url"]]
                completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                    if (error) {
                        NSLog(@"downloadTaskWithURL completionHandler error: %@", error);
                        
                        // delete the temp file
                        NSError* error = nil;
                        if ([[NSFileManager defaultManager] removeItemAtPath:[location path] error:&error]) {
                            NSLog(@"!!! download completion handler removeItemAtPath [Error] %@ (%@)", error, location);
                        }
                        
                        NSMutableDictionary* responseDictionary = [NSMutableDictionary new];
                        responseDictionary[@"created"] = @(FALSE);
                        responseDictionary[@"error"] = [error localizedDescription];
                        [blockSelf callWebMethod:createDetectionObjectCallback paramJSON:responseDictionary webCompletion:NULL];
                        return;
                    }
                 
                    objectAnchorInfoDictionary[@"url"] = [location absoluteString];

                    if ([self onCreateDetectionObject]) {
                        [self onCreateDetectionObject](objectAnchorInfoDictionary, ^(BOOL success, NSString* errorString) {
                            NSMutableDictionary* responseDictionary = [NSMutableDictionary new];
                            responseDictionary[@"created"] = @(success);
                            if (errorString) {
                                responseDictionary[@"error"] = errorString;
                            }
                            
                            [blockSelf callWebMethod:createDetectionObjectCallback paramJSON:responseDictionary webCompletion:NULL];
                            
                            // delete the temp file
                            NSError* error = nil;
                            if ([[NSFileManager defaultManager] removeItemAtPath:[location path] error:&error]) {
                                NSLog(@"!!! download completion handler removeItemAtPath [Error] %@ (%@)", error, location);
                            }
                        });
                    } else {
                        NSMutableDictionary* responseDictionary = [NSMutableDictionary new];
                        responseDictionary[@"created"] = @(FALSE);
                        responseDictionary[@"error"] = @"No onCreateDetectionObject";
                        [blockSelf callWebMethod:createDetectionObjectCallback paramJSON:responseDictionary webCompletion:NULL];
                        
                        // delete the temp file
                        NSError* error = nil;
                        if ([[NSFileManager defaultManager] removeItemAtPath:[location path] error:&error]) {
                            NSLog(@"!!! onCreateDetectionObject removeItemAtPath [Error] %@ (%@)", error, location);
                        }                        
                    }
                        
                    });
                }];
        [dl resume];
    } else if ([[message name] isEqualToString:WEB_AR_ACTIVATE_DETECTION_OBJECT_MESSAGE]) {
        NSDictionary *objectAnchorInfoDictionary = [message body];
        NSString *objectName = objectAnchorInfoDictionary[WEB_AR_DETECTION_OBJECT_NAME_OPTION];
        NSString *activateDetectionObjectCallback = [[message body] objectForKey:WEB_AR_CALLBACK_OPTION];
        if ([self onActivateDetectionObject]) {
            [self onActivateDetectionObject](objectName, ^(BOOL success, NSString* errorString, NSDictionary* objectAnchor) {
                NSMutableDictionary* responseDictionary = [NSMutableDictionary new];
                responseDictionary[@"activated"] = @(success);
                if (errorString) {
                    responseDictionary[@"error"] = errorString;
                } else {
                    responseDictionary[@"objectAnchor"] = objectAnchor;
                }
                [blockSelf callWebMethod:activateDetectionObjectCallback paramJSON:responseDictionary webCompletion:NULL];
            });
        }
    } else if ([[message name] isEqualToString:WEB_AR_DEACTIVATE_DETECTION_OBJECT_MESSAGE]) {
        NSDictionary *objectAnchorInfoDictionary = [message body];
        NSString *objectName = objectAnchorInfoDictionary[WEB_AR_DETECTION_OBJECT_NAME_OPTION];
        NSString *deactivateDetectionObjectCallback = [[message body] objectForKey:WEB_AR_CALLBACK_OPTION];
        if ([self onDeactivateDetectionObject]) {
            [self onDeactivateDetectionObject](objectName, ^(BOOL success, NSString* errorString) {
                NSMutableDictionary* responseDictionary = [NSMutableDictionary new];
                responseDictionary[@"deactivated"] = @(success);
                if (errorString) {
                    responseDictionary[@"error"] = errorString;
                }
                [blockSelf callWebMethod:deactivateDetectionObjectCallback paramJSON:responseDictionary webCompletion:NULL];
            });
        }
    } else if ([[message name] isEqualToString:WEB_AR_DESTROY_DETECTION_OBJECT_MESSAGE]) {
        NSDictionary *objectAnchorInfoDictionary = [message body];
        NSString *objectName = objectAnchorInfoDictionary[WEB_AR_DETECTION_OBJECT_NAME_OPTION];
        NSString *destroyDetectionObjectCallback = [[message body] objectForKey:WEB_AR_CALLBACK_OPTION];
        if ([self onDestroyDetectionObject]) {
            [self onDestroyDetectionObject](objectName, ^(BOOL success, NSString* errorString) {
                NSMutableDictionary* responseDictionary = [NSMutableDictionary new];
                responseDictionary[@"destroyed"] = @(success);
                if (errorString) {
                    responseDictionary[@"error"] = errorString;
                }
                [blockSelf callWebMethod:destroyDetectionObjectCallback paramJSON:responseDictionary webCompletion:NULL];
            });
        }
    } else {
        DDLogError(@"Unknown message: %@ ,for name: %@", [message body], [message name]);
    }
    
}

- (void)callWebMethod:(NSString *)name param:(NSString *)param webCompletion:(WebCompletion)completion
{
    NSData *jsonData = param ? [NSJSONSerialization dataWithJSONObject:@[param] options:0 error:nil] : [NSData data];
    [self callWebMethod:name jsonData:jsonData  webCompletion:completion];
}

- (void)callWebMethod:(NSString *)name paramJSON:(id)paramJSON webCompletion:(WebCompletion)completion
{
    NSData *jsonData = paramJSON ? [NSJSONSerialization dataWithJSONObject:paramJSON options:0 error:nil] : [NSData data];
    [self callWebMethod:name jsonData:jsonData webCompletion:completion];
}

- (void)callWebMethod:(NSString *)name jsonData:(NSData *)jsonData webCompletion:(WebCompletion)completion
{
    NSAssert(name, @" Web Massage name is nil !");
    
    NSString *jsString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSString *jsScript = [NSString stringWithFormat:@"%@(%@)", name, jsString];
    
    [[self webView] evaluateJavaScript:jsScript completionHandler:completion];
}

#pragma mark WKUIDelegate, WKNavigationDelegate

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation
{
    DDLogDebug(@"didStartProvisionalNavigation - %@\n on thread %@", navigation, [[NSThread currentThread] description]);

    [[self webView] addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
    self.documentReadyState = nil;
    
    [self onStartLoad]();
    
    [[self barView] startLoading:[[[self webView] URL] absoluteString]];
    [[self barView] setBackEnabled:[[self webView] canGoBack]];
    [[self barView] setForwardEnabled:[[self webView] canGoForward]];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation
{
    DDLogDebug(@"didFinishNavigation - %@", navigation);
//    NSString* loadedURL = [[[self webView] URL] absoluteString];
//    [self setLastURL:loadedURL];
//
//    [[NSUserDefaults standardUserDefaults] setObject:loadedURL forKey:LAST_URL_KEY];
//
//    [self onFinishLoad]();
//
//    [[self barView] finishLoading:[[[self webView] URL] absoluteString]];
//    [[self barView] setBackEnabled:[[self webView] canGoBack]];
//    [[self barView] setForwardEnabled:[[self webView] canGoForward]];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error
{
    DDLogError(@"Web Error - %@", error);
    
    @try {
        [[self webView] removeObserver:self forKeyPath:@"estimatedProgress"];
    } @catch (NSException* exception) {
        NSLog(@"%@", [exception description]);
    }
    
    if ([self shouldShowError:error])
    {
        [self onError](error);
    }
    
    [[self barView] finishLoading:[[[self webView] URL] absoluteString]];
    [[self barView] setBackEnabled:[[self webView] canGoBack]];
    [[self barView] setForwardEnabled:[[self webView] canGoForward]];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error
{
    DDLogError(@"Web Error - %@", error);
    
    @try {
        [[self webView] removeObserver:self forKeyPath:@"estimatedProgress"];
    } @catch (NSException* exception) {
        NSLog(@"%@", [exception description]);
    }
    
    if ([self shouldShowError:error])
    {
        [self onError](error);
    }
    
    [[self barView] finishLoading:[[[self webView] URL] absoluteString]];
    [[self barView] setBackEnabled:[[self webView] canGoBack]];
    [[self barView] setForwardEnabled:[[self webView] canGoForward]];
}

- (BOOL)webView:(WKWebView *)webView shouldPreviewElement:(WKPreviewElementInfo *)elementInfo
{
    return NO;
}

#pragma mark Private

- (void)goFullScreen {
    [[self webViewTopAnchorConstraint] setConstant:0.0];
}

- (BOOL)shouldShowError:(NSError *)error
{
    return (([error code] > 600) || ([error code] < 200));
}

- (void)layout
{
    [[self webView] layoutIfNeeded];
    
    [[self barView] layoutIfNeeded];
}

- (void)setupWebUI
{
    [[self webView] setAutoresizesSubviews:YES];
    
    [[self webView] setAllowsLinkPreview:NO];
    [[self webView] setOpaque:NO];
    [[self webView] setBackgroundColor:[UIColor clearColor]];
    [[self webView] setUserInteractionEnabled:YES];
    [[[self webView] scrollView] setBounces:NO];
    [[[self webView] scrollView] setBouncesZoom:NO];
}

- (void)setupBarView
{
    BarView *barView = [[[NSBundle mainBundle] loadNibNamed:@"BarView" owner:self options:nil] firstObject];
    [barView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [[[self webView] superview] addSubview:barView];
    
    NSLayoutConstraint* topAnchorConstraint = [[barView topAnchor] constraintEqualToAnchor:[[barView superview] topAnchor]];
    [topAnchorConstraint setActive:YES];
    [self setBarViewTopAnchorConstraint: topAnchorConstraint];
    
    [[[barView leftAnchor] constraintEqualToAnchor:[[barView superview] leftAnchor]] setActive:YES];
    [[[barView rightAnchor] constraintEqualToAnchor:[[barView superview] rightAnchor]] setActive:YES];
    NSLayoutConstraint *barViewHeightAnchorConstraint = [[barView heightAnchor] constraintEqualToConstant:URL_BAR_HEIGHT];
    [self setBarViewHeightAnchorConstraint: barViewHeightAnchorConstraint];
    [barViewHeightAnchorConstraint setActive:YES];
    
    [self setBarView:barView];
    
    __weak typeof (self) blockSelf = self;
    __weak typeof (BarView *) blockBar = barView;
    
    [barView setBackActionBlock:^(id sender)
     {
         if ([[blockSelf webView] canGoBack])
         {
             [[blockSelf webView] goBack];
         }
         else
         {
             [blockBar setBackEnabled:NO];
         }
     }];
    
    [barView setForwardActionBlock:^(id sender)
     {
         if ([[blockSelf webView] canGoForward])
         {
             [[blockSelf webView] goForward];
         }
         else
         {
             [blockBar setForwardEnabled:NO];
         }
     }];
    
    [barView setHomeActionBlock:^(id sender) {
        [self goHome];
    }];
    
    [barView setCancelActionBlock:^(id sender)
     {
         [[blockSelf webView] stopLoading];
     }];
    
    [barView setReloadActionBlock:^(id sender)
     {
         [blockSelf loadURL:[blockBar urlFieldText]];
     }];
    
    [barView setGoActionBlock:^(NSString *url)
     {
         [blockSelf loadURL:url];
     }];
    
    [barView setDebugButtonToggledAction:^(BOOL selected) {
        if ([blockSelf onDebugButtonToggled]) {
            [blockSelf onDebugButtonToggled](selected);
        }
    }];
    
    [barView setSettingsActionBlock:^{
        if ([blockSelf onSettingsButtonTapped]) {
            [blockSelf onSettingsButtonTapped]();
        }
    }];

    [barView setRestartTrackingActionBlock:^{
        if ([blockSelf onResetTrackingButtonTapped]) {
            [blockSelf onResetTrackingButtonTapped]();
        }
    }];
    
    [barView setSwitchCameraActionBlock:^{
        if ([blockSelf onSwitchCameraButtonTapped]) {
            [blockSelf onSwitchCameraButtonTapped]();
        }
    }];
}

- (void)setupWebContent
{
    [[self contentController] addScriptMessageHandler:self name:WEB_AR_INIT_MESSAGE];
    [[self contentController] addScriptMessageHandler:self name:WEB_AR_START_WATCH_MESSAGE];
    [[self contentController] addScriptMessageHandler:self name:WEB_AR_STOP_WATCH_MESSAGE];
    [[self contentController] addScriptMessageHandler:self name:WEB_AR_ON_JS_UPDATE_MESSAGE];
    [[self contentController] addScriptMessageHandler:self name:WEB_AR_LOAD_URL_MESSAGE];
    [[self contentController] addScriptMessageHandler:self name:WEB_AR_SET_UI_MESSAGE];
    [[self contentController] addScriptMessageHandler:self name:WEB_AR_HIT_TEST_MESSAGE];
    [[self contentController] addScriptMessageHandler:self name:WEB_AR_ADD_ANCHOR_MESSAGE];
    [[self contentController] addScriptMessageHandler:self name:WEB_AR_REQUEST_CV_DATA_MESSAGE];
    [[self contentController] addScriptMessageHandler:self name:WEB_AR_START_SENDING_CV_DATA_MESSAGE];
    [[self contentController] addScriptMessageHandler:self name:WEB_AR_STOP_SENDING_CV_DATA_MESSAGE];
    [[self contentController] addScriptMessageHandler:self name:WEB_AR_REMOVE_ANCHORS_MESSAGE];
    [[self contentController] addScriptMessageHandler:self name:WEB_AR_ADD_IMAGE_ANCHOR_MESSAGE];
    [[self contentController] addScriptMessageHandler:self name:WEB_AR_CREATE_IMAGE_ANCHOR_MESSAGE];
    [[self contentController] addScriptMessageHandler:self name:WEB_AR_ACTIVATE_DETECTION_IMAGE_MESSAGE];
    [[self contentController] addScriptMessageHandler:self name:WEB_AR_DEACTIVATE_DETECTION_IMAGE_MESSAGE];
    [[self contentController] addScriptMessageHandler:self name:WEB_AR_DESTROY_DETECTION_IMAGE_MESSAGE];
    [[self contentController] addScriptMessageHandler:self name:WEB_AR_ADD_OBJECT_ANCHOR_MESSAGE];
    [[self contentController] addScriptMessageHandler:self name:WEB_AR_CREATE_OBJECT_ANCHOR_MESSAGE];
    [[self contentController] addScriptMessageHandler:self name:WEB_AR_ACTIVATE_DETECTION_OBJECT_MESSAGE];
    [[self contentController] addScriptMessageHandler:self name:WEB_AR_DEACTIVATE_DETECTION_OBJECT_MESSAGE];
    [[self contentController] addScriptMessageHandler:self name:WEB_AR_DESTROY_DETECTION_OBJECT_MESSAGE];
}

- (void)cleanWebContent
{
    [[self contentController] removeScriptMessageHandlerForName:WEB_AR_INIT_MESSAGE];
    [[self contentController] removeScriptMessageHandlerForName:WEB_AR_START_WATCH_MESSAGE];
    [[self contentController] removeScriptMessageHandlerForName:WEB_AR_STOP_WATCH_MESSAGE];
    [[self contentController] removeScriptMessageHandlerForName:WEB_AR_ON_JS_UPDATE_MESSAGE];
    [[self contentController] removeScriptMessageHandlerForName:WEB_AR_LOAD_URL_MESSAGE];
    [[self contentController] removeScriptMessageHandlerForName:WEB_AR_SET_UI_MESSAGE];
    [[self contentController] removeScriptMessageHandlerForName:WEB_AR_HIT_TEST_MESSAGE];
    [[self contentController] removeScriptMessageHandlerForName:WEB_AR_ADD_ANCHOR_MESSAGE];
    [[self contentController] removeScriptMessageHandlerForName:WEB_AR_REQUEST_CV_DATA_MESSAGE];
    [[self contentController] removeScriptMessageHandlerForName:WEB_AR_START_SENDING_CV_DATA_MESSAGE];
    [[self contentController] removeScriptMessageHandlerForName:WEB_AR_STOP_SENDING_CV_DATA_MESSAGE];
    [[self contentController] removeScriptMessageHandlerForName:WEB_AR_REMOVE_ANCHORS_MESSAGE];
    [[self contentController] removeScriptMessageHandlerForName:WEB_AR_ADD_IMAGE_ANCHOR_MESSAGE];
    [[self contentController] removeScriptMessageHandlerForName:WEB_AR_CREATE_IMAGE_ANCHOR_MESSAGE];
    [[self contentController] removeScriptMessageHandlerForName:WEB_AR_ACTIVATE_DETECTION_IMAGE_MESSAGE];
    [[self contentController] removeScriptMessageHandlerForName:WEB_AR_DEACTIVATE_DETECTION_IMAGE_MESSAGE];
    [[self contentController] removeScriptMessageHandlerForName:WEB_AR_DESTROY_DETECTION_IMAGE_MESSAGE];
    [[self contentController] removeScriptMessageHandlerForName:WEB_AR_ADD_OBJECT_ANCHOR_MESSAGE];
    [[self contentController] removeScriptMessageHandlerForName:WEB_AR_CREATE_OBJECT_ANCHOR_MESSAGE];
    [[self contentController] removeScriptMessageHandlerForName:WEB_AR_ACTIVATE_DETECTION_OBJECT_MESSAGE];
    [[self contentController] removeScriptMessageHandlerForName:WEB_AR_DEACTIVATE_DETECTION_OBJECT_MESSAGE];
    [[self contentController] removeScriptMessageHandlerForName:WEB_AR_DESTROY_DETECTION_OBJECT_MESSAGE];
}

- (void)setupWebViewWithRootView:(__autoreleasing UIView*)rootView
{
    WKWebViewConfiguration *conf = [[WKWebViewConfiguration alloc] init];
    WKUserContentController *contentController = [WKUserContentController new];
    [conf setUserContentController:contentController];
    [self setContentController:contentController];
    
    WKPreferences *pref = [[WKPreferences alloc] init];
    [pref setJavaScriptEnabled:YES];
    [conf setPreferences:pref];
    
    [conf setProcessPool:[WKProcessPool new]];

    [conf setAllowsInlineMediaPlayback: YES];
    [conf setAllowsAirPlayForMediaPlayback: YES];
    [conf setAllowsPictureInPictureMediaPlayback: YES];
    [conf setMediaTypesRequiringUserActionForPlayback: WKAudiovisualMediaTypeNone];
    
    WKWebView *wv = [[WKWebView alloc] initWithFrame:[rootView bounds] configuration:conf];
    [rootView addSubview:wv];
    [wv setTranslatesAutoresizingMaskIntoConstraints:NO];
    
    NSLayoutConstraint* webViewTopAnchorConstraint = [[wv topAnchor] constraintEqualToAnchor:[rootView topAnchor]];
    [self setWebViewTopAnchorConstraint: webViewTopAnchorConstraint];
    [webViewTopAnchorConstraint setActive:YES];
    NSLayoutConstraint* webViewLeftAnchorConstraint = [[wv leftAnchor] constraintEqualToAnchor:[rootView leftAnchor]];
    [self setWebViewLeftAnchorConstraint: webViewLeftAnchorConstraint];
    [webViewLeftAnchorConstraint setActive:YES];
    NSLayoutConstraint *webViewRightAnchorConstraint = [[wv rightAnchor] constraintEqualToAnchor:[rootView rightAnchor]];
    [self setWebViewRightAnchorConstraint: webViewRightAnchorConstraint];
    [webViewRightAnchorConstraint setActive:YES];
    
    [[[wv bottomAnchor] constraintEqualToAnchor:[rootView bottomAnchor]] setActive:YES];
    
    [[wv scrollView] setContentInsetAdjustmentBehavior:UIScrollViewContentInsetAdjustmentNever];
    
    [wv setNavigationDelegate:self];
    [wv setUIDelegate:self];
    [self setWebView:wv];
}

- (void) documentDidBecomeInteractive {
    NSLog(@"documentDidBecomeInteractive");
    NSString* loadedURL = [[[self webView] URL] absoluteString];
    [self setLastURL:loadedURL];
    
    [[NSUserDefaults standardUserDefaults] setObject:loadedURL forKey:LAST_URL_KEY];
    
    [self onFinishLoad]();
    
    [[self barView] finishLoading:[[[self webView] URL] absoluteString]];
    [[self barView] setBackEnabled:[[self webView] canGoBack]];
    [[self barView] setForwardEnabled:[[self webView] canGoForward]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    __weak typeof (self) blockSelf = self;
    
    if ([keyPath isEqualToString:@"estimatedProgress"] && object == [blockSelf webView]) {
        [[blockSelf webView] evaluateJavaScript:@"document.readyState" completionHandler:^(NSString* _Nullable readyState, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"Estimated progress: %f", [[blockSelf webView] estimatedProgress]);
                NSLog(@"document.readyState: %@", readyState);
                
                if (([readyState isEqualToString:@"interactive"] && ![[blockSelf documentReadyState] isEqualToString:@"interactive"]) ||
                    ([[blockSelf webView] estimatedProgress] >= 1.0)) {
                    @try {
                        [[blockSelf webView] removeObserver:blockSelf forKeyPath:@"estimatedProgress"];
                        [blockSelf documentDidBecomeInteractive];
                    }@catch(NSException* exception) {
                        NSLog(@"%@", [exception description]);
                    }
                }
                
                blockSelf.documentReadyState = readyState;
            });
        }];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end

