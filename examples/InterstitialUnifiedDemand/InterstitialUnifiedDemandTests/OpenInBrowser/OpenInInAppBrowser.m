/* Copyright 2015 APPNEXUS INC
 
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

#define interstitial [[[UIApplication sharedApplication] keyWindow] accessibilityElementWithLabel:@"interstitial"]
#define player [[[UIApplication sharedApplication] keyWindow] accessibilityElementWithLabel:@"player"]

#import "OpenInInAppBrowser.h"
#import <KIF/KIFTestCase.h>
#import "ANInterstitialAd.h"

@interface OpenInInAppBrowser()<ANVideoAdDelegate, ANInterstitialAdDelegate>{
    ANInterstitialAd *interstitialAdView;
    BOOL isDelegateFired;
}

@end

@implementation OpenInInAppBrowser

- (void)setUp{
    
    isDelegateFired = NO;
    [tester waitForViewWithAccessibilityLabel:@"interstitial"];
    
    [self setupDelegatesForVideo];

    int breakCounter = 5;
    
    while (interstitial && breakCounter--) {
        [self performClickOnInterstitial];
        [tester waitForTimeInterval:2.0];
    }
    
    if (!interstitial) {
        [tester waitForViewWithAccessibilityLabel:@"player"];
        if (!player) {
            NSLog(@"Test: Not able to load the video.");
        }
    }
}

static dispatch_semaphore_t waitForDelegateToFire;

- (void) test1OpenClickInInAppBrowser{
    
    waitForDelegateToFire = dispatch_semaphore_create(0);
    
    [self performSelector:@selector(notifySemaphoreForRelease) withObject:nil afterDelay:5.0];
    
    [tester tapViewWithAccessibilityLabel:@"player"];
    
    dispatch_semaphore_wait(waitForDelegateToFire, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));

    XCTAssertFalse(isDelegateFired, @"Click opened in Native Browser. failed case.");
    
}

-(void) setupDelegatesForVideo{
    
    UIViewController *controller = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    if (controller) {
        SEL aSelector = NSSelectorFromString(@"interstitialAd");
        interstitialAdView = (ANInterstitialAd *)[controller performSelector:aSelector];
        interstitialAdView.opensInNativeBrowser = NO;
        interstitialAdView.delegate = self;
        interstitialAdView.videoAdDelegate = self;
    }
}

- (void) performClickOnInterstitial{
    if (interstitial) {
        [tester tapViewWithAccessibilityLabel:@"interstitial"];
    }
}

- (void)adWillLeaveApplication:(id<ANAdProtocol>)ad{
    NSLog(@"Test: ad will leave application.");
    isDelegateFired = YES;
}

- (void) notifySemaphoreForRelease{
    dispatch_semaphore_signal(waitForDelegateToFire);
}

@end
