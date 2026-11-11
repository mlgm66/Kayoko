#import "KayokoClippaIntegration.h"
#import "ClippaPinning.h"
#import "KayokoPasteboardItem.h"
#import "KayokoPasteboardManager.h"
#import <math.h>

static CGFloat const kKayokoClippaMaximumImageDimension = 4096;
static CGFloat const kKayokoClippaMaximumImagePixelCount = 16000000;
static CGFloat const kKayokoClippaTextWidthRatio = 0.80;

@implementation KayokoClippaIntegration
+ (Class)pinningControllerClass {
    Class controller = NSClassFromString(@"ClippaPinningController");
    return [controller respondsToSelector:@selector(isAvailable)] &&
        [controller respondsToSelector:@selector(pinImage:initialFrame:error:)] ? controller : Nil;
}
+ (BOOL)isAvailable {
    return NSThread.isMainThread && [[self pinningControllerClass] isAvailable];
}
+ (nullable UIImage *)noteImageFromText:(NSString *)text errorMessage:(NSString **)errorMessage {
    NSCharacterSet *content = NSCharacterSet.whitespaceAndNewlineCharacterSet.invertedSet;
    NSRange first = [text rangeOfCharacterFromSet:content];
    if (!text.length || first.location == NSNotFound) return nil;
    NSRange last = [text rangeOfCharacterFromSet:content options:NSBackwardsSearch];
    NSUInteger start, end;
    [text getLineStart:&start end:NULL contentsEnd:NULL forRange:first];
    [text getLineStart:NULL end:NULL contentsEnd:&end forRange:last];
    NSString *displayText = [text substringWithRange:NSMakeRange(start, end - start)];

    CGFloat screenWidth = [[UIScreen mainScreen] bounds].size.width;
    CGFloat maximumWidth = screenWidth * kKayokoClippaTextWidthRatio;
    CGFloat horizontalInset = 18.0;
    CGFloat verticalInset = 10.0;
    UIFont *font = [UIFont systemFontOfSize:20.0 weight:UIFontWeightRegular];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setLineBreakMode:NSLineBreakByWordWrapping];
    [paragraphStyle setLineSpacing:1.0];

    NSDictionary<NSAttributedStringKey, id> *attributes = @{
        NSFontAttributeName : font,
        NSForegroundColorAttributeName : [UIColor labelColor],
        NSParagraphStyleAttributeName : paragraphStyle
    };
    CGRect measuredTextRect = [displayText boundingRectWithSize:CGSizeMake(maximumWidth - horizontalInset * 2.0,
                                                                             CGFLOAT_MAX)
                                                          options:NSStringDrawingUsesLineFragmentOrigin |
                                                                  NSStringDrawingUsesFontLeading
                                                       attributes:attributes
                                                          context:nil];
    CGFloat imageWidth = ceil(maximumWidth);
    CGFloat imageHeight = MAX(46.0, ceil(measuredTextRect.size.height) + verticalInset * 2.0);
    CGSize imageSize = CGSizeMake(imageWidth, imageHeight);

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    CGFloat maximumScale = MIN(kKayokoClippaMaximumImageDimension / MAX(imageWidth, imageHeight),
                               sqrt(kKayokoClippaMaximumImagePixelCount / (imageWidth * imageHeight)));
    if (!isfinite(imageWidth) || !isfinite(imageHeight) || !isfinite(maximumScale) || maximumScale < 1.0) {
        if (errorMessage) *errorMessage = @"Text Too Long to Float";
        return nil;
    }
    [format setScale:MIN(format.scale, maximumScale)];
    [format setOpaque:YES];
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:imageSize format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *_Nonnull rendererContext) {
      (void)rendererContext;
      CGRect cardRect = CGRectMake(0, 0, imageSize.width, imageSize.height);
      [[UIColor secondarySystemBackgroundColor] setFill];
      UIRectFill(cardRect);

      CGRect textRect = CGRectInset(cardRect, horizontalInset, verticalInset);
      [displayText drawWithRect:textRect
                         options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                      attributes:attributes
                         context:nil];
    }];
}

