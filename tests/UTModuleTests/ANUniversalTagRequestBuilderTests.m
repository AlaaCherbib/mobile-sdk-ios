//
//  UTModuleTests.m
//  UTModuleTests
//
//  Created by Punnaghai Puviarasu on 3/10/17.
//  Copyright © 2017 AppNexus. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "ANUniversalTagRequestBuilder.h"
#import "ANSDKSettings+PrivateMethods.h"
#import "ANUniversalAdFetcher.h"
#import "ANGlobal.h"
#import "ANReachability.h"
#import "TestANUniversalFetcher.h"

static NSString *const kTestUUID = @"0000-000-000-00";

@interface ANUniversalTagRequestBuilderTests : XCTestCase


@end

@implementation ANUniversalTagRequestBuilderTests

- (void)setUp {
    [super setUp];
    
}

- (void)tearDown {
    [super tearDown];
}

- (void)testBasicVideoRequest {
    
    NSString *urlString = [[[ANSDKSettings sharedInstance] baseUrlConfig] utAdRequestBaseUrl];
    
    TestANUniversalFetcher *adFetcher = [[TestANUniversalFetcher alloc] initWithPlacementId:@"9924001"];
    
    NSURLRequest *request = [ANUniversalTagRequestBuilder buildRequestWithAdFetcherDelegate:adFetcher.delegate baseUrlString:urlString];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Dummy expectation"];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        NSError *error;
        id jsonObject = [NSJSONSerialization JSONObjectWithData:request.HTTPBody
                                                        options:kNilOptions
                                                          error:&error];
        XCTAssertNil(error);
        XCTAssertNotNil(jsonObject);
        XCTAssertTrue([jsonObject isKindOfClass:[NSDictionary class]]);
        NSDictionary *jsonDict = (NSDictionary *)jsonObject;
        
        NSArray *tags = jsonDict[@"tags"];
        NSDictionary *user = jsonDict[@"user"];
        NSDictionary *device = jsonDict[@"device"];
        NSArray *keywords = jsonDict[@"keywords"];
        
        XCTAssertNotNil(tags);
        XCTAssertNotNil(user);
        XCTAssertNotNil(device);
        XCTAssertNil(keywords); // no keywords passed unless set in the targeting
        
        // Tags
        XCTAssertEqual(tags.count, 1);
        NSDictionary *tag = [tags firstObject];
        
        NSInteger placementId = [tag[@"id"] integerValue];
        XCTAssertEqual(placementId, 9924001);
        
        NSArray *sizes = tag[@"sizes"];
        XCTAssertNotNil(sizes);
        XCTAssertEqual(sizes.count, 1);
        NSDictionary *size = [sizes firstObject];
        XCTAssertEqual([size[@"width"] integerValue], 1);
        XCTAssertEqual([size[@"height"] integerValue], 1);
        
        NSArray *allowedMediaTypes = tag[@"allowed_media_types"];
        XCTAssertNotNil(allowedMediaTypes);
        
        NSNumber *disablePSA = tag[@"disable_psa"];
        XCTAssertNotNil(disablePSA);
        XCTAssertEqual([disablePSA integerValue], 1);
        
        // User
        NSNumber *gender = user[@"gender"];
        XCTAssertNotNil(gender);
        
        NSString *language = user[@"language"];
        XCTAssertEqualObjects(language, @"en");
        
        // Device
        NSString *userAgent = device[@"useragent"];
        XCTAssertNotNil(userAgent);
        
        NSString *deviceMake = device[@"make"];
        XCTAssertEqualObjects(deviceMake, @"Apple");
        
        NSString *deviceModel = device[@"model"];
        XCTAssertTrue(deviceModel.length > 0);
        
        NSNumber *connectionType = device[@"connectiontype"];
        XCTAssertNotNil(connectionType);
        
        ANReachability *reachability = [ANReachability reachabilityForInternetConnection];
        ANNetworkStatus status = [reachability currentReachabilityStatus];
        switch (status) {
            case ANNetworkStatusReachableViaWiFi:
                XCTAssertEqual([connectionType integerValue], 1);
                break;
            case ANNetworkStatusReachableViaWWAN:
                XCTAssertEqual([connectionType integerValue], 2);
                break;
            default:
                XCTAssertEqual([connectionType integerValue], 0);
                break;
        }
        
        NSNumber *lmt = device[@"limit_ad_tracking"];
        XCTAssertNotNil(lmt);
        XCTAssertEqual([lmt boolValue], ANAdvertisingTrackingEnabled() ? NO : YES);
        // get the objective c type of the NSNumber for limit_ad_tracking
        // "c" is the BOOL type that is returned from NSNumber objCType for BOOL value
        const char *boolType = "c";
        XCTAssertEqual(strcmp([lmt objCType], boolType), 0);
        
        // Device Id Start
        NSDictionary *deviceId = device[@"device_id"];
        XCTAssertNotNil(deviceId);
        NSString *idfa = deviceId[@"idfa"];
        XCTAssertEqualObjects(idfa, ANUDID());
        
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
}

