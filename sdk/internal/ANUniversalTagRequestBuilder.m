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

#import "ANUniversalTagRequestBuilder.h"
#import "ANGlobal.h"
#import "ANLogging.h"
#import "ANReachability.h"
#import "ANUniversalAdFetcher.h"

#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>




@interface ANUniversalTagRequestBuilder()

@property (nonatomic, readwrite, weak) id<ANAdFetcherDelegate> adFetcherDelegate;
@property (nonatomic) NSString *baseURLString;

@end




@implementation ANUniversalTagRequestBuilder

+ (NSURLRequest *)buildRequestWithAdFetcherDelegate:(id<ANAdFetcherDelegate>)adFetcherDelegate
                                      baseUrlString:(NSString *)baseUrlString
{
    ANUniversalTagRequestBuilder *requestBuilder = [[ANUniversalTagRequestBuilder alloc] initWithAdFetcherDelegate:adFetcherDelegate
                                                                                                     baseUrlString:baseUrlString];
    return [requestBuilder request];
}


- (instancetype)initWithAdFetcherDelegate:(id<ANAdFetcherDelegate>)adFetcherDelegate
                            baseUrlString:(NSString *)baseUrlString {
    if (self = [super init]) {
        _adFetcherDelegate = adFetcherDelegate;
        _baseURLString = baseUrlString;
    }
    return self;
}

