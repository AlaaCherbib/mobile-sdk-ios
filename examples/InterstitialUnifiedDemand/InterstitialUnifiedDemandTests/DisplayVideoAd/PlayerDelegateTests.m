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

#import "PlayerDelegateTests.h"
#import <KIF/KIFTestCase.h>
#import "ANInterstitialAd.h"

@interface PlayerDelegateTests()<ANVideoAdDelegate, ANInterstitialAdDelegate>{
    ANInterstitialAd *interstitialAdView;
    BOOL isAdStartedPlayingVideo;
    BOOL isFirstQuartileDone;
    BOOL isMidPointQuartileDone;
    BOOL isthirdQuartileDone;
    BOOL isCreativeViewDone;
    BOOL isPlayingCompelete;
}

@property (nonatomic, strong) XCTestExpectation *expectation;

@end

@implementation PlayerDelegateTests

- (void)setUp{
    [tester waitForViewWithAccessibilityLabel:@"interstitial"];
    [self setupDelegatesForVideo];
    
    int breakCounter = 5;
    
    while (interstitial && breakCounter--) {
        [self performClickOnInterstitial];
        [tester waitForTimeInterval:2.0];
    }
    
    self.expectation = [self expectationWithDescription:@"Waiting for delegates to be fired."];
    if (!interstitial) {
        [tester waitForViewWithAccessibilityLabel:@"player"];
        if (!player) {
            NSLog(@"Test: Not able to load the video.");
        }
    }
    
}

- (void)tearDown{
    interstitialAdView.delegate = nil;
    interstitialAdView.videoAdDelegate = nil;
    interstitialAdView = nil;
    isAdStartedPlayingVideo = NO;
    isCreativeViewDone = NO;
    isFirstQuartileDone = NO;
    isMidPointQuartileDone = NO;
    isthirdQuartileDone = NO;
    isPlayingCompelete = NO;
    self.expectation = nil;
}

- (void) test1PlayerRelatedDelegates{
    
    [self waitForExpectationsWithTimeout:100.0 handler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"%@", error.description);
        }
    }];

    XCTAssertTrue(isAdStartedPlayingVideo, @"Ad failed to start video.");
    XCTAssertTrue(isFirstQuartileDone, @"Ad did not play till first quartile.");
    XCTAssertTrue(isMidPointQuartileDone, @"Ad did not play till mid point quartile.");
    XCTAssertTrue(isthirdQuartileDone, @"Ad did not play till third quartile.");
    XCTAssertTrue(isPlayingCompelete, @"Ad did not finish playing video till the end.");
}

-(void) setupDelegatesForVideo{
    
    UIViewController *controller = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    if (controller) {
        SEL aSelector = NSSelectorFromString(@"interstitialAd");
        interstitialAdView = (ANInterstitialAd *)[controller performSelector:aSelector];
        interstitialAdView.delegate = self;
        interstitialAdView.videoAdDelegate = self;
    }
}

- (void) performClickOnInterstitial{
    if (interstitial) {
        [tester tapViewWithAccessibilityLabel:@"interstitial"];
    }
}

- (void)adDidReceiveAd:(id<ANAdProtocol>)ad{
    NSLog(@"Test: ad received ad.");
}

- (void)adStartedPlayingVideo:(id<ANAdProtocol>)ad{
    NSLog(@"Test: video ad started playing video.");
    isAdStartedPlayingVideo = YES;
}

- (void)adFinishedQuartileEvent:(ANVideoEvent)videoEvent withAd:(id<ANAdProtocol>)ad{
    switch (videoEvent) {
        case ANVideoEventQuartileFirst:
            isFirstQuartileDone = YES;
            break;
        case ANVideoEventQuartileMidPoint:
            isMidPointQuartileDone = YES;
            break;
        case ANVideoEventQuartileThird:
            isthirdQuartileDone = YES;
            break;
        default:
            break;
    }
}

- (void)adFinishedPlayingCompleteVideo:(id<ANAdProtocol>)ad{
    NSLog(@"Test: Video finished playing complete video.");
    isPlayingCompelete = YES;
    [self.expectation fulfill];
}

@end
