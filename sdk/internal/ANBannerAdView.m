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

#import "ANBannerAdView.h"

#import "ANUniversalAdFetcher.h"
#import "ANGlobal.h"
#import "ANLogging.h"
#import "ANMRAIDContainerView.h"

#import "UIView+ANCategory.h"
#import "UIWebView+ANCategory.h"
#import "ANBannerAdView+ANContentViewTransitions.h"
#import "ANAdView+PrivateMethods.h"




@interface ANBannerAdView () <ANBannerAdViewInternalDelegate>

@property (nonatomic, readwrite, strong)  UIView    *contentView;
@property (nonatomic, readwrite, strong)  NSNumber  *transitionInProgress;

@property (nonatomic, readwrite, strong)  NSArray<NSString *>  *impressionURLs;

@end



@implementation ANBannerAdView

@synthesize  autoRefreshInterval  = __autoRefreshInterval;
@synthesize  contentView          = _contentView;

@synthesize  adSize               = __adSize;
@synthesize  allowedAdSizes       = __allowedAdSizes;



#pragma mark - Initialization

- (void)initialize {
    [super initialize];
	
    self.autoresizingMask = UIViewAutoresizingNone;
    
    // Defaults.
    //
    __autoRefreshInterval  = kANBannerDefaultAutoRefreshInterval;
    _transitionDuration    = kAppNexusBannerAdTransitionDefaultDuration;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    self.adSize = self.frame.size;
}

+ (ANBannerAdView *)adViewWithFrame:(CGRect)frame placementId:(NSString *)placementId {
    return [[[self class] alloc] initWithFrame:frame placementId:placementId adSize:frame.size];
}

