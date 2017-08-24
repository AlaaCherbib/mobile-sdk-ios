/*   Copyright 2013 APPNEXUS INC
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "ANMediationAdViewController.h"

#import "ANBannerAdView.h"
#import "ANGlobal.h"
#import "ANInterstitialAd.h"
#import "ANLogging.h"
#import "ANMediatedAd.h"
#import "ANPBBuffer.h"
#import "NSString+ANCategory.h"
#import "ANPBContainerView.h"
#import "ANMediationContainerView.h"



@interface ANMediationAdViewController () <ANCustomAdapterBannerDelegate, ANCustomAdapterInterstitialDelegate>

@property (nonatomic, readwrite, strong)  id<ANCustomAdapter>                currentAdapter;
@property (nonatomic, readwrite, assign)  BOOL                               hasSucceeded;
@property (nonatomic, readwrite, assign)  BOOL                               hasFailed;
@property (nonatomic, readwrite, assign)  BOOL                               timeoutCanceled;
@property (nonatomic, readwrite, weak)    id<ANUniversalAdFetcherDelegate>   adViewDelegate;
@property (nonatomic, readwrite, strong)  ANMediatedAd                      *mediatedAd;
@property (nonatomic, readwrite, strong)  NSDictionary                      *pitbullAdForDelayedCapture;

// variables for measuring latency.
@property (nonatomic, readwrite, assign)  NSTimeInterval  latencyStart;
@property (nonatomic, readwrite, assign)  NSTimeInterval  latencyStop;

@property (nonatomic, readwrite, assign)  BOOL  isRegisteredForPitbullScreenCaptureNotifications;

@end

            /* FIX -- update
@interface ANAdFetcher ()
- (NSTimeInterval)getTotalLatency:(NSTimeInterval)stopTime;
@end
                    */



@implementation ANMediationAdViewController

#pragma mark - Lifecycle.

+ (ANMediationAdViewController *)initMediatedAd:(ANMediatedAd *)mediatedAd
                                    withFetcher:(ANUniversalAdFetcher *)fetcher
                                 adViewDelegate:(id<ANUniversalAdFetcherDelegate>)adViewDelegate
{
ANLogMark();
    ANMediationAdViewController *controller = [[ANMediationAdViewController alloc] init];
    controller.adFetcher = fetcher;
    controller.adViewDelegate = adViewDelegate;
    
    if ([controller requestForAd:mediatedAd]) {
        return controller;
    } else {
        return nil;
    }
}

- (BOOL)requestForAd:(ANMediatedAd *)ad {
ANLogMark();
    // variables to pass into the failure handler if necessary
    NSString *className = nil;
    NSString *errorInfo = nil;
    ANAdResponseCode errorCode = ANDefaultCode;
    
    do {
        // check that the ad is non-nil
        if (!ad) {
            errorInfo = @"null mediated ad object";
            errorCode = ANAdResponseUnableToFill;
            break;
        }
        
        self.mediatedAd = ad;
        className = ad.className;
        
        // notify that a mediated class name was received
        ANPostNotifications(kANAdFetcherWillInstantiateMediatedClassNotification, self,
                            @{kANAdFetcherMediatedClassKey: className});
        
        ANLogDebug(@"instantiating_class %@", className);
        
        // check to see if an instance of this class exists
        Class adClass = NSClassFromString(className);
        if (!adClass) {
            errorInfo = @"ClassNotFoundError";
            errorCode = ANAdResponseMediatedSDKUnavailable;
            break;
        }
        
        id adInstance = [[adClass alloc] init];
        if (!adInstance
            || ![adInstance respondsToSelector:@selector(setDelegate:)]
            || ![adInstance conformsToProtocol:@protocol(ANCustomAdapter)]) {
            errorInfo = @"InstantiationError";
            errorCode = ANAdResponseMediatedSDKUnavailable;
            break;
        }
        
        // instance valid - request a mediated ad
        id<ANCustomAdapter> adapter = (id<ANCustomAdapter>)adInstance;
        adapter.delegate = self;
        self.currentAdapter = adapter;
        
        // Grab the size of the ad - interstitials will ignore this value
        CGSize sizeOfCreative = CGSizeMake([ad.width floatValue], [ad.height floatValue]);

        BOOL requestedSuccessfully = [self requestAd:sizeOfCreative
                                     serverParameter:ad.param
                                            adUnitId:ad.adId
                                              adView:self.adViewDelegate];
        
        if (!requestedSuccessfully) {
            // don't add class to invalid networks list for this failure
            className = nil;
            errorInfo = @"ClassCastError";
            errorCode = ANAdResponseMediatedSDKUnavailable;
            break;
        }
        
    } while (false);
    
    
    if (errorCode != ANDefaultCode) {
        [self handleInstantiationFailure:className
                               errorCode:errorCode errorInfo:errorInfo];
        return NO;
    }
    
    // otherwise, no error yet
    // wait for a mediation adapter to hit one of our callbacks.
    return YES;
}


