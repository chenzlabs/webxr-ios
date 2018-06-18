#import <Foundation/Foundation.h>
#import "ARKHelper.h"
#import "AppState.h"

// The ARSessionConfiguration object passed to the run(_:options:) method is not supported by the current device.
#define UNSUPPORTED_CONFIGURATION_ARKIT_ERROR_CODE 100

// A sensor required to run the session is not available.
#define SENSOR_UNAVAILABLE_ARKIT_ERROR_CODE 101

// A sensor failed to provide the required input.
#define SENSOR_FAILED_ARKIT_ERROR_CODE 102

// The user has denied your app permission to use the device camera.
#define CAMERA_ACCESS_NOT_AUTHORIZED_ARKIT_ERROR_CODE 103

// World tracking has encountered a fatal error.
#define WORLD_TRACKING_FAILED_ARKIT_ERROR_CODE 200

/**
 Enum representing the world sensing authorization status
 
 - SendWorldSensingDataAuthorizationStateNotDetermined: The user didn't say anything about the world sensing
 - SendWorldSensingDataAuthorizationStateAuthorized: The user allowed sending wold sensing data
 - SendWorldSensingDataAuthorizationStateDenied: The user denied sending world sensing data
 */
typedef NS_ENUM(NSUInteger, SendWorldSensingDataAuthorizationState)
{
    SendWorldSensingDataAuthorizationStateNotDetermined,
    SendWorldSensingDataAuthorizationStateAuthorized,
    SendWorldSensingDataAuthorizationStateDenied
};

/**
 An enum representing the ARKit session state

 - ARKSessionUnknown: We don't know about the session state, probably it's been initiated but not ran yet
 - ARKSessionPaused: The session is paused
 - ARKSessionRunning: The session is running
 */
typedef NS_ENUM(NSUInteger, ARKitSessionState)
{
    ARKSessionUnknown,
    ARKSessionPaused,
    ARKSessionRunning
};

typedef NS_ENUM(NSUInteger, ARKType)
{
    ARKMetal,
    ARKSceneKit
};

@class ARKController;
typedef void (^DidUpdate)(ARKController *);
typedef void (^DidFailSession)(NSError *);
typedef void (^DidInterrupt)(BOOL);
typedef void (^DidChangeTrackingState)(NSString *state);
typedef void (^DidAddPlaneAnchors)(void);
typedef void (^DidRemovePlaneAnchors)(void);
typedef void (^DidUpdateWindowSize)(void);
typedef void (^DetectionImageCreatedCompletionType)(BOOL success, NSString* errorString);
typedef void (^ActivateDetectionImageCompletionBlock)(BOOL success, NSString* errorString, NSDictionary* detectedImageAnchor);
typedef void (^DetectionObjectCreatedCompletionType)(BOOL success, NSString* errorString);
typedef void (^ActivateDetectionObjectCompletionBlock)(BOOL success, NSString* errorString, NSDictionary* detectedObjectAnchor);

@interface ARKController : NSObject

@property(copy) DidUpdate didUpdate;
@property(copy) DidInterrupt didInterrupt;
@property(copy) DidFailSession didFailSession;
@property(copy) DidChangeTrackingState didChangeTrackingState;
@property(copy) DidAddPlaneAnchors didAddPlaneAnchors;
@property(copy) DidRemovePlaneAnchors didRemovePlaneAnchors;
@property(copy) DidUpdateWindowSize didUpdateWindowSize;
@property UIInterfaceOrientation interfaceOrientation;

/**
 Flag indicating if we should inform the JS side about a window size update
 within the current AR Frame update. It's set to YES when the device orientation changes.
 The idea is to only send this kind of update once a Frame.
 */
@property(nonatomic) BOOL shouldUpdateWindowSize;

/**
 Enum indicating the AR session state
 @see ARKitSessionState
 */
@property ARKitSessionState arSessionState;

/**
 A flag representing whether the user allowed the app to send computer vision data to the web page
 */
@property(nonatomic) bool computerVisionDataEnabled;