- (void)testVideoRequestWithSingleKeyValue {
    
    NSString *urlString = [[[ANSDKSettings sharedInstance] baseUrlConfig] utAdRequestBaseUrl];
    
    TestANUniversalFetcher *adFetcher = [[TestANUniversalFetcher alloc] initWithPlacementId:@"9924001"];
    
    [adFetcher addCustomKeywordWithKey:@"state" value:@"NY"];
    
    NSURLRequest *request = [ANUniversalTagRequestBuilder buildRequestWithAdFetcherDelegate:adFetcher.delegate baseUrlString:urlString];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Dummy expectation"];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        NSError *error;
        id jsonObject = [NSJSONSerialization JSONObjectWithData:request.HTTPBody
                                                        options:kNilOptions
                                                          error:&error];
        XCTAssertNil(error);
        XCTAssertNotNil(jsonObject);
        XCTAssertTrue([jsonObject isKindOfClass:[NSDictionary class]]);
        NSDictionary *jsonDict = (NSDictionary *)jsonObject;
        
        NSArray *tags = jsonDict[@"tags"];
        NSDictionary *user = jsonDict[@"user"];
        NSDictionary *device = jsonDict[@"device"];
        NSArray *keywords = jsonDict[@"keywords"];
        
        XCTAssertNotNil(tags);
        XCTAssertNotNil(user);
        XCTAssertNotNil(device);
        XCTAssertNotNil(keywords); // no keywords passed unless set in the targeting
        
        for (NSDictionary *keyword in keywords) {
            XCTAssertNotNil(keyword[@"key"]);
            NSString *key = keyword[@"key"];
            NSArray *value = keyword[@"value"];
            if ([key isEqualToString:@"state"]) {
                XCTAssertEqualObjects(value, @[@"NY"]);
            }
        }
        
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
}

- (void)testVideoRequestWithMultipleKeyValues {
    
    NSString *urlString = [[[ANSDKSettings sharedInstance] baseUrlConfig] utAdRequestBaseUrl];
    
    TestANUniversalFetcher *adFetcher = [[TestANUniversalFetcher alloc] initWithPlacementId:@"9924001"];
    
    [adFetcher addCustomKeywordWithKey:@"state" value:@"NY"];
    [adFetcher addCustomKeywordWithKey:@"state" value:@"NJ"];
    [adFetcher addCustomKeywordWithKey:@"county" value:@"essex"];
    [adFetcher addCustomKeywordWithKey:@"county" value:@"morris"];
    
    
    NSURLRequest *request = [ANUniversalTagRequestBuilder buildRequestWithAdFetcherDelegate:adFetcher.delegate baseUrlString:urlString];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Dummy expectation"];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        NSError *error;
        id jsonObject = [NSJSONSerialization JSONObjectWithData:request.HTTPBody
                                                        options:kNilOptions
                                                          error:&error];
        XCTAssertNil(error);
        XCTAssertNotNil(jsonObject);
        XCTAssertTrue([jsonObject isKindOfClass:[NSDictionary class]]);
        NSDictionary *jsonDict = (NSDictionary *)jsonObject;
        
        NSArray *tags = jsonDict[@"tags"];
        NSDictionary *user = jsonDict[@"user"];
        NSDictionary *device = jsonDict[@"device"];
        NSArray *keywords = jsonDict[@"keywords"];
        
        XCTAssertNotNil(tags);
        XCTAssertNotNil(user);
        XCTAssertNotNil(device);
        XCTAssertNotNil(keywords); // no keywords passed unless set in the targeting
        
        for (NSDictionary *keyword in keywords) {
            XCTAssertNotNil(keyword[@"key"]);
            NSString *key = keyword[@"key"];
            NSArray *value = keyword[@"value"];
            if ([key isEqualToString:@"state"]){
                NSArray *valueArray = @[@"NJ",@"NY"];
                XCTAssertEqualObjects(value, valueArray);
            }
            if ([key isEqualToString:@"county"]) {
                NSArray *valueArray = @[@"essex",@"morris"];
                XCTAssertEqualObjects(value, valueArray);
            }
        }
        
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
}

- (void)testRequestContentType {
    
    NSString *urlString = [[[ANSDKSettings sharedInstance] baseUrlConfig] utAdRequestBaseUrl];
    
    TestANUniversalFetcher *adFetcher = [[TestANUniversalFetcher alloc] initWithPlacementId:@"1281482"];
    
    NSURLRequest *request = [ANUniversalTagRequestBuilder buildRequestWithAdFetcherDelegate:adFetcher.delegate baseUrlString:urlString];
    
    NSString *contentType =  [request valueForHTTPHeaderField:@"content-type"];
    XCTAssertNotNil(contentType);
    XCTAssertEqualObjects(@"application/json", contentType);
    
    
}

@end