- (void)handleInstantiationFailure:(NSString *)className
                         errorCode:(ANAdResponseCode)errorCode
                         errorInfo:(NSString *)errorInfo
{
    if ([errorInfo length] > 0) {
        ANLogError(@"mediation_instantiation_failure %@", errorInfo);
    }
    if ([className length] > 0) {
        if ([self.adViewDelegate isKindOfClass:[ANBannerAdView class]]) {
            ANLogWarn(@"mediation_adding_invalid_for_media_type %@ %@", className, @"banner");
            [[self class] addBannerInvalidNetwork:className];
        } else if ([self.adViewDelegate isKindOfClass:[ANInterstitialAd class]]) {
            ANLogWarn(@"mediation_adding_invalid_for_media_type %@ %@", className, @"interstitial");
            [[self class] addInterstitialInvalidNetwork:className];
        } else {
            ANLogDebug(@"Instantiation failure for unknown ad view, could not add %@ to an invalid networks list", className);
        }
    }
    
    [self didFailToReceiveAd:errorCode];
}


- (void)setAdapter:adapter {
    self.currentAdapter = adapter;
}


- (void)clearAdapter {
ANLogMark();
    if (self.currentAdapter)
        self.currentAdapter.delegate = nil;
    self.currentAdapter = nil;
    self.hasSucceeded = NO;
    self.hasFailed = YES;
    self.adFetcher = nil;
    self.adViewDelegate = nil;
    self.mediatedAd = nil;
    [self cancelTimeout];
    ANLogInfo(@"mediation_finish");
}

- (BOOL)requestAd:(CGSize)size
  serverParameter:(NSString *)parameterString
         adUnitId:(NSString *)idString
           adView:(id<ANUniversalAdFetcherDelegate>)adView
{
ANLogMark();
    // create targeting parameters object from adView properties
    ANTargetingParameters *targetingParameters = [[ANTargetingParameters alloc] init];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    targetingParameters.customKeywords = adView.customKeywords;
#pragma clang diagnostic pop
    targetingParameters.age = adView.age;
    targetingParameters.gender = adView.gender;
    targetingParameters.location = adView.location;
    targetingParameters.idforadvertising = ANUDID();

    //
    if ([adView isKindOfClass:[ANBannerAdView class]]) {
        // make sure the container and protocol match
        if (    [[self.currentAdapter class] conformsToProtocol:@protocol(ANCustomAdapterBanner)]
             && [self.currentAdapter respondsToSelector:@selector(requestBannerAdWithSize:rootViewController:serverParameter:adUnitId:targetingParameters:)])
        {
            
            [self markLatencyStart];
            [self startTimeout];

            ANBannerAdView *banner = (ANBannerAdView *)adView;
            id<ANCustomAdapterBanner> bannerAdapter = (id<ANCustomAdapterBanner>) self.currentAdapter;
            [bannerAdapter requestBannerAdWithSize:size
                                rootViewController:banner.rootViewController
                                   serverParameter:parameterString
                                          adUnitId:idString
                               targetingParameters:targetingParameters];
            return YES;
        } else {
            ANLogError(@"instance_exception %@", @"CustomAdapterBanner");
        }

    } else if ([adView isKindOfClass:[ANInterstitialAd class]]) {
        // make sure the container and protocol match
        if (    [[self.currentAdapter class] conformsToProtocol:@protocol(ANCustomAdapterInterstitial)]
             && [self.currentAdapter respondsToSelector:@selector(requestInterstitialAdWithParameter:adUnitId:targetingParameters:)])
        {
            
            [self markLatencyStart];
            [self startTimeout];
            
            id<ANCustomAdapterInterstitial> interstitialAdapter = (id<ANCustomAdapterInterstitial>) self.currentAdapter;
            [interstitialAdapter requestInterstitialAdWithParameter:parameterString
                                                           adUnitId:idString
                                                targetingParameters:targetingParameters];
            return YES;
        } else {
            ANLogError(@"instance_exception %@", @"CustomAdapterInterstitial");
        }

    } else {
        ANLogError(@"UNRECOGNIZED Entry Point classname.  (%@)", [adView class]);
    }

    
    // executes iff request was unsuccessful
    return NO;
}




