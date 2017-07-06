#import "../PS.h"
#import <UIKit/UIImage+Private.h>

@interface SBIcon : NSObject
- (UIImage *)getIconImage:(NSInteger)type;
@end

@interface SBIconView : UIView
@property(retain, nonatomic) SBIcon *icon;
- (BOOL)_isShowingCloseBox;
@end

@interface SBCloseBoxView : UIView
@end

@interface SBIconBlurryBackgroundView : UIView
@end

struct pixel {
    unsigned char r, g, b, a;
};

static UIColor *dominantColorFromIcon(SBIcon *icon) {
    UIImage *iconImage = [icon getIconImage:2];
    CGImageRef iconCGImage = iconImage.CGImage;
    NSUInteger red = 0;
    NSUInteger green = 0;
    NSUInteger blue = 0;
    size_t width = CGImageGetWidth(iconCGImage);
    size_t height = CGImageGetHeight(iconCGImage);
    int bitmapBytesPerRow = width * 4;
    int bitmapByteCount = bitmapBytesPerRow * height;
    struct pixel *pixels = (struct pixel *)malloc(bitmapByteCount);
    if (pixels) {
        CGContextRef context = CGBitmapContextCreate((void *)pixels, width, height, 8, bitmapBytesPerRow, CGImageGetColorSpace(iconCGImage), kCGImageAlphaPremultipliedLast);
        if (context) {
            CGContextDrawImage(context, CGRectMake(0.0, 0.0, width, height), iconCGImage);
            NSUInteger numberOfPixels = width * height;
            for (int i = 0; i < numberOfPixels; i++) {
                red += pixels[i].r;
                green += pixels[i].g;
                blue += pixels[i].b;
            }
            red /= numberOfPixels;
            green /= numberOfPixels;
            blue /= numberOfPixels;
            CGContextRelease(context);
        }
        free(pixels);
    }
    return [UIColor colorWithRed:red/255.0 green:green/255.0 blue:blue/255.0 alpha:1.0];
}

static CGFloat readValue(NSString *key, CGFloat defaultValue) {
    id r = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    #if CGFLOAT_IS_DOUBLE
    return r ? [r doubleValue] : defaultValue;
    #else
    return r ? [r floatValue] : defaultValue;
    #endif
}

%hook SBIconView

- (void)_updateCloseBoxAnimated: (BOOL)animated {
    %orig;
    SBCloseBoxView *closeBox = MSHookIvar<SBCloseBoxView *>(self, "_closeBox");
    if (closeBox && !closeBox.hidden) {
        UIColor *dominantColor = dominantColorFromIcon(self.icon);
        MSHookIvar<UIView *>(closeBox, "_whiteTintView").backgroundColor = dominantColor;
        CGFloat tintAlpha = readValue(@"SBCloseBoxTintAlpha", 0.85);
        MSHookIvar<UIView *>(closeBox, "_whiteTintView").alpha = tintAlpha;
        CGFloat borderWidth = readValue(@"SBCloseBoxBorderWidth", 0.0);
        MSHookIvar<UIView *>(closeBox, "_whiteTintView").layer.borderWidth = borderWidth;
        if (borderWidth > 0.0)
            MSHookIvar<UIView *>(closeBox, "_whiteTintView").layer.borderColor = dominantColor.CGColor;

        MSHookIvar<UIImageView *>(closeBox, "_xColorBurnView").image = [MSHookIvar<UIImageView *>(closeBox, "_xColorBurnView").image _flatImageWithColor:dominantColor];
        MSHookIvar<UIView *>(closeBox, "_xColorBurnView").alpha = tintAlpha;
    }
}

%end

#ifdef TARGET_OS_SIMULATOR

%hook SBIconColorSettings

- (BOOL)closeBoxesEverywhere {
    return YES;
}

%end

%hook SBIconView

- (BOOL)iconViewDisplaysCloseBox: (id)arg1 {
    return YES;
}

%end

#endif