/**
 Enum representing the world sensing data sending authorization status
 @see SendWorldSensingDataAuthorizationState
 */
@property(nonatomic) SendWorldSensingDataAuthorizationState sendingWorldSensingDataAuthorizationStatus;

- (instancetype)initWithType:(ARKType)type rootView:(UIView *)rootView;

/**
 Updates the hit test focus point and updates the orientation

 @param size the size of the new frame
 */
- (void)viewWillTransitionToSize:(CGSize)size;

/**
 Updates the internal AR Request dictionary
 Creates an ARKit configuration object
 Runs the ARKit session
 Updates the session state to running
 Updates the show mode and the show options

 @param state The current app state
 */
- (void)startSessionWithAppState:(AppState *)state;

/**
 Updates the internal AR Request dictionary and the configuration
 Runs the session
 Updates the session state to running
 Updates the show mode and the show options
 
 @param state The current app state
 */
- (void)resumeSessionWithAppState: (AppState*)state;

/**
 Pauses the AR session and sets the arSessionState to paused
 */
- (void)pauseSession;

/**
 ARKit data creates a copy of the current AR data and returns it

 @return the dictionary that's going to be sent to JS
 */
- (NSDictionary *)arkData;

/**
 computer vision data creates a copy of the current CV data and returns it

 @return the dictionary of CV data that's going to be sent to JS
 */
- (NSDictionary*)computerVisionData;

- (NSTimeInterval)currentFrameTimeInMilliseconds;

- (void)setShowMode:(ShowMode)mode;

- (void)setShowOptions:(ShowOptions)options;

/**
 Performs a hit test over the scene

 @param point source point for the ray casting in normalized coordinates
 @param type A bit mask representing the hit test types to be considered
 @return an array of hit tests
 */
- (NSArray *)hitTestNormPoint:(CGPoint)point types:(NSUInteger)type;

/**
 Adds a "regular" anchor to the session

 @param userGeneratedAnchorID the ID the user wants this new anchor to have
 @param transform the transform of the anchor
 @return YES if the anchorID didn't exist already
 */
- (BOOL)addAnchor:(NSString *)userGeneratedAnchorID transform:(NSArray *)transform;

/// Removes the anchors with the ids passed as parameter from the scene.
/// @param anchorIDsToDelete An array of anchor IDs. These can be both ARKit-generated anchorIDs or user-generated anchorIDs
- (void)removeAnchors:(NSArray *)anchorIDsToDelete;

/**
 Get an array of dictionaries representing planes

 @return an array of dictionaries representing planes
 */
- (NSArray *)currentPlanesArray;

- (NSString *)trackingState;

- (void)removeAllAnchors;

- (void)removeAllAnchorsExceptPlanes;

/**
 Updates the internal AR request dictionary.
 Creates a AR configuration object based on the request.
 Runs the session.
 Sets the session status to running.

 @param state the app state
 */
- (void)runSessionWithAppState:(AppState *)state;

- (void)runSessionRemovingAnchorsWithAppState:(AppState *)state;

- (void)runSessionResettingTrackingAndRemovingAnchorsWithAppState:(AppState *)state;

/**
 Remove all the plane anchors further than the value hosted in NSUserdDefaults with the
 key "distantAnchorsDistanceKey"
 */
- (void)removeDistantAnchors;

/**
 If SendWorldSensingDataAuthorizationStateAuthorized, creates an ARImages using the
 information in the dictionary as input. Otherwise, enqueue the request for when the user
 accepts and SendWorldSensingDataAuthorizationStateAuthorized is set

 @param referenceImageDictionary the dictionary representing the ARReferenceImage
 @param completion the promise to be resolved when the image is created
 */
- (void)createDetectionImage:(NSDictionary *)referenceImageDictionary completion:(DetectionImageCreatedCompletionType)completion;