#pragma mark - Invalid Networks

+ (NSMutableSet *)bannerInvalidNetworks {
    static dispatch_once_t bannerInvalidNetworksToken;
    static NSMutableSet *bannerInvalidNetworks;
    dispatch_once(&bannerInvalidNetworksToken, ^{
        bannerInvalidNetworks = [[NSMutableSet alloc] init];
    });
    return bannerInvalidNetworks;
}

+ (NSMutableSet *)interstitialInvalidNetworks {
    static dispatch_once_t interstitialInvalidNetworksToken;
    static NSMutableSet *interstitialInvalidNetworks;
    dispatch_once(&interstitialInvalidNetworksToken, ^{
        interstitialInvalidNetworks = [[NSMutableSet alloc] init];
    });
    return interstitialInvalidNetworks;
}

+ (void)addBannerInvalidNetwork:(NSString *)network {
    NSMutableSet *invalidNetworks = (NSMutableSet *)[[self class] bannerInvalidNetworks];
    [invalidNetworks addObject:network];
}

+ (void)addInterstitialInvalidNetwork:(NSString *)network {
    NSMutableSet *invalidNetworks = (NSMutableSet *)[[self class] interstitialInvalidNetworks];
    [invalidNetworks addObject:network];
}




#pragma mark - ANCustomAdapterBannerDelegate

- (void)didLoadBannerAd:(UIView *)view {
ANLogMark();
	[self didReceiveAd:view];
}



#pragma mark - ANCustomAdapterInterstitialDelegate

- (void)didLoadInterstitialAd:(id<ANCustomAdapterInterstitial>)adapter {
ANLogMark();
	[self didReceiveAd:adapter];
}



#pragma mark - ANCustomAdapterDelegate

- (void)didFailToLoadAd:(ANAdResponseCode)errorCode {
ANLogMark();
    [self didFailToReceiveAd:errorCode];
}

- (void)adWasClicked {
ANLogMark();
    if (self.hasFailed) return;
    [self runInBlock:^(void) {
        [self.adViewDelegate adWasClicked];
    }];
}

- (void)willPresentAd {
ANLogMark();
    if (self.hasFailed) return;
    [self runInBlock:^(void) {
        [self.adViewDelegate adWillPresent];
    }];
}

- (void)didPresentAd {
ANLogMark();
    if (self.hasFailed) return;
    [self runInBlock:^(void) {
        [self.adViewDelegate adDidPresent];
    }];
}

- (void)willCloseAd {
ANLogMark();
    if (self.hasFailed) return;
    [self runInBlock:^(void) {
        [self.adViewDelegate adWillClose];
    }];
}

- (void)didCloseAd {
ANLogMark();
    if (self.hasFailed) return;
    [self runInBlock:^(void) {
        [self.adViewDelegate adDidClose];
    }];
}

- (void)willLeaveApplication {
ANLogMark();
    if (self.hasFailed) return;
    [self runInBlock:^(void) {
        [self.adViewDelegate adWillLeaveApplication];
    }];
}

- (void)failedToDisplayAd {
ANLogMark();
    if (self.hasFailed) return;
    [self runInBlock:^(void) {
        if ([self.adViewDelegate conformsToProtocol:@protocol(ANInterstitialAdViewInternalDelegate)]) {
            id<ANInterstitialAdViewInternalDelegate> interstitialDelegate = (id<ANInterstitialAdViewInternalDelegate>)self.adViewDelegate;
            [interstitialDelegate adFailedToDisplay];
        }
    }];
}



#pragma mark - helper methods

- (BOOL)checkIfHasResponded {
    // we received a callback from mediation adaptor, cancel timeout
    [self cancelTimeout];
    // don't succeed or fail more than once per mediated ad
    return (self.hasSucceeded || self.hasFailed);
}

