/*   Copyright 2015 APPNEXUS INC
 
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

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "ANBannerAdView.h"
#import "ANInterstitialAd.h"
#import "ANGlobal.h"
#import "ANURLConnectionStub.h"
#import "ANHTTPStubbingManager.h"
#import "XCTestCase+ANCategory.h"
#import "ANInterstitialAdFetcher.h"
#import "ANGlobal.h"

@interface ANPublicAPITestCase : XCTestCase

@property (nonatomic, readwrite, strong) XCTestExpectation *requestExpectation;
@property (nonatomic, readwrite, strong) ANBannerAdView *banner;
@property (nonatomic, readwrite, strong) ANInterstitialAd *interstitial;
@property (nonatomic) NSURLRequest *request;

@end

@implementation ANPublicAPITestCase

- (void)setUp {
    [super setUp];
    [[ANHTTPStubbingManager sharedStubbingManager] enable];
    [ANHTTPStubbingManager sharedStubbingManager].ignoreUnstubbedRequests = YES;
    [self setupRequestTracker];
}

- (void)tearDown {
    [super tearDown];
    [[ANHTTPStubbingManager sharedStubbingManager] removeAllStubs];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kANHTTPStubURLProtocolRequestDidLoadNotification
                                                  object:nil];
}

- (void)setupRequestTracker {
    [ANHTTPStubbingManager sharedStubbingManager].broadcastRequests = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(requestLoaded:)
                                                 name:kANHTTPStubURLProtocolRequestDidLoadNotification
                                               object:nil];
}

- (void)requestLoaded:(NSNotification *)notification {
    if (self.requestExpectation) {
        self.request = notification.userInfo[kANHTTPStubURLProtocolRequest];
        [self.requestExpectation fulfill];
        self.requestExpectation = nil;
    }
}

- (void)stubRequestWithResponse:(NSString *)responseName {
    NSBundle *currentBundle = [NSBundle bundleForClass:[self class]];
    NSString *baseResponse = [NSString stringWithContentsOfFile:[currentBundle pathForResource:responseName
                                                                                        ofType:@"json"]
                                                       encoding:NSUTF8StringEncoding
                                                          error:nil];
    ANURLConnectionStub *requestStub = [[ANURLConnectionStub alloc] init];
    requestStub.requestURLRegexPatternString = @"http://mediation.adnxs.com/mob\\?.*";
    requestStub.responseCode = 200;
    requestStub.responseBody = baseResponse;
    [[ANHTTPStubbingManager sharedStubbingManager] addStub:requestStub];
}

- (void)stubUTv2RequestWithResponse:(NSString *)responseName {
    NSBundle *currentBundle = [NSBundle bundleForClass:[self class]];
    NSString *baseResponse = [NSString stringWithContentsOfFile:[currentBundle pathForResource:responseName
                                                                                        ofType:@"json"]
                                                       encoding:NSUTF8StringEncoding
                                                          error:nil];
    ANURLConnectionStub *requestStub = [[ANURLConnectionStub alloc] init];
    requestStub.requestURLRegexPatternString = kANInterstitialAdFetcherDefaultRequestUrlString;
    requestStub.responseCode = 200;
    requestStub.responseBody = baseResponse;
    [[ANHTTPStubbingManager sharedStubbingManager] addStub:requestStub];
}

#pragma mark - Banner

- (void)testSetPlacementOnlyOnBanner {
    [self stubRequestWithResponse:@"SuccessfulMRAIDResponse"];
    self.requestExpectation = [self expectationWithDescription:@"request"];
    self.banner = [[ANBannerAdView alloc]
                   initWithFrame:CGRectMake(0, 0, 320, 50)
                   placementId:@"1"
                   adSize:CGSizeMake(320, 50)];
    [self.banner loadAd];
    [self waitForExpectationsWithTimeout:2 * kAppNexusRequestTimeoutInterval
                                 handler:^(NSError * _Nullable error) {
                                     
                                 }];
    self.requestExpectation = nil;
    NSString *requestPath = [[self.request URL] absoluteString];
    XCTAssertEqual(@"1", [self.banner placementId]);
    XCTAssertTrue([requestPath containsString:@"?id=1"]);
}

- (void)testSetInventoryCodeAndMemberIDOnBanner {
    [self stubRequestWithResponse:@"SuccessfulMRAIDResponse"];
        self.requestExpectation = [self expectationWithDescription:@"request"];
    self.banner = [[ANBannerAdView alloc]
                   initWithFrame:CGRectMake(0, 0, 320, 50)
                   memberId:1
                   inventoryCode:@"test"
                   adSize:CGSizeMake(320, 50)];
    [self.banner loadAd];
    [self waitForExpectationsWithTimeout:2 * kAppNexusRequestTimeoutInterval
                                 handler:^(NSError * _Nullable error) {
                                     
                                 }];
    self.requestExpectation = nil;
    NSString *requestPath = [[self.request URL] absoluteString];
    XCTAssertEqual(@"test", [self.banner inventoryCode]);
    XCTAssertEqual(1, [self.banner memberId]);
    XCTAssertTrue([requestPath containsString:@"?member=1&inv_code=test"]);
}

- (void)testSetBothInventoryCodeAndPlacementIdOnBanner {
    [self stubRequestWithResponse:@"SuccessfulMRAIDResponse"];
    self.requestExpectation = [self expectationWithDescription:@"request"];
    self.banner = [[ANBannerAdView alloc]
                   initWithFrame:CGRectMake(0, 0, 320, 50)
                   placementId:@"1"
                   adSize:CGSizeMake(320, 50)];
    [self.banner setInventoryCode:@"test" memberId:2];
    [self.banner loadAd];
    [self waitForExpectationsWithTimeout:2 * kAppNexusRequestTimeoutInterval
                                 handler:^(NSError * _Nullable error) {
                                     
                                 }];
    self.requestExpectation = nil;
    NSString *requestPath = [[self.request URL] absoluteString];
    XCTAssertEqual(@"1", [self.banner placementId]);
    XCTAssertEqual(@"test", [self.banner inventoryCode]);
    XCTAssertEqual(2, [self.banner memberId]);
    XCTAssertTrue([requestPath containsString:@"?member=2&inv_code=test"]);
}

#pragma mark - Interstitial

- (void)testSetPlacementOnlyOnInterstitial {
    [self stubUTv2RequestWithResponse:@"UTv2RTBHTML"];
    self.requestExpectation = [self expectationWithDescription:@"request"];
    self.interstitial = [[ANInterstitialAd alloc] initWithPlacementId:@"1"];
    [self.interstitial loadAd];
    [self waitForExpectationsWithTimeout:2 * kAppNexusRequestTimeoutInterval
                                 handler:^(NSError * _Nullable error) {
                                     
                                 }];
    self.requestExpectation = nil;
    NSDictionary *postData = [NSJSONSerialization JSONObjectWithData:self.request.HTTPBody
                                                             options:kNilOptions
                                                               error:nil];
    XCTAssertNotNil(postData);
    XCTAssertNil(postData[@"member_id"]);
    NSArray *tags = postData[@"tags"];
    XCTAssertNotNil(tags);
    NSDictionary *tag = [tags firstObject];
    XCTAssertNotNil(tag);
    XCTAssertEqualObjects(tag[@"id"], @(1));
    XCTAssertNil(tag[@"code"]);
}

- (void)testSetInventoryCodeAndMemberIDOnInterstitial {
    [self stubUTv2RequestWithResponse:@"UTv2RTBHTML"];
    self.requestExpectation = [self expectationWithDescription:@"request"];
    self.interstitial = [[ANInterstitialAd alloc] initWithMemberId:2
                                                     inventoryCode:@"test"];
    [self.interstitial loadAd];
    [self waitForExpectationsWithTimeout:2 * kAppNexusRequestTimeoutInterval
                                 handler:^(NSError * _Nullable error) {
                                     
                                 }];
    self.requestExpectation = nil;
    NSDictionary *postData = [NSJSONSerialization JSONObjectWithData:self.request.HTTPBody
                                                             options:kNilOptions
                                                               error:nil];
    XCTAssertNotNil(postData);
    XCTAssertEqualObjects(postData[@"member_id"], @(2));
    NSArray *tags = postData[@"tags"];
    XCTAssertNotNil(tags);
    NSDictionary *tag = [tags firstObject];
    XCTAssertNotNil(tag);
    XCTAssertEqualObjects(tag[@"code"], @"test");
    XCTAssertNil(tag[@"id"]);
}

- (void)testSetBothInventoryCodeAndPlacementIdOnInterstitial {
    [self stubUTv2RequestWithResponse:@"UTv2RTBHTML"];
    self.requestExpectation = [self expectationWithDescription:@"request"];
    self.interstitial = [[ANInterstitialAd alloc] initWithPlacementId:@"1"];
    [self.interstitial setInventoryCode:@"test" memberId:2];
    [self.interstitial loadAd];
    [self waitForExpectationsWithTimeout:2 * kAppNexusRequestTimeoutInterval
                                 handler:^(NSError * _Nullable error) {
                                     
                                 }];
    self.requestExpectation = nil;
    NSDictionary *postData = [NSJSONSerialization JSONObjectWithData:self.request.HTTPBody
                                                             options:kNilOptions
                                                               error:nil];
    XCTAssertNotNil(postData);
    XCTAssertEqualObjects(postData[@"member_id"], @(2));
    NSArray *tags = postData[@"tags"];
    XCTAssertNotNil(tags);
    NSDictionary *tag = [tags firstObject];
    XCTAssertNotNil(tag);
    XCTAssertEqualObjects(tag[@"code"], @"test");
    XCTAssertNil(tag[@"id"]);
}

- (void)testDefaultAllowedSizesOnInterstitial {
    [self stubUTv2RequestWithResponse:@"UTv2RTBHTML"];
    self.requestExpectation = [self expectationWithDescription:@"request"];
    self.interstitial = [[ANInterstitialAd alloc] initWithPlacementId:@"1"];
    [self.interstitial loadAd];
    [self waitForExpectationsWithTimeout:2 * kAppNexusRequestTimeoutInterval
                                 handler:^(NSError * _Nullable error) {
                                     
                                 }];
    self.requestExpectation = nil;
    NSDictionary *postData = [NSJSONSerialization JSONObjectWithData:self.request.HTTPBody
                                                             options:kNilOptions
                                                               error:nil];
    XCTAssertNotNil(postData);
    NSArray *tags = postData[@"tags"];
    XCTAssertTrue(tags.count > 0);
    NSDictionary *tag = [tags firstObject];
    XCTAssertNotNil(tag);
    NSArray *sizes = tag[@"sizes"];
    XCTAssertNotNil(sizes);
    __block NSMutableArray *passedSizes = [[NSMutableArray alloc] init];
    [sizes enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL *stop) {
        NSNumber *width = obj[@"width"];
        NSNumber *height = obj[@"height"];
        XCTAssertNotNil(width);
        XCTAssertNotNil(height);
        [passedSizes addObject:[NSString stringWithFormat:@"%dx%d", (int)[width integerValue], (int)[height integerValue]]];
    }];
    CGFloat screenWidth = [UIScreen mainScreen].coordinateSpace.bounds.size.width;
    CGFloat screenHeight = [UIScreen mainScreen].coordinateSpace.bounds.size.height;
    if (screenWidth >= 300 && screenHeight >= 250) {
        XCTAssertTrue([passedSizes containsObject:@"300x250"]);
    } else {
        XCTAssertFalse([passedSizes containsObject:@"300x250"]);
    }
    if (screenWidth >= 320 && screenHeight >= 480) {
        XCTAssertTrue([passedSizes containsObject:@"320x480"]);
    } else {
        XCTAssertFalse([passedSizes containsObject:@"320x480"]);
    }
    if (screenWidth >= 900 && screenHeight >= 500) {
        XCTAssertTrue([passedSizes containsObject:@"900x500"]);
    } else {
        XCTAssertFalse([passedSizes containsObject:@"900x500"]);
    }
    if (screenWidth >= 1024 && screenHeight >= 1024) {
        XCTAssertTrue([passedSizes containsObject:@"1024x1024"]);
    } else {
        XCTAssertFalse([passedSizes containsObject:@"1024x1024"]);
    }
}

- (void)testSetAgeOnInterstitial {
    self.requestExpectation = [self expectationWithDescription:@"request"];
    [self stubUTv2RequestWithResponse:@"UTv2RTBHTML"];
    self.interstitial = [[ANInterstitialAd alloc] initWithPlacementId:@"1"];
    [self.interstitial setAge:@"18"];
    [self.interstitial loadAd];
    [self waitForExpectationsWithTimeout:2 * kAppNexusRequestTimeoutInterval
                                 handler:^(NSError * _Nullable error) {
                                     
                                 }];
    self.requestExpectation = nil;
    NSDictionary *postData = [NSJSONSerialization JSONObjectWithData:self.request.HTTPBody
                                                             options:kNilOptions
                                                               error:nil];
    XCTAssertNotNil(postData);
    NSArray *user = postData[@"user"];
    XCTAssertNotNil(user);
    NSNumber *age = (NSNumber *)[user valueForKey:@"age"];
    XCTAssertNotNil(age);
    XCTAssertEqualObjects(age, @(18));
}

- (void)testSetOpensInNativeBrowserOnBanner {
    [self stubRequestWithResponse:@"SuccessfulMRAIDResponse"];
    self.requestExpectation = [self expectationWithDescription:@"request"];
    
    NSNumber *value = [NSNumber numberWithInt:UIInterfaceOrientationLandscapeLeft];
    [[UIDevice currentDevice] setValue:value forKey:@"orientation"];
    
    self.banner = [[ANBannerAdView alloc]
                   initWithFrame:CGRectMake(0, 0, 320, 50)
                   placementId:@"1"
                   adSize:CGSizeMake(200, 150)];
    [self.banner setOpensInNativeBrowser:YES];
    
    [self.banner loadAd];
    [self waitForExpectationsWithTimeout:2 * kAppNexusRequestTimeoutInterval
                                 handler:^(NSError * _Nullable error) {
                                     
                                 }];
    self.requestExpectation = nil;
    NSString *requestPath = [[self.request URL] absoluteString];
    XCTAssertTrue(self.banner.opensInNativeBrowser);
    XCTAssertTrue([requestPath containsString:@"&native_browser=1"]);
    
    self.requestExpectation = [self expectationWithDescription:@"request"];
    [self.banner setOpensInNativeBrowser:NO];
    [self.banner loadAd];
    [self waitForExpectationsWithTimeout:2 * kAppNexusRequestTimeoutInterval
                                 handler:^(NSError * _Nullable error) {
                                     
                                 }];
    self.requestExpectation = nil;
    requestPath = [[self.request URL] absoluteString];
    XCTAssertFalse(self.banner.opensInNativeBrowser);
    XCTAssertTrue([requestPath containsString:@"&native_browser=0"]);
}

- (void)testSetShouldServePublicServiceAnnoucementsOnInterstitial {
    self.requestExpectation = [self expectationWithDescription:@"request"];
    [self stubUTv2RequestWithResponse:@"SuccessfulMRAIDResponse"];
    self.interstitial = [[ANInterstitialAd alloc] initWithPlacementId:@"1"];
    [self.interstitial setShouldServePublicServiceAnnouncements:YES];
    [self.interstitial loadAd];
    [self waitForExpectationsWithTimeout:2 * kAppNexusRequestTimeoutInterval
                                 handler:^(NSError * _Nullable error) {
                                     
                                 }];
    self.requestExpectation = nil;
    NSDictionary *postData = [NSJSONSerialization JSONObjectWithData:self.request.HTTPBody
                                                             options:kNilOptions
                                                               error:nil];
    XCTAssertNotNil(postData);
    NSArray *tags = postData[@"tags"];
    XCTAssertNotNil(tags);
    NSNumber *disablePSA = [[tags firstObject] valueForKey:@"disable_psa"];
    XCTAssertNotNil(disablePSA);
    XCTAssertFalse([disablePSA boolValue]);
    
    self.requestExpectation = [self expectationWithDescription:@"request"];
    [self.interstitial setShouldServePublicServiceAnnouncements:NO];
    [self.interstitial loadAd];
    [self waitForExpectationsWithTimeout:2 * kAppNexusRequestTimeoutInterval
                                 handler:^(NSError * _Nullable error) {
                                     
                                 }];
    self.requestExpectation = nil;
    postData = [NSJSONSerialization JSONObjectWithData:self.request.HTTPBody
                                               options:kNilOptions
                                                 error:nil];
    XCTAssertNotNil(postData);
    tags = postData[@"tags"];
    XCTAssertNotNil(tags);
    disablePSA = [[tags firstObject] valueForKey:@"disable_psa"];
    XCTAssertNotNil(disablePSA);
    XCTAssertTrue([disablePSA boolValue]);
}

- (void)testSetReserveOnBanner {
    [self stubRequestWithResponse:@"SuccessfulMRAIDResponse"];
    self.requestExpectation = [self expectationWithDescription:@"request"];
    
    NSNumber *value = [NSNumber numberWithInt:UIInterfaceOrientationLandscapeLeft];
    [[UIDevice currentDevice] setValue:value forKey:@"orientation"];
    
    self.banner = [[ANBannerAdView alloc]
                   initWithFrame:CGRectMake(0, 0, 320, 50)
                   placementId:@"1"
                   adSize:CGSizeMake(200, 150)];
    [self.banner setReserve:1.0];
    
    [self.banner loadAd];
    [self waitForExpectationsWithTimeout:2 * kAppNexusRequestTimeoutInterval
                                 handler:^(NSError * _Nullable error) {
                                     
                                 }];
    self.requestExpectation = nil;
    NSString *requestPath = [[self.request URL] absoluteString];
    XCTAssertNotNil(requestPath);
    NSURLComponents *components = [[NSURLComponents alloc] initWithString:requestPath];
    XCTAssertNotNil(components);
    NSArray *queryItems = components.queryItems;
    XCTAssertNotNil(queryItems);
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name=%@", @"reserve"];
    NSURLQueryItem *queryItem = [[queryItems
                                  filteredArrayUsingPredicate:predicate]
                                 firstObject];
    XCTAssertNotNil(queryItem);
    XCTAssertTrue([queryItem.value hasPrefix:@"1.0"]);
}

- (void)testSetGenderOnInterstitial {
    self.requestExpectation = [self expectationWithDescription:@"request"];
    [self stubUTv2RequestWithResponse:@"UTv2RTBHTML"];
    self.interstitial = [[ANInterstitialAd alloc] initWithPlacementId:@"1"];
    [self.interstitial setGender:ANGenderMale];
    [self.interstitial loadAd];
    [self waitForExpectationsWithTimeout:2 * kAppNexusRequestTimeoutInterval
                                 handler:^(NSError * _Nullable error) {
                                     
                                 }];
    self.requestExpectation = nil;
    NSDictionary *postData = [NSJSONSerialization JSONObjectWithData:self.request.HTTPBody
                                                             options:kNilOptions
                                                               error:nil];
    XCTAssertNotNil(postData);
    NSArray *user = postData[@"user"];
    XCTAssertNotNil(user);
    NSNumber *gender = [user valueForKey:@"gender"];
    XCTAssertEqualObjects(gender, @(1));
    
    self.requestExpectation = [self expectationWithDescription:@"request"];
    [self.interstitial setGender:ANGenderFemale];
    [self.interstitial loadAd];
    [self waitForExpectationsWithTimeout:2 * kAppNexusRequestTimeoutInterval
                                 handler:^(NSError * _Nullable error) {
                                     
                                 }];
    self.requestExpectation = nil;
    postData = [NSJSONSerialization JSONObjectWithData:self.request.HTTPBody
                                          options:kNilOptions
                                            error:nil];
    XCTAssertNotNil(postData);
    user = postData[@"user"];
    XCTAssertNotNil(user);
    gender = [user valueForKey:@"gender"];
    XCTAssertEqualObjects(gender, @(2));
}

- (void)testSetCustomKeywordsOnInterstitial {
    self.requestExpectation = [self expectationWithDescription:@"request"];
    [self stubUTv2RequestWithResponse:@"UTv2RTBHTML"];
    self.interstitial = [[ANInterstitialAd alloc] initWithPlacementId:@"1"];
    [self.interstitial setCustomKeywords:[NSMutableDictionary dictionaryWithObject:@"object" forKey:@"key"]];
    [self.interstitial loadAd];
    [self waitForExpectationsWithTimeout:2 * kAppNexusRequestTimeoutInterval
                                 handler:^(NSError * _Nullable error) {
                                     
                                 }];
    self.requestExpectation = nil;
    NSDictionary *postData = [NSJSONSerialization JSONObjectWithData:self.request.HTTPBody
                                                             options:kNilOptions
                                                               error:nil];
    XCTAssertNotNil(postData);
    NSArray *keywords = postData[@"keywords"];
    XCTAssertNotNil(keywords);
    NSString *key = [[keywords firstObject] valueForKey:@"key"];
    XCTAssertEqualObjects(key, @"key");
    NSString *value = [[keywords firstObject] valueForKey:@"value"];
    XCTAssertEqualObjects(value, @"object");
}

- (void)testSetSizeAndOrientationParameterOnBanner {
    [self stubRequestWithResponse:@"SuccessfulMRAIDResponse"];
    self.requestExpectation = [self expectationWithDescription:@"request"];
    
    NSNumber *value = [NSNumber numberWithInt:UIInterfaceOrientationLandscapeLeft];
    [[UIDevice currentDevice] setValue:value forKey:@"orientation"];

    self.banner = [[ANBannerAdView alloc]
                   initWithFrame:CGRectMake(0, 0, 320, 50)
                   placementId:@"1"
                   adSize:CGSizeMake(200, 150)];
    

    [self.banner loadAd];
    [self waitForExpectationsWithTimeout:2 * kAppNexusRequestTimeoutInterval
                                 handler:^(NSError * _Nullable error) {
                                     
                                 }];
    self.requestExpectation = nil;
    NSString *requestPath = [[self.request URL] absoluteString];
    XCTAssertNotNil(requestPath);
    XCTAssertTrue([requestPath containsString:@"orientation=h"]);
    XCTAssertTrue(([requestPath containsString:@"size=200x150"]));
}

- (void)testAllowedSizesOnInterstitial {
    // Make sure that ANInterstitialAd.allowedAdSizes is passed correctly in the request body
}

- (void)testLocationOnInterstitial {
    // Make sure that ANInterstitialAd.location is passed correctly in the request body
}


@end