+ (ANBannerAdView *)adViewWithFrame:(CGRect)frame placementId:(NSString *)placementId adSize:(CGSize)size {
    return [[[self class] alloc] initWithFrame:frame placementId:placementId adSize:size];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self != nil) {
        [self initialize];
        self.backgroundColor = [UIColor clearColor];
    }
    
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame placementId:(NSString *)placementId {
    self = [self initWithFrame:frame];
    
    if (self != nil) {
        self.placementId = placementId;
    }
    
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame placementId:(NSString *)placementId adSize:(CGSize)size {
    self = [self initWithFrame:frame placementId:placementId];
    
    if (self != nil) {
        self.adSize = size;
    }
    
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame memberId:(NSInteger)memberId inventoryCode:(NSString *)inventoryCode {
    self = [self initWithFrame:frame];
    if (self != nil) {
        [self setInventoryCode:inventoryCode memberId:memberId];
    }
    
    return self;
    
}

- (instancetype)initWithFrame:(CGRect)frame memberId:(NSInteger)memberId inventoryCode:(NSString *)inventoryCode adSize:(CGSize)size{
    self = [self initWithFrame:frame memberId:memberId inventoryCode:inventoryCode];
    if (self != nil) {
        self.adSize = size;
    }
    return self;
}

- (void)loadAd
{
ANLogMark();
    [super loadAd];
}



#pragma mark - Getter and Setter methods

- (CGSize)adSize {
    ANLogDebug(@"adSize returned %@", NSStringFromCGSize(__adSize));
    return  __adSize;
}

// adSize represents /ut/v2 "primary_size".
//
// Following the lead from historical /mob request:
//   1) adSize represents an exact size, unless...
//   2) adSize is zero (CGSizeZero), it represents the maximum size and zero is replaced with the current size of the display.
//
- (void)setAdSize:(CGSize)adSize
{
    BOOL  allowSmallerSizes  = NO;

    if (CGSizeEqualToSize(adSize, CGSizeZero)) {
        adSize = self.frame.size;
        allowSmallerSizes = YES;
    }

    if (CGSizeEqualToSize(adSize, __adSize)) { return; }

    //
    self.adSizes = @[ [NSValue valueWithCGSize:adSize] ];
    self.allowSmallerSizes = allowSmallerSizes;

    ANLogDebug(@"Setting adSize to %@, %@ smaller sizes.",
                   NSStringFromCGSize(adSize),
                   self.allowSmallerSizes ? @"ALLOWING" : @"DISALLOWING"
               );
}


- (NSArray<NSValue *> *) adSizes
{
    return  [self.allowedAdSizes allObjects];
}

// adSizes represents /ut/v2 "sizes".
//
- (void)setAdSizes:(NSArray<NSValue *> *)adSizes
{
    NSValue  *adSizeAsValue  = [adSizes firstObject];
    if (!adSizeAsValue) {
        ANLogError(@"adSizes array IS EMPTY.");
        return;
    }

    CGSize  adSizeAsCGSize  = [adSizeAsValue CGSizeValue];
    if ((adSizeAsCGSize.width <= 0) || (adSizeAsCGSize.height <= 0)) {
        ANLogError(@"adSizes contains INVALID SIZE as initial value.  (%@)", NSStringFromCGSize(adSizeAsCGSize));
        return;
    }

    __adSize                = adSizeAsCGSize;
    __allowedAdSizes        = [NSMutableSet setWithArray:adSizes];
    self.allowSmallerSizes  = NO;
}


- (void)setAutoRefreshInterval:(NSTimeInterval)autoRefreshInterval {
    // if auto refresh is above the threshold (0), turn auto refresh on
    if (autoRefreshInterval > kANBannerAutoRefreshThreshold) {
        // minimum allowed value for auto refresh is (15).
        if (autoRefreshInterval < kANBannerMinimumAutoRefreshInterval) {
            __autoRefreshInterval = kANBannerMinimumAutoRefreshInterval;
            ANLogWarn(@"setAutoRefreshInterval called with value %f, AutoRefresh interval set to minimum allowed value %f", autoRefreshInterval, kANBannerMinimumAutoRefreshInterval);
        } else {
            __autoRefreshInterval = autoRefreshInterval;
            ANLogDebug(@"AutoRefresh interval set to %f seconds", __autoRefreshInterval);
        }
        
        [self.universalAdFetcher stopAdLoad];
        
        ANLogDebug(@"New autoRefresh interval set. Making ad request.");
        [self.universalAdFetcher requestAd];
    } else {
		ANLogDebug(@"Turning auto refresh off");
		__autoRefreshInterval = autoRefreshInterval;
    }
}

- (NSTimeInterval)autoRefreshInterval {
    ANLogDebug(@"autoRefreshInterval returned %f seconds", __autoRefreshInterval);
    return __autoRefreshInterval;
}



#pragma mark - Transitions

- (void)setContentView:(UIView *)newContentView {
    if (newContentView != _contentView) {
        
        if ([newContentView isKindOfClass:[UIWebView class]]) {
            UIWebView *webView = (UIWebView *)newContentView;
            [webView an_removeDocumentPadding];
            [webView an_setMediaProperties];
        }

        UIView *oldContentView = _contentView;
        _contentView = newContentView;

        if ([newContentView isKindOfClass:[ANMRAIDContainerView class]]) {
            ANMRAIDContainerView *standardAdView = (ANMRAIDContainerView *)newContentView;
            standardAdView.adViewDelegate = self;
        }
        
        if ([oldContentView isKindOfClass:[ANMRAIDContainerView class]]) {
            ANMRAIDContainerView *standardAdView = (ANMRAIDContainerView *)oldContentView;
            standardAdView.adViewDelegate = nil;
        }
        
        [self performTransitionFromContentView:oldContentView
                                 toContentView:newContentView];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.shouldResizeAdToFitContainer && [self.contentView isKindOfClass:[ANMRAIDContainerView class]]) {
        ANMRAIDContainerView *standardAdView = (ANMRAIDContainerView *)self.contentView;
        CGFloat horizontalScaleFactor = self.frame.size.width / [standardAdView an_originalFrame].size.width;
        CGFloat verticalScaleFactor = self.frame.size.height / [standardAdView an_originalFrame].size.height;
        CGFloat scaleFactor = horizontalScaleFactor < verticalScaleFactor ? horizontalScaleFactor : verticalScaleFactor;
        CGAffineTransform transform = CGAffineTransformMakeScale(scaleFactor, scaleFactor);
        standardAdView.transform = transform;
    }
}

- (NSNumber *)transitionInProgress {
    if (!_transitionInProgress) _transitionInProgress = @(NO);
    return _transitionInProgress;
}



#pragma mark - Implementation of abstract methods from ANAdView

- (void)loadAdFromHtml: (NSString *)html
                 width: (int)width
                height: (int)height
{
    self.adSize = CGSizeMake(width, height);
    [super loadAdFromHtml:html width:width height:height];
}




#pragma mark - ANUniversalAdFetcherDelegate


- (void)universalAdFetcher:(ANUniversalAdFetcher *)fetcher didFinishRequestWithResponse:(ANAdFetcherResponse *)response
{
ANLogMark();
    NSError *error;

    if ([response isSuccessful]) {
        UIView *contentView      = response.adObject;
        id      adObjectHandler  = response.adObjectHandler;

        if ([adObjectHandler respondsToSelector:@selector(impressionUrls)]) {
            self.impressionURLs = [adObjectHandler performSelector:@selector(impressionUrls)];
        }

        if ([contentView isKindOfClass:[UIView class]]) {
            self.contentView = contentView;
            [self adDidReceiveAd];

            if ([self an_isViewable])  {
                [self fireTrackers:self.impressionURLs];
            }
        }
        else {
            NSDictionary *errorInfo = @{NSLocalizedDescriptionKey: NSLocalizedString(@"Requested a banner ad but received a non-view object as response.", @"Error: We did not get a viewable object as a response for a banner ad request.")};
            error = [NSError errorWithDomain:AN_ERROR_DOMAIN
                                        code:ANAdResponseNonViewResponse
                                    userInfo:errorInfo];
        }
    }
    else {
        error = response.error;
    }

    if (error) {
        self.contentView = nil;
        [self adRequestFailedWithError:error];
    }
}

- (NSTimeInterval)autoRefreshIntervalForAdFetcher:(ANAdFetcher *)fetcher {
    return self.autoRefreshInterval;
}

- (CGSize)requestedSizeForAdFetcher:(ANUniversalAdFetcher *)fetcher {
    return self.adSize;
}




#pragma mark - ANAdViewInternalDelegate

- (NSString *) adTypeForMRAID  {
    return @"inline";
}

- (NSArray<NSValue *> *)adAllowedMediaTypes
{
    return  @[ @(ANAllowedMediaTypeBanner) ];
}


- (UIViewController *)displayController {
    UIViewController *displayController = self.rootViewController;
    if (!displayController) {
        displayController = [self an_parentViewController];
    }
    return displayController;
}




#pragma mark - UIView observer methods.

- (void)didMoveToWindow
{
    [self fireTrackers:self.impressionURLs];
}


@end