- (void)didReceiveAd:(id)adObject
{
ANLogMark();
    if ([self checkIfHasResponded])  { return; }

    if (!adObject) {
        [self didFailToReceiveAd:ANAdResponseInternalError];
        return;
    }

    //
    self.hasSucceeded = YES;
    [self markLatencyStop];
    
    ANLogDebug(@"received an ad from the adapter");

    if ([adObject isKindOfClass:[UIView class]]) {
        UIView *adView = (UIView *)adObject;
        ANMediationContainerView *containerView = [[ANMediationContainerView alloc] initWithMediatedView:adView];
        containerView.controller = self;
        adObject = containerView;
    }
    
    // save auctionInfo for the winning ad
    NSString *auctionID = [ANPBBuffer saveAuctionInfo:self.mediatedAd.auctionInfo];
    
    if (auctionID) {
        [ANPBBuffer addAdditionalInfo:@{kANPBBufferMediatedNetworkNameKey: self.mediatedAd.className,
                                        kANPBBufferMediatedNetworkPlacementIDKey: self.mediatedAd.adId}
                         forAuctionID:auctionID];
        if ([adObject isKindOfClass:[UIView class]]) {
            UIView *adView = (UIView *)adObject;
            [ANPBBuffer addAdditionalInfo:@{kANPBBufferAdWidthKey: @(CGRectGetWidth(adView.frame)),
                                            kANPBBufferAdHeightKey: @(CGRectGetHeight(adView.frame))}
                             forAuctionID:auctionID];
            ANPBContainerView *containerView = [[ANPBContainerView alloc] initWithContentView:adView];
            adObject = containerView;
        }
    }
    
    [self finish:ANAdResponseSuccessful withAdObject:adObject auctionID:auctionID];

    // if auctionInfo was present and had an auctionID,
    // screenshot the view. For banners, do it here
    if (auctionID && [adObject isKindOfClass:[UIView class]]) {
        if ([self.adViewDelegate respondsToSelector:@selector(transitionInProgress)]) {
            NSNumber *transitionInProgress = [self.adViewDelegate performSelector:@selector(transitionInProgress)];
            if ([transitionInProgress boolValue] == YES) {
                self.pitbullAdForDelayedCapture = @{auctionID: adObject};
                [self registerForPitbullScreenCaptureNotifications];
            }
        }
        
        if (!self.pitbullAdForDelayedCapture) {
            [ANPBBuffer captureDelayedImage:adObject forAuctionID:auctionID];
        }
    }
}

- (void)didFailToReceiveAd:(ANAdResponseCode)errorCode {
ANLogMark();
    if ([self checkIfHasResponded]) return;
    [self markLatencyStop];
    self.hasFailed = YES;
    [self finish:errorCode withAdObject:nil auctionID:nil];
}


- (void)finish: (ANAdResponseCode)errorCode
  withAdObject: (id)adObject
     auctionID: (NSString *)auctionID
{
ANLogMark();
    // use queue to force return
    [self runInBlock:^(void) {
        ANUniversalAdFetcher *fetcher = self.adFetcher;
        NSString *responseURLString = [self createResponseURLRequest:self.mediatedAd.responseURL reason:errorCode];

        // fireResponseURL will clear the adapter if fetcher exists
        if (!fetcher) {
            [self clearAdapter];
        }
        [fetcher fireResponseURL:responseURLString reason:errorCode adObject:adObject auctionID:auctionID];
    }];
}


- (void)runInBlock:(void (^)())block {
ANLogMark();
    // nothing keeps 'block' alive, so we don't have a retain cycle
    dispatch_async(dispatch_get_main_queue(), ^{
        block();
    });
}

