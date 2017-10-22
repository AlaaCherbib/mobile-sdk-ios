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

//static NSString *const  kANLoadedMultiple                       = @"ANMockMediationAdapterLoadedMultiple";
//static NSString *const  kANMockMediationAdapterTimeout          = @"ANMockMediationAdapterTimeout";
static NSString *const  kANLoadThenFail                         = @"ANLoadThenFail";
static NSString *const  kANFailThenLoad                         = @"ANFailThenLoad";
static NSString *const  kANLoadAndHitOtherCallbacks             = @"ANLoadAndHitOtherCallbacks";
static NSString *const  kANFailAndHitOtherCallbacks             = @"ANFailAndHitOtherCallbacks";
static NSString *const  kANFailedMultiple                       = @"ANFailedMultiple";
static NSString *const  kMediationAdapterClassDoesNotExist      = @"MediationAdapterClassDoesNotExist";
            //fix -fix --FIX -- string duplicates variable?




@interface MediationCallbacksTests : ANBaseTestCase

@property (nonatomic, readwrite, assign) BOOL adLoadedMultiple;
@property (nonatomic, readwrite, assign) BOOL adFailedMultiple;

@end




@implementation MediationCallbacksTests

- (void)tearDown
{
    [super tearDown];
    _adLoadedMultiple = NO;
    _adFailedMultiple = NO;
}

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
{
    [ANMockMediationAdapterTimeout setTimeout:kAppNexusMediationNetworkTimeoutInterval + 2];
    [self stubWithBody:[ANTestResponses createMediatedBanner:@"ANMockMediationAdapterTimeout"]];
    [self stubResultCBResponses:@""];
    [self runBasicTest:NO waitTime:kAppNexusMediationNetworkTimeoutInterval + MEDIATION_CALLBACKS_TESTS_TIMEOUT];
    [self clearTest];
}

- (void)test20LoadThenFail
{
    [self stubWithBody:[ANTestResponses createMediatedBanner:kANLoadThenFail]];
    [self stubResultCBResponses:@""];
    [self runBasicTest:YES waitTime:MEDIATION_CALLBACKS_TESTS_TIMEOUT];
    [self clearTest];
}

- (void)test21FailThenLoad
{
    [self stubWithBody:[ANTestResponses createMediatedBanner:kANFailThenLoad]];
    [self stubResultCBResponses:@""];
    [self runBasicTest:NO waitTime:MEDIATION_CALLBACKS_TESTS_TIMEOUT];
    [self clearTest];
}

- (void)test22LoadAndHitOtherCallbacks
{
    [self stubWithBody:[ANTestResponses createMediatedBanner:kANLoadAndHitOtherCallbacks]];
    [self stubResultCBResponses:@""];
    [self runBasicTest:YES waitTime:MEDIATION_CALLBACKS_TESTS_TIMEOUT];
    [self checkCallbacks:YES];
    [self clearTest];
}

// Will be fixed by HiccupFixesSep14 branch
/*- (void)test23FailAndHitOtherCallbacks
{
    [self stubWithBody:[ANTestResponses createMediatedBanner:kANFailAndHitOtherCallbacks]];
    [self stubResultCBResponses:@""];
    [self runBasicTest:NO waitTime:MEDIATION_CALLBACKS_TESTS_TIMEOUT];
    [self checkCallbacks:NO];
    [self clearTest];
}*/

- (void)test24FailedMultiple
{
    [self stubWithBody:[ANTestResponses createMediatedBanner:kANFailedMultiple]];
    [self stubResultCBResponses:@""];
    [self runBasicTest:NO waitTime:MEDIATION_CALLBACKS_TESTS_TIMEOUT];
    [self clearTest];
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
