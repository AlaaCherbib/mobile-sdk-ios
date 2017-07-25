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

#import <AdColony/AdColony.h>
#import <AdColony/AdColonyAdOptions.h>
#import <AdColony/AdColonyAdRequestError.h>
#import <AdColony/AdColonyAppOptions.h>
#import <AdColony/AdColonyInterstitial.h>
#import <AdColony/AdColonyOptions.h>
#import <AdColony/AdColonyTypes.h>
#import <AdColony/AdColonyUserMetadata.h>
#import <AdColony/AdColonyZone.h>

#import "ANAdAdapterBaseAdColony.h"
#import "ANAdAdapterBaseAdColony+PrivateMethods.h"

#import "ANLogging.h"



static NSString             *appID    = nil;
static NSArray<NSString *>  *zoneIDs  = nil;



@implementation ANAdAdapterBaseAdColony

#pragma mark - Configuration lifecycle.

+ (void)configureWithAppID: (NSString *)appIDValue
                   zoneIDs: (NSArray *)zoneIDsValue
{
    appID    = appIDValue;
    zoneIDs  = zoneIDsValue;

    ANLogTrace(@"AdColony version %@ is CONFIGURED to serve ads.", [AdColony getSDKVersion]);
}

+ (void)configureAndInitializeWithAppID: (NSString *)appID
                                zoneIDs: (NSArray *)zoneIDs
{
    [ANAdAdapterBaseAdColony configureWithAppID: appID
                                        zoneIDs: zoneIDs ];

    [ANAdAdapterBaseAdColony initializeAdColonySDK:nil];
}

+ (void)initializeAdColonySDK: (void (^)(void))completionAction
{
    [AdColony configureWithAppID: [ANAdAdapterBaseAdColony getAppID]
                         zoneIDs: [ANAdAdapterBaseAdColony getZoneIDs]
                         options: [ANAdAdapterBaseAdColony getAppOptions]
                      completion: ^(NSArray<AdColonyZone *> * _Nonnull zones)
                                  {
                                      ANLogTrace(@"AdColony version %@ is READY to serve ads.  \n\tzones=%@", [AdColony getSDKVersion], zones);
                                      if (!completionAction) {
                                          completionAction();
                                      }
                                  }
     ];
}

+ (void)setAdColonyTargetingWithTargetingParameters:(ANTargetingParameters *)targetingParameters
{
ANLogMark();

    AdColonyAppOptions  *appOptions  = [ANAdAdapterBaseAdColony getAppOptions];

    if (targetingParameters.age) {
        appOptions.userMetadata.userAge = [targetingParameters.age integerValue];
    }
    
    switch (targetingParameters.gender) {
        case ANGenderMale:
            appOptions.userMetadata.userGender = ADCUserMale;
            break;
        case ANGenderFemale:
            appOptions.userMetadata.userGender = ADCUserFemale;
            break;
            
        default:
            break;
    }
    
    if (targetingParameters.location) {
        appOptions.userMetadata.userLatitude = [NSNumber numberWithFloat:targetingParameters.location.latitude];
        appOptions.userMetadata.userLongitude = [NSNumber numberWithFloat:targetingParameters.location.longitude];
    }

    if ([targetingParameters.customKeywords count] > 0)
                    //FIX  test me
    {
        for (NSString *key in targetingParameters.customKeywords) {
            NSString  *value  = [targetingParameters.customKeywords objectForKey:key];

            [appOptions.userMetadata setMetadataWithKey:key andStringValue:value];
        }
    }
}



#pragma mark - Helper methods.

+ (NSString *) getAppID
{
    return appID;
}

+ (NSArray<NSString *> *) getZoneIDs
{
    return zoneIDs;
}

+ (AdColonyAppOptions *) getAppOptions
{
    AdColonyAppOptions  *appOptions  = [AdColony getAppOptions];

    if (nil == appOptions) {
        appOptions = [[AdColonyAppOptions alloc] init];
        appOptions.disableLogging  = YES;
    }

    if (nil == appOptions.userMetadata) {
        appOptions.userMetadata = [[AdColonyUserMetadata alloc] init];
    }

    return  appOptions;
}


@end