- (NSString *)createResponseURLRequest:(NSString *)baseString reason:(int)reasonCode
                    //FIX are latency values correct when medaition adapter is invoked but failes or timesout?
{
ANLogMark();
    if ([baseString length] < 1) {
        return @"";
    }
    
    // append reason code
    NSString *responseURLString = [baseString an_stringByAppendingUrlParameter: @"reason"
                                                                      value: [NSString stringWithFormat:@"%d",reasonCode]];
    
    // append idfa
    responseURLString = [responseURLString an_stringByAppendingUrlParameter: @"idfa"
                                                                value: ANUDID()];
    
    // append latency measurements
    NSTimeInterval latency       = [self getLatency] * 1000; // secs to ms
    NSTimeInterval totalLatency  = [self getTotalLatency] * 1000; // secs to ms
    
    if (latency > 0) {
        responseURLString = [responseURLString an_stringByAppendingUrlParameter: @"latency"
                                                                    value: [NSString stringWithFormat:@"%.0f", latency]];
    }
    if (totalLatency > 0) {
        responseURLString = [responseURLString an_stringByAppendingUrlParameter: @"total_latency"
                                                                    value :[NSString stringWithFormat:@"%.0f", totalLatency]];
    }

ANLogMarkMessage(@"responseURLString=%@", responseURLString);
    return responseURLString;
}



#pragma mark - Timeout handler              
                        //FIX -- status of this?

- (void)startTimeout {
ANLogMark();
    if (self.timeoutCanceled) return;
    __weak ANMediationAdViewController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 kAppNexusMediationNetworkTimeoutInterval
                                 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
                       ANMediationAdViewController *strongSelf = weakSelf;
                       if (!strongSelf || strongSelf.timeoutCanceled) return;
                       ANLogWarn(@"mediation_timeout");
                       [strongSelf didFailToReceiveAd:ANAdResponseInternalError];
                   });
    
}

- (void)cancelTimeout {
ANLogMark();
    self.timeoutCanceled = YES;
}



# pragma mark - Latency Measurement

/**
 * Should be called immediately after mediated SDK returns
 * from `requestAd` call.
 */
- (void)markLatencyStart {
ANLogMark();
    self.latencyStart = [NSDate timeIntervalSinceReferenceDate];
}

/**
 * Should be called immediately after mediated SDK
 * calls either of `onAdLoaded` or `onAdFailed`.
 */
- (void)markLatencyStop {
ANLogMark();
    self.latencyStop = [NSDate timeIntervalSinceReferenceDate];
}

/**
 * The latency of the call to the mediated SDK.
 */
- (NSTimeInterval)getLatency {
ANLogMark();
    if ((self.latencyStart > 0) && (self.latencyStop > 0)) {
        return (self.latencyStop - self.latencyStart);
    }
    // return -1 if invalid.
    return -1;
}

/**
 * The running total latency of the ad call.
 */
- (NSTimeInterval)getTotalLatency {
ANLogMark();
    if (self.adFetcher && (self.latencyStop > 0)) {
        return [self.adFetcher getTotalLatency:self.latencyStop];
    }
    // return -1 if invalid.
    return -1;
}



#pragma mark - Pitbull Image Capture Transition Adjustments

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (object == self.adViewDelegate) {
        NSNumber *transitionInProgress = change[NSKeyValueChangeNewKey];
        if ([transitionInProgress boolValue] == NO) {
            [self unregisterFromPitbullScreenCaptureNotifications];
            [self dispatchPitbullScreenCapture];
        }
    }
}

- (void)registerForPitbullScreenCaptureNotifications {
    if (!self.isRegisteredForPitbullScreenCaptureNotifications) {
        NSObject *object = self.adViewDelegate;
        [object addObserver:self
                 forKeyPath:@"transitionInProgress"
                    options:NSKeyValueObservingOptionNew
                    context:nil];
        self.isRegisteredForPitbullScreenCaptureNotifications = YES;
    }
}

- (void)unregisterFromPitbullScreenCaptureNotifications {
    if (self.isRegisteredForPitbullScreenCaptureNotifications) {
        NSObject *object = self.adViewDelegate;
        @try {
            [object removeObserver:self
                        forKeyPath:@"transitionInProgress"];
        }
        @catch (NSException * __unused exception) {}
        self.isRegisteredForPitbullScreenCaptureNotifications = NO;
    }
}

- (void)dispatchPitbullScreenCapture {
    if (self.pitbullAdForDelayedCapture) {
        [self.pitbullAdForDelayedCapture enumerateKeysAndObjectsUsingBlock:^(NSString *auctionID, UIView *view, BOOL *stop) {
            [ANPBBuffer captureImage:view
                        forAuctionID:auctionID];
        }];
        self.pitbullAdForDelayedCapture = nil;
    }
}

- (void)dealloc {
ANLogMark();
    [self clearAdapter];
    [self unregisterFromPitbullScreenCaptureNotifications];
}

@end
