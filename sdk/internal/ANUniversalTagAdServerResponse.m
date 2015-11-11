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

#import "ANUniversalTagAdServerResponse.h"
#import "ANLogging.h"
#import "ANInterstitialAdFetcher.h"

static NSString *const kANUniversalTagAdServerResponseKeyNoBid = @"nobid";
static NSString *const kANUniversalTagAdServerResponseKeyTags = @"tags";
static NSString *const kANUniversalTagAdServerResponseKeyAd = @"ad";
static NSString *const kANUniversalTagAdServerResponseKeyAds = @"ads";

static NSString *const kANUniversalTagAdServerResponseKeyNotifyUrl = @"notify_url";

static NSString *const kANUniversalTagAdServerResponseKeyRTBObject = @"rtb";

static NSString *const kANUniversalTagAdServerResponseKeyVideo = @"video";
static NSString *const kANUniversalTagAdServerResponseVideoKeyContent = @"content";

static NSString *const kANUniversalTagAdServerResponseKeyBanner = @"banner";
static NSString *const kANUniversalTagAdServerResponseBannerKeyWidth = @"width";
static NSString *const kANUniversalTagAdServerResponseBannerKeyHeight = @"height";
static NSString *const kANUniversalTagAdServerResponseBannerKeyContent = @"content";

static NSString *const kANUniversalTagAdServerResponseMraidJSFilename = @"mraid.js";

@interface ANUniversalTagAdServerResponse ()

@property (nonatomic, readwrite, assign) BOOL containsAds;
@property (nonatomic, readwrite, strong) ANStandardAd *standardAd;
@property (nonatomic, readwrite, strong) NSMutableArray *standardAds;
@property (nonatomic, readwrite, strong) ANVideoAd *videoAd;
@property (nonatomic, readwrite, strong) NSMutableArray *videoAds;

@end

@implementation ANUniversalTagAdServerResponse

- (instancetype)initWithAdServerData:(NSData *)data {
    self = [super init];
    if (self) {
    #if kANANInterstitialAdFetcherUseUTV2
        [self processV2ResponseData:data];
    #else
        [self processResponseData:data];
    #endif
    }
    return self;
}

+ (ANUniversalTagAdServerResponse *)responseWithData:(NSData *)data {
    return [[ANUniversalTagAdServerResponse alloc] initWithAdServerData:data];
}

- (void)processResponseData:(NSData *)data {
    NSDictionary *jsonResponse = [[self class] jsonResponseFromData:data];
    if (jsonResponse) {
        NSArray *tags = [[self class] tagsFromJSONResponse:jsonResponse];
        for (NSDictionary *tag in tags) {
            if ([[self class] isNoBidTag:tag]) {
                continue;
            }
            NSDictionary *adObject = [[self class] adObjectFromTag:tag];
            if (adObject) {
                ANStandardAd *standardAd = [[self class] standardAdFromAdObject:adObject];
                if (standardAd) {
                    [self.standardAds addObject:standardAd];
                }
                ANVideoAd *videoAd = [[self class] videoAdFromAdObject:adObject];
                if (videoAd) {
                    videoAd.vastDataModel.notifyUrlString = [adObject[kANUniversalTagAdServerResponseKeyNotifyUrl] description];
                    [self.videoAds addObject:videoAd];
                }
            }
        }
    }
    self.standardAd = [self.standardAds firstObject];
    self.videoAd = [self.videoAds firstObject];
    if (self.standardAd || self.videoAd) {
        self.containsAds = YES;
    }
}

+ (BOOL)isNoBidTag:(NSDictionary *)tag {
    if (tag[kANUniversalTagAdServerResponseKeyNoBid]) {
        BOOL noBid = [tag[kANUniversalTagAdServerResponseKeyNoBid] boolValue];
        return noBid;
    }
    return NO;
}

+ (NSArray *)tagsFromJSONResponse:(NSDictionary *)jsonResponse {
    return [[self class] validDictionaryArrayForKey:kANUniversalTagAdServerResponseKeyTags
                                     inJSONResponse:jsonResponse];
}

+ (NSDictionary *)adObjectFromTag:(NSDictionary *)tag {
    if ([tag[kANUniversalTagAdServerResponseKeyAd] isKindOfClass:[NSDictionary class]]) {
        return tag[kANUniversalTagAdServerResponseKeyAd];
    }
    return nil;
}