- (NSURLRequest *)request
{
ANLogMark();
    NSURL                *URL             = [NSURL URLWithString:self.baseURLString];
    NSMutableURLRequest  *mutableRequest  = [[NSMutableURLRequest alloc] initWithURL: URL
                                                                         cachePolicy: NSURLRequestReloadIgnoringLocalCacheData
                                                                     timeoutInterval: kAppNexusRequestTimeoutInterval];

    [mutableRequest setValue:ANUserAgent() forHTTPHeaderField:@"User-Agent"];
    [mutableRequest setHTTPMethod:@"POST"];

    NSError       *error       = nil;
    NSDictionary  *jsonObject  = [self requestBody];
    NSData        *postData    = [NSJSONSerialization dataWithJSONObject: jsonObject
                                                                 options: kNilOptions
                                                                   error: &error];

    if (!error) {
        NSString *jsonString = [[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding];
        ANLogDebug(@"Post JSON: %@", jsonString);
        ANLogDebug(@"[self requestBody] = %@", jsonObject);   //DEBUG

        [mutableRequest setHTTPBody:postData];
        return [mutableRequest copy];

    } else {
        ANLogError(@"Error formulating Universal Tag request: %@", error);
        return nil;
    }
}

- (NSDictionary *)requestBody {
    NSMutableDictionary *requestDict = [[NSMutableDictionary alloc] init];
    
    NSDictionary *tags = [self tag:requestDict];
    if (tags) {
        requestDict[@"tags"] = @[tags];
    }
    NSDictionary *user = [self user];
    if (user) {
        requestDict[@"user"] = user;
    }
    NSDictionary *device = [self device];
    if (device) {
        requestDict[@"device"] = device;
    }
    NSDictionary *app = [self app];
    if (app) {
        requestDict[@"app"] = app;
    }
    NSArray *keywords = [self keywords];
    if (keywords) {
        requestDict[@"keywords"] = keywords;
    }

    //
    requestDict[@"sdkver"]       = AN_SDK_VERSION;
    requestDict[@"supply_type"]  = @"mobile_app";


    //
    return [requestDict copy];
}

// ASSUME  customKeywordsMap is a superset of customKeywords.
//
- (NSArray *)keywords
{
    NSDictionary  *customKeywordsMap  = [self.adFetcherDelegate customKeywordsMap];

    if ([customKeywordsMap count] < 1) {
        return nil;
    }

    //
    NSMutableArray  *kvSegmentsArray  = [[NSMutableArray alloc] init];

    for (NSString *key in customKeywordsMap)
    {
        NSArray  *valueArray  = [customKeywordsMap objectForKey:key];
        if ([valueArray count] < 1)  {
            ANLogWarn(@"DISCARDING key with empty value array.  (%@)", key);
            continue;
        }

        NSSet  *setOfUniqueArrayValues  = [NSSet setWithArray:valueArray];
        
       
        
        [kvSegmentsArray addObject:@{ @"key":key, @"value":[setOfUniqueArrayValues allObjects] }];
    }

    return [kvSegmentsArray copy];
}


- (NSDictionary *)tag:(NSMutableDictionary *) requestDict
{
ANLogMark();
    NSMutableDictionary *tagDict = [[NSMutableDictionary alloc] init];

    NSInteger placementId = [[self.adFetcherDelegate placementId] integerValue];

    //
    NSString *invCode = [self.adFetcherDelegate inventoryCode];
    NSInteger memberId = [self.adFetcherDelegate memberId];
    if(invCode && memberId>0){
        tagDict[@"code"] = invCode;
        requestDict[@"member_id"] = @(memberId);
    }else {
        tagDict[@"id"] = @(placementId);
    }

    
    //
    ANEntryPointType  entryPointType     = self.adFetcherDelegate.entryPointType;
    CGSize            adSize             = self.adFetcherDelegate.adSize;
    NSMutableSet<NSValue *>  *allowedAdSizes  = [self.adFetcherDelegate.allowedAdSizes mutableCopy];
    BOOL              allowSmallerSizes  = NO;

    if (nil == allowedAdSizes)  {
        allowedAdSizes = [[NSMutableSet alloc] init];
    }

    switch (entryPointType)
    {
        case ANEntryPointTypeBannerAdView:
            if (CGSizeEqualToSize(adSize, APPNEXUS_SIZE_ZERO))
            {
                adSize = [self.adFetcherDelegate frameSize];
                allowSmallerSizes = YES;
            } else {
                allowSmallerSizes = NO;
            }

            [allowedAdSizes addObject:[NSValue valueWithCGSize:adSize]];
            break;


        case ANEntryPointTypeInterstitialAd:
            adSize = [self.adFetcherDelegate frameSize];
            break;


        default:
            ANLogError(@"UNRECOGNIZED ANEntryPointType.  (%lu)", (unsigned long)entryPointType);
                                //FIX UT -- handle all known cases...
    }


    for (id element in self.adFetcherDelegate.adAllowedMediaTypes)
    {
        if (1 != [element integerValue])  {
            [allowedAdSizes addObject:[NSValue valueWithCGSize:CGSizeMake(1, 1)]];
            break;
        }
    }


    tagDict[@"primary_size"] = @{
                                    @"width"  : @(adSize.width),
                                    @"height" : @(adSize.height)
                                };
                    //FIX UTTEST

    NSMutableArray  *sizesObjectArray  = [[NSMutableArray alloc] init];

    for (id sizeValue in allowedAdSizes) {
        if ([sizeValue isKindOfClass:[NSValue class]]) {
            CGSize  size  = [sizeValue CGSizeValue];
            [sizesObjectArray addObject:@{
                                             @"width"  : @(size.width),
                                             @"height" : @(size.height)
                                         } ];
        }
    }

    tagDict[@"sizes"] = sizesObjectArray;
                    //FIX UTTEST

    // tag.allow_smaller_sizes indicates whether tag.primary_size is the maximum size requested (allowSmallerSizes=YES),
    // or whether tag.primary_size is the exact size requested (allowSmallerSizes=NO).
    //
    tagDict[@"allow_smaller_sizes"] = [NSNumber numberWithBool:allowSmallerSizes];
                    //FIX UTTEST


    //
    tagDict[@"allowed_media_types"] = [self.adFetcherDelegate adAllowedMediaTypes];

    //
    tagDict[@"disable_psa"] = [NSNumber numberWithBool:![self.adFetcherDelegate shouldServePublicServiceAnnouncements]];
    
    //
    tagDict[@"require_asset_url"] = [NSNumber numberWithBool:0];

    //
    CGFloat  reservePrice  = [self.adFetcherDelegate reserve];
    if (reservePrice > 0)  {
        tagDict[@"reserve"] = @(reservePrice);
    }


    //
    return [tagDict copy];
}

- (NSDictionary *)user {
    NSMutableDictionary *userDict = [[NSMutableDictionary alloc] init];
    
    NSInteger ageValue = [[self.adFetcherDelegate age] integerValue]; // Invalid value for hyphenated age
    if (ageValue > 0) {
        userDict[@"age"] = @(ageValue);
    }
    
    ANGender genderValue = [self.adFetcherDelegate gender];
    NSUInteger gender;
    switch (genderValue) {
        case ANGenderMale:
            gender = 1;
            break;
        case ANGenderFemale:
            gender = 2;
            break;
        default:
            gender = 0;
            break;
    }
    userDict[@"gender"] = @(gender);
    
    NSString *language = [NSLocale preferredLanguages][0];
    if (language.length) {
        userDict[@"language"] = language;
    }
    
    return [userDict copy];
}

- (NSDictionary *)device {
    NSMutableDictionary *deviceDict = [[NSMutableDictionary alloc] init];
    
    NSString *userAgent = ANUserAgent();
    if (userAgent) {
        deviceDict[@"useragent"] = userAgent;
    }
    
    NSDictionary *geo = [self geo];
    if (geo) {
        deviceDict[@"geo"] = geo;
    }
    
    deviceDict[@"make"] = @"Apple";
    
    NSString *deviceModel = ANDeviceModel();
    if (deviceModel) {
        deviceDict[@"model"] = deviceModel;
    }
    
    CTTelephonyNetworkInfo *netinfo = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *carrier = [netinfo subscriberCellularProvider];
    
    if (carrier.carrierName.length > 0) {
        deviceDict[@"carrier"] = carrier.carrierName;
    }
    
    ANReachability *reachability = [ANReachability reachabilityForInternetConnection];
    ANNetworkStatus status = [reachability currentReachabilityStatus];
    NSUInteger connectionType = 0;
    switch (status) {
        case ANNetworkStatusReachableViaWiFi:
            connectionType = 1;
            break;
        case ANNetworkStatusReachableViaWWAN:
            connectionType = 2;
            break;
        default:
            connectionType = 0;
            break;
    }
    deviceDict[@"connectiontype"] = @(connectionType);
    
    if (carrier.mobileCountryCode.length > 0) {
        deviceDict[@"mcc"] = @([carrier.mobileCountryCode integerValue]);
    }
    if (carrier.mobileNetworkCode.length > 0) {
        deviceDict[@"mnc"] = @([carrier.mobileNetworkCode integerValue]);
    }
    
    deviceDict[@"limit_ad_tracking"] = [NSNumber numberWithBool:!ANAdvertisingTrackingEnabled()];
    
    NSDictionary *deviceId = [self deviceId];
    if (deviceId) {
        deviceDict[@"device_id"] = deviceId;
    }
    
    NSInteger timeInMiliseconds = (NSInteger)[[NSDate date] timeIntervalSince1970];
    deviceDict[@"devtime"] = @(timeInMiliseconds);
    
    return [deviceDict copy];
}

- (NSDictionary *)deviceId {
    NSString *idfa = ANUDID();
    if (idfa) {
        return @{@"idfa":idfa};
    } else {
        return nil;
    }
}

- (NSDictionary *)geo 
{
    ANLocation  *location  = [self.adFetcherDelegate location];
    NSString    *zipcode   = [self.adFetcherDelegate zipcode];

    //
    if (!location && !zipcode)  {
        return nil;
    }

    NSMutableDictionary  *geoDict  = [[NSMutableDictionary alloc] init];

    //
    if (location) {
        CGFloat latitude = location.latitude;
        CGFloat longitude = location.longitude;
        
        if (location.precision >= 0) {
            NSNumberFormatter *nf = [[self class] precisionNumberFormatter];
            nf.maximumFractionDigits = location.precision;
            nf.minimumFractionDigits = location.precision;
            geoDict[@"lat"] = [nf numberFromString:[NSString stringWithFormat:@"%f", location.latitude]];
            geoDict[@"lng"] = [nf numberFromString:[NSString stringWithFormat:@"%f", location.longitude]];
        } else {
            geoDict[@"lat"] = @(latitude);
            geoDict[@"lng"] = @(longitude);
        }
        
        NSDate *locationTimestamp = location.timestamp;
        NSTimeInterval ageInSeconds = -1.0 * [locationTimestamp timeIntervalSinceNow];
        NSInteger ageInMilliseconds = (NSInteger)(ageInSeconds * 1000);
        
        geoDict[@"loc_age"] = @(ageInMilliseconds);
        geoDict[@"loc_precision"] = @((NSInteger)location.horizontalAccuracy);
    }

    //
    if (zipcode) {
            //TBD -- error check zipcode string -- must be location aware.
        geoDict[@"zip"] = [zipcode copy];
    }

    //
    return [geoDict copy];
}

+ (NSNumberFormatter *)precisionNumberFormatter {
    static dispatch_once_t precisionNumberFormatterToken;
    static NSNumberFormatter *precisionNumberFormatter;
    dispatch_once(&precisionNumberFormatterToken, ^{
        precisionNumberFormatter = [[NSNumberFormatter alloc] init];
        precisionNumberFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
    });
    return precisionNumberFormatter;
}

- (NSDictionary *)app {
    NSString *appId = [[NSBundle mainBundle] infoDictionary][@"CFBundleIdentifier"];
    if (appId) {
        return @{@"appid":appId};
    } else {
        return nil;
    }
}

@end
