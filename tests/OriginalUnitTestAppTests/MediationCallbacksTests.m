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

#import "ANBaseTestCase.h"
#import "ANMockMediationAdapterTimeout.h"



float const  MEDIATION_CALLBACKS_TESTS_TIMEOUT = 5.0;   // seconds



@interface MediationCallbacksTests : ANBaseTestCase

@property (nonatomic, readwrite, assign) BOOL adLoadedMultiple;
@property (nonatomic, readwrite, assign) BOOL adFailedMultiple;

@end




@implementation MediationCallbacksTests
                    //FIX -- rename so tests exeitutd after MediationTests?

#pragma mark - Test lifecycle.

- (void)tearDown
{
    [super tearDown];
    _adLoadedMultiple = NO;
    _adFailedMultiple = NO;
}



#pragma mark - MediationCallback tests

- (void)test17
{
    [self stubWithBody:[ANTestResponses mediationWaterfallWithMockClassNames:@[ kMediationAdapterClassDoesNotExist, @"ANMockMediationAdapterTimeout" ]] ];
    [ANMockMediationAdapterTimeout setTimeout:MEDIATION_CALLBACKS_TESTS_TIMEOUT - 2];

    [self runBasicTest:YES waitTime:MEDIATION_CALLBACKS_TESTS_TIMEOUT];
    [self clearTest];
}

- (void)test18LoadedMultiple
{
    [self stubWithBody:[ANTestResponses mediationWaterfallWithMockClassNames:@[ @"ANMockMediationAdapterLoadedMultiple" ]]];

    [self runBasicTest:YES waitTime:MEDIATION_CALLBACKS_TESTS_TIMEOUT];
    [self clearTest];
}

- (void)test19Timeout
                    //TBDFIX -- is this a useful test?
{
    [self stubWithBody:[ANTestResponses mediationWaterfallWithMockClassNames:@[ @"ANMockMediationAdapterTimeout" ]]];
    [ANMockMediationAdapterTimeout setTimeout:kAppNexusMediationNetworkTimeoutInterval + 2];

    [self runBasicTest:NO waitTime:kAppNexusMediationNetworkTimeoutInterval + MEDIATION_CALLBACKS_TESTS_TIMEOUT];
    [self clearTest];
}

- (void)test20LoadThenFail
                    //TBDFIX -- is this a useful test?
{
    [self stubWithBody:[ANTestResponses mediationWaterfallWithMockClassNames:@[ @"ANMockMediationAdapterLoadThenFail" ]]];

    [self runBasicTest:YES waitTime:MEDIATION_CALLBACKS_TESTS_TIMEOUT];
    [self clearTest];
}

- (void)test21FailThenLoad
                    //TBDFIX -- is this a useful test?
{
    [self stubWithBody:[ANTestResponses mediationWaterfallWithMockClassNames:@[ @"ANMockMediationAdapterFailThenLoad" ]]];

    [self runBasicTest:NO waitTime:MEDIATION_CALLBACKS_TESTS_TIMEOUT];
    [self clearTest];
}

- (void)test22LoadAndHitOtherCallbacks
{
    [self stubWithBody:[ANTestResponses mediationWaterfallWithMockClassNames:@[ @"ANMockMediationAdapterLoadAndHitOtherCallbacks" ]]];

    [self runBasicTest:YES waitTime:MEDIATION_CALLBACKS_TESTS_TIMEOUT];
    [self checkCallbacks:YES];
    [self clearTest];
}

- (void)test23FailAndHitOtherCallbacks
                    //TBDFIX -- is this a useful test?
{
    [self stubWithBody:[ANTestResponses mediationWaterfallWithMockClassNames:@[ @"ANMockMediationAdapterFailAndHitOtherCallbacks" ]]];

    [self runBasicTest:NO waitTime:MEDIATION_CALLBACKS_TESTS_TIMEOUT];
    [self checkCallbacks:NO];
    [self clearTest];
}

- (void)test24FailedMultiple
                    //TBDFIX -- is this a useful test?
{
    [self stubWithBody:[ANTestResponses mediationWaterfallWithMockClassNames:@[ @"ANMockMediationAdapterFailedMultiple" ]]];

    [self runBasicTest:NO waitTime:MEDIATION_CALLBACKS_TESTS_TIMEOUT];
    [self clearTest];
}




#pragma mark - Test helper methods.

- (void)runBasicTest:(BOOL)didLoadValue
            waitTime:(int)waitTime
{
    [self loadBannerAd];
    [self waitForCompletion:waitTime];

    XCTAssertEqual(didLoadValue, self.adDidLoadCalled, @"callback adDidLoad should be %d", didLoadValue);
    XCTAssertEqual((BOOL)!didLoadValue, self.adFailedToLoadCalled, @"callback adFailedToLoad should be %d", (BOOL)!didLoadValue);

    XCTAssertFalse(self.adLoadedMultiple, @"adLoadedMultiple should never be true");
    XCTAssertFalse(self.adFailedMultiple, @"adFailedMultiple should never be true");
}

- (void)checkCallbacks:(BOOL)called
{
    XCTAssertEqual(self.adWasClickedCalled,             called, @"callback adWasClickCalled should be %d", called);
    XCTAssertEqual(self.adWillPresentCalled,            called, @"callback adWillPresentCalled should be %d", called);
    XCTAssertEqual(self.adDidPresentCalled,             called, @"callback adDidPresentCalled should be %d", called);
    XCTAssertEqual(self.adWillCloseCalled,              called, @"callback adWillCloseCalled should be %d", called);
    XCTAssertEqual(self.adDidCloseCalled,               called, @"callback adDidCloseCalled should be %d", called);
    XCTAssertEqual(self.adWillLeaveApplicationCalled,   called, @"callback adWillLeaveApplicationCalled should be %d", called);
}




#pragma mark - ANBannerAdViewDelegate

- (void)adDidReceiveAd:(id<ANAdProtocol>)ad {
    if (self.adDidLoadCalled) {
        self.adLoadedMultiple = YES;
    }
    [super adDidReceiveAd:ad];
}
- (void)ad:(id<ANAdProtocol>)ad requestFailedWithError:(NSError *)error {
    if (self.adFailedToLoadCalled) {
        self.adFailedMultiple = YES;
    }
    [super ad:ad requestFailedWithError:error];
}

@end