+ (ANStandardAd *)standardAdFromAdObject:(NSDictionary *)adObject {
    if ([adObject[kANUniversalTagAdServerResponseKeyBanner] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *banner = adObject[kANUniversalTagAdServerResponseKeyBanner];
        ANStandardAd *standardAd = [[ANStandardAd alloc] init];
        standardAd.width = [banner[kANUniversalTagAdServerResponseBannerKeyWidth] description];
        standardAd.height = [banner[kANUniversalTagAdServerResponseBannerKeyHeight] description];
        standardAd.content = [banner[kANUniversalTagAdServerResponseBannerKeyContent] description];
        if (!standardAd.content || [standardAd.content length] == 0) {
            ANLogError(@"blank_ad");
            return nil;
        }
        NSRange mraidJSRange = [standardAd.content rangeOfString:kANUniversalTagAdServerResponseMraidJSFilename];
        if (mraidJSRange.location != NSNotFound) {
            standardAd.mraid = YES;
        }
        return standardAd;
    }
    return nil;
}

+ (ANVideoAd *)videoAdFromAdObject:(NSDictionary *)adObject {
    if ([adObject[kANUniversalTagAdServerResponseKeyVideo] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *video = adObject[kANUniversalTagAdServerResponseKeyVideo];
        ANVideoAd *videoAd = [[ANVideoAd alloc] init];
        videoAd.content = [video[kANUniversalTagAdServerResponseVideoKeyContent] description];
        videoAd.vastDataModel = [[ANVast alloc] initWithContent:videoAd.content];
        if (!videoAd.vastDataModel) {
            ANLogDebug(@"Invalid VAST content, unable to use");
            return nil;
        }
        return videoAd;
    }
    return nil;
}

#pragma mark - Universal Tag V2 Support

- (void)processV2ResponseData:(NSData *)data {
    NSDictionary *jsonResponse = [[self class] jsonResponseFromData:data];
    if (jsonResponse) {
        NSArray *tags = [[self class] tagsFromJSONResponse:jsonResponse];
        for (NSDictionary *tag in tags) {
            if ([[self class] isNoBidTag:tag]) {
                continue;
            }
            NSArray *adsArray = [[self class] adsArrayFromTag:tag];
            if (adsArray) {
                for (id adObject in adsArray) {
                    if (![adObject isKindOfClass:[NSDictionary class]]) {
                        continue;
                    }
                    NSDictionary *rtbObject = [[self class] rtbObjectFromAdObject:adObject];
                    if (!rtbObject) {
                        return;
                    }
                    ANStandardAd *standardAd = [[self class] standardAdFromAdObject:rtbObject];
                    if (standardAd) {
                        [self.standardAds addObject:standardAd];
                    }
                    ANVideoAd *videoAd = [[self class] videoAdFromAdObject:rtbObject];
                    if (videoAd) {
                        videoAd.vastDataModel.notifyUrlString = [adObject[kANUniversalTagAdServerResponseKeyNotifyUrl] description];
                        [self.videoAds addObject:videoAd];
                    }
                }
            }
        }
    }
    self.standardAd = [self.standardAds firstObject];
    self.videoAd = [self.videoAds firstObject];
    if (self.standardAd || self.videoAd) {
        self.containsAds = YES;
    }
}

+ (NSArray *)adsArrayFromTag:(NSDictionary *)tag {
    if ([tag[kANUniversalTagAdServerResponseKeyAds] isKindOfClass:[NSArray class]]) {
        return tag[kANUniversalTagAdServerResponseKeyAds];
    }
    return nil;
}

+ (NSDictionary *)rtbObjectFromAdObject:(NSDictionary *)adObject {
    if ([adObject[kANUniversalTagAdServerResponseKeyRTBObject] isKindOfClass:[NSDictionary class]]) {
        return adObject[kANUniversalTagAdServerResponseKeyRTBObject];
    }
    return nil;
}

#pragma mark - Helper Methods

- (NSMutableArray *)standardAds {
    if (!_standardAds) _standardAds = [[NSMutableArray alloc] init];
    return _standardAds;
}

- (NSMutableArray *)videoAds {
    if (!_videoAds) _videoAds = [[NSMutableArray alloc] init];
    return _videoAds;
}

+ (NSDictionary *)jsonResponseFromData:(NSData *)data {
    NSString *responseString = [[NSString alloc] initWithData:data
                                                     encoding:NSUTF8StringEncoding];
    if (!responseString || [responseString length] == 0) {
        ANLogDebug(@"Received empty response from ad server");
        return nil;
    }
    
    NSError *jsonParsingError = nil;
    id jsonResponse = [NSJSONSerialization JSONObjectWithData:data
                                                      options:0
                                                        error:&jsonParsingError];
    if (jsonParsingError) {
        ANLogError(@"response_json_error %@", jsonParsingError);
        return nil;
    } else if (![jsonResponse isKindOfClass:[NSDictionary class]]) {
        ANLogError(@"Response from ad server in an unexpected format: %@", jsonResponse);
        return nil;
    }
    
    return (NSDictionary *)jsonResponse;
}

+ (NSArray *)validDictionaryArrayForKey:(NSString *)key
                         inJSONResponse:(NSDictionary *)jsonResponse {
    if ([jsonResponse[key] isKindOfClass:[NSArray class]]) {
        NSArray *adsArray = (NSArray *)jsonResponse[key];
        NSMutableArray *validAdsArray = [[NSMutableArray alloc] initWithCapacity:[adsArray count]];
        [adsArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([obj isKindOfClass:[NSDictionary class]]) {
                [validAdsArray addObject:obj];
            }
        }];
        if (validAdsArray.count) {
            return [validAdsArray copy];
        }
    }
    return nil;
}

@end