# WebXR Viewer Privacy Notice
 
### _Effective June 1, 2018_
 
At Mozilla, we adhere to the practices outlined in the Mozilla [Privacy Policy](https://www.mozilla.org/privacy/) for how we receive, handle and share information we collect from the WebXR Viewer.

## Things you should know

Mozilla’s WebXR Viewer is an augmented reality (AR) tool that lets you create and run AR experiences.  When you use the Viewer, we collect certain information so that we can improve our product. 

- *Information We Collect Automatically When You Use WebXR Viewer*: The WebXR Viewer starts sending Mozilla data once you install the application and start using it on your device. This includes:
   - _Interaction data_: The WebXR Viewer sends data to us about your interactions with the application. This includes information such as when you launch the WebXR Viewer, when you background or foreground the Viewer, and when you load a webpage that activates the AR capabilities of the Viewer. We don’t track any of the webpages you access through the Viewer.
   - _Technical data_: The WebXR Viewer sends data to us about your WebXR Viewer version, device operating system, and basic information about crashes and errors. When the WebXR Viewer sends data to us, your IP address is temporarily collected as part of our server logs.

   Read the telemetry documentation for [iOS](Telemetry.md).

- *Turning-off Data Collection*: Data collection can be disabled by you at anytime, which will stop corresponding data collection by the WebXR Viewer. This can be done by going to the Settings page in the WebXR Viewer application, which directs you to the iOS Settings panel.  

- *Non-Mozilla Services*: We use Apple ARKit which integrates the iOS device camera and motion features to produce augmented reality experiences in the WebXR Viewer. Apple may collect information about your location as part of its ARKit functionality. To learn more about Apple’s data collection practices related to this integration, we encourage you to review their [Privacy Policy](https://www.apple.com/legal/privacy/en-ww/). 

- *AR Data Provided to Web Pages*: When web pages use AR, they receive information from ARKit via the WebXR API. You can learn more about ARKit on [Apple's ARKit Web Page](https://developer.apple.com/arkit/).  All web pages will know the position and motion of the phone in the room around you (but not your real-world location), as well as any vertical or horizontal planes that ARKit detects (such as walls, floors and tables). Mozilla does not receive this information.

- *Advanced AR Features the require additional Permission*: ARKit can recognize images provided by a web page (such as a movie poster or picture in a magazine), and can use the TrueDepth Camera to find and track the face of the person holding the phone. The WebXR Viewer will ask for your permission (for "*Access to World Sensing*") before letting web pages use these features. If you approve, the page will receive the position of the image in the world when it is recognized, or the position of the face along with a simple 3D model of a generic human face that ARKit tries to align with the face the TrueDepth camera sees.  ARKit and the WebXR Viewer does not ever provide the raw data from the TrueDepth camera to web pages. Mozilla does not receive this information.  If you choose, WebXR Viewer will remember your decision to allow world sensing for individual sites on your phone (Mozilla does not receive this data); those decisions can be forgotten by using the Reset Allowed World Sensing option in the Settings menu.

- *Loading of ARKit World Maps": ARKit creates a "3D map" of the space near the user as you use it, to allow it to understand the motion of the phone, place anchors in the world, and detect surfaces. If the user has giving permission (for *Access to World Sensing*), a web page can request that ARKit load a saved map and attempt to use it for tracking.  The maps cannot be created with the WebXR Viewer, but are created by developers using a custom version of the application. These maps are used to create persistent content and shared experiences, by ensuring all users in a known space use the same map of the space.  The WebXR Viewer does not allow web pages to retrieve the world map, nor does Mozilla receive any information about these maps.  Developers who create maps of spaces manage those themselves, and can load them into the WebXR Viewer and ask ARKit to use them if the user has given permission.

- *Direct Camera Access*:  If a web page wants to access the video images from the camera, the WebXR Viewer will ask for your permission before providing video images to the web page. Mozilla does not receive this information.

[Legal](https://www.mozilla.org/about/legal/) [Privacy](https://www.mozilla.org/en-US/privacy/) [Terms](https://www.mozilla.org/en-US/about/legal/terms/mozilla/) [Cookies](https://www.mozilla.org/privacy/websites/#cookies)