+ (nullable UIImage *)scaledImageIfNeeded:(UIImage *)image {
    CGSize sourceSize = [image size];
    if (!image.CGImage || !isfinite(sourceSize.width) || !isfinite(sourceSize.height) || !isfinite(image.scale) || image.scale <= 0 || sourceSize.width <= 0.0 || sourceSize.height <= 0.0) {
        return nil;
    }

    CGFloat sourcePixelWidth = sourceSize.width * [image scale];
    CGFloat sourcePixelHeight = sourceSize.height * [image scale];
    CGFloat sourcePixelCount = sourcePixelWidth * sourcePixelHeight;
    CGFloat longestPixelSide = MAX(sourcePixelWidth, sourcePixelHeight);
    if (longestPixelSide <= kKayokoClippaMaximumImageDimension &&
        sourcePixelCount <= kKayokoClippaMaximumImagePixelCount) {
        return image;
    }

    CGFloat dimensionScale = kKayokoClippaMaximumImageDimension / longestPixelSide;
    CGFloat pixelScale = sqrt(kKayokoClippaMaximumImagePixelCount / sourcePixelCount);
    CGFloat scale = MIN(dimensionScale, pixelScale);
    if (!isfinite(scale) || scale <= 0.0 || scale >= 1.0) {
        return image;
    }

    CGSize targetSize = CGSizeMake(MAX(1.0, floor(sourcePixelWidth * scale)),
                                   MAX(1.0, floor(sourcePixelHeight * scale)));
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    [format setOpaque:NO];
    [format setScale:1.0];
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:targetSize format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *_Nonnull rendererContext) {
      (void)rendererContext;
      [image drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
    }];
}

+ (nullable UIImage *)imageForPasteboardItem:(KayokoPasteboardItem *)item errorMessage:(NSString **)errorMessage {
    if ([[item imageName] length] > 0) {
        UIImage *image = [[KayokoPasteboardManager sharedInstance] getImageForItem:item];
        return image ? [self scaledImageIfNeeded:image] : nil;
    }
    return [self noteImageFromText:[item content] errorMessage:errorMessage];
}


+ (BOOL)floatPasteboardItem:(KayokoPasteboardItem *)item error:(NSError **)error {
    if (error) *error = nil;
    NSString *message = nil;
    Class controller = [self pinningControllerClass];
    if (!NSThread.isMainThread) message = @"Pin on Main Thread";
    else if (!controller) message = @"Clippa Pinning Unavailable";
    UIImage *image = message ? nil : [self imageForPasteboardItem:item errorMessage:&message];
    if (!message && !image) message = @"Unable to Load Pin Image";
    if (message) {
        if (error) *error = [NSError errorWithDomain:@"com.mlgm.kayoko.pinning" code:1 userInfo:@{
            NSLocalizedDescriptionKey:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:message value:message table:@"Tweak"]
        }];
        return NO;
    }
    CGRect bounds = UIScreen.mainScreen.bounds;
    CGFloat scale = MIN(bounds.size.width * kKayokoClippaTextWidthRatio / image.size.width,
                        MAX(1, bounds.size.height - 32) / image.size.height);
    if ([[item imageName] length] > 0) {
        scale = MIN(0.704, MIN(MAX(1, bounds.size.width - 32) / image.size.width,
                               MIN(360, MAX(1, bounds.size.height * 0.4 - 32)) / image.size.height));
    }
    CGSize size = CGSizeMake(image.size.width * scale, image.size.height * scale);
    CGRect frame = CGRectMake(CGRectGetMidX(bounds) - size.width / 2, CGRectGetMinY(bounds) + 16,
                              size.width, size.height);
    return [controller pinImage:image initialFrame:frame error:error];
}
@end
