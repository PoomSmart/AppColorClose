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
    NSUInteger red = 0;
    NSUInteger green = 0;
    NSUInteger blue = 0;
    CGImageRef iconCGImage = iconImage.CGImage;
    struct pixel *pixels = (struct pixel *)calloc(1, iconImage.size.width * iconImage.size.height * sizeof(struct pixel));
    if (pixels) {
        CGContextRef context = CGBitmapContextCreate((void *)pixels, iconImage.size.width, iconImage.size.height, 8, iconImage.size.width * 4, CGImageGetColorSpace(iconCGImage), kCGImageAlphaPremultipliedLast);
        if (context != NULL) {
            CGContextDrawImage(context, CGRectMake(0.0, 0.0, iconImage.size.width, iconImage.size.height), iconCGImage);
            NSUInteger numberOfPixels = iconImage.size.width * iconImage.size.height;
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
    return [UIColor colorWithRed:red/255.0f green:green/255.0f blue:blue/255.0f alpha:1.0f];
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
        CGFloat tintAlpha = readValue(@"SBCloseBoxTintAlpha", 0.65);
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
