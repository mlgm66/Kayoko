#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#define ClippaPinningErrorDomain @"com.mlgm.clippa.pinning"

typedef NS_ENUM(NSInteger, ClippaPinningErrorCode) {
    ClippaPinningErrorWrongThread = 1,
    ClippaPinningErrorNotReady,
    ClippaPinningErrorDisabled,
    ClippaPinningErrorLocked,
    ClippaPinningErrorBusy,
    ClippaPinningErrorInvalidImage,
    ClippaPinningErrorImageTooLarge,
    ClippaPinningErrorInvalidFrame,
    ClippaPinningErrorPresentationFailed,
    ClippaPinningErrorPersistence,
};

@interface ClippaPinningController : NSObject
+ (BOOL)isAvailable;
+ (BOOL)pinImage:(UIImage *)image
    initialFrame:(CGRect)initialFrame
           error:(NSError * _Nullable * _Nullable)error;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