/**
 Adds the image to the set of references images in the configuration object and re-runs the session.
 
 - If the image hasn't been created, it calls the promise with an error string.
 
 - It also fails when the current session is not of type ARWorldTrackingConfiguration
 
 - If the image trying to be activated was already activated but not yet detected, respond with an error string in the callback
 
 - If the image trying to be activated was already activated and yet detected, we remove it from the session, so
 it can be detected again by ARKit
 
 @param imageName the name of the image to be added to the session. It must have been previously created with createImage
 @param completion a completion block acting a promise
 */
- (void)activateDetectionImage:(NSString *)imageName completion:(ActivateDetectionImageCompletionBlock)completion;

/**
 Removes the reference image from the current set of reference images and re-runs the session
 
 - It fails when the current session is not of type ARWorldTrackingConfiguration
 
 - It fails when the image trying to be deactivated is not in the current set of detection images
 
 - It fails when the image trying to be deactivated was already detected
 
 - It fails when the image trying to be deactivated is still active

 @param imageName The name of the image to be deactivated
 @param completion The promise that will be called with the outcome of the deactivation
 */
- (void)deactivateDetectionImage:(NSString *)imageName completion:(DetectionImageCreatedCompletionType)completion;

/**
 Destroys the detection image
 
 - Fails if the image to be destroy doesn't exist

 @param imageName The name of the image to be destroyed
 @param completion The completion block that will be called with the outcome of the destroy
 */
- (void)destroyDetectionImage:(NSString *)imageName completion:(DetectionImageCreatedCompletionType)completion;



/**
 If SendWorldSensingDataAuthorizationStateAuthorized, creates an ARReferenceObject using the
 information in the dictionary as input. Otherwise, enqueue the request for when the user
 accepts and SendWorldSensingDataAuthorizationStateAuthorized is set
 
 @param referenceObjectDictionary the dictionary representing the ARReferenceObject
 @param completion the promise to be resolved when the image is created
 */
- (void)createDetectionObject:(NSDictionary *)referenceObjectDictionary completion:(DetectionObjectCreatedCompletionType)completion;

/**
 Adds the object to the set of references objects in the configuration object and re-runs the session.
 
 - If the object hasn't been created, it calls the promise with an error string.
 
 - It also fails when the current session is not of type ARWorldTrackingConfiguration
 
 - If the object trying to be activated was already activated but not yet detected, respond with an error string in the callback
 
 - If the object trying to be activated was already activated and yet detected, we remove it from the session, so
 it can be detected again by ARKit
 
 @param objectName the name of the object to be added to the session. It must have been previously created with createObject
 @param completion a completion block acting a promise
 */
- (void)activateDetectionObject:(NSString *)objectName completion:(ActivateDetectionObjectCompletionBlock)completion;

/**
 Removes the reference object from the current set of reference objects and re-runs the session
 
 - It fails when the current session is not of type ARWorldTrackingConfiguration
 
 - It fails when the object trying to be deactivated is not in the current set of detection objects
 
 - It fails when the object trying to be deactivated was already detected
 
 - It fails when the object trying to be deactivated is still active
 
 @param objectName The name of the object to be deactivated
 @param completion The promise that will be called with the outcome of the deactivation
 */
- (void)deactivateDetectionObject:(NSString *)objectName completion:(DetectionImageCreatedCompletionType)completion;

/**
 Destroys the detection object
 
 - Fails if the object to be destroy doesn't exist
 
 @param objectName The name of the object to be destroyed
 @param completion The completion block that will be called with the outcome of the destroy
 */
- (void)destroyDetectionObject:(NSString *)objectName completion:(DetectionImageCreatedCompletionType)completion;





- (void)setSendingWorldSensingDataAuthorizationStatus:(SendWorldSensingDataAuthorizationState)sendingWorldSensingDataAuthorizationStatus;

/**
 Removes all the anchors in the curren session.
 
 If the current session is not of class ARFaceTrackingConfiguration, create a
 ARFaceTrackingConfiguration and run the session with it
 
 Otherwise, create a ARWorldTrackingConfiguration, add the images that were not detected
 in the previous ARWorldTrackingConfiguration session, and run the session
 */
- (void)switchCameraButtonTapped;

+ (BOOL)supportsARFaceTrackingConfiguration;

@end

