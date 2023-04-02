#import <PSHeader/PS.h>
#import <SpringBoard/SBIconImageInfo.h>
#import <SpringBoard/SBIcon.h>
#import <SpringBoard/SBIconView.h>
#import <UIKit/UIImage+Private.h>

@interface SBIconView (AppColorClose)
@property(retain, nonatomic) UIColor *dominantColor;
@end

@interface SBHomeScreenMaterialView : UIView
@end

@interface SBHomeScreenButton : UIView
- (SBHomeScreenMaterialView *)materialView;
@end

@interface SBCloseBoxView : SBHomeScreenButton
@end

@interface SBIconBlurryBackgroundView : UIView
@end

struct pixel {
    unsigned char r, g, b, a;
};

static UIColor *dominantColorFromIcon(SBIcon *icon) {
    UIImage *iconImage = nil;
    if (@available(iOS 13.0, *))
        iconImage = [icon generateIconImageWithInfo:(SBIconImageInfo) { .size = CGSizeMake(48, 48), .scale = 1, .continuousCornerRadius = 12 }];
    else
        iconImage = [icon getIconImage:2];
    if (iconImage == nil)
        return [UIColor blackColor];
    NSUInteger red = 0, green = 0, blue = 0;
    CGImageRef iconCGImage = iconImage.CGImage;
    struct pixel *pixels = (struct pixel *)calloc(1, iconImage.size.width * iconImage.size.height * sizeof(struct pixel));
    if (pixels != nil)     {
        CGContextRef context = CGBitmapContextCreate((void *)pixels, iconImage.size.width, iconImage.size.height, 8, iconImage.size.width * 4, CGImageGetColorSpace(iconCGImage), kCGImageAlphaPremultipliedLast);
        if (context != NULL) {
            CGContextDrawImage(context, CGRectMake(0.0, 0.0, iconImage.size.width, iconImage.size.height), iconCGImage);
            NSUInteger numberOfPixels = iconImage.size.width * iconImage.size.height;
            for (int i = 0; i < numberOfPixels; ++i) {
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
    return r ? [r doubleValue] : defaultValue;
}

static void setColor(SBIconView *self, SBIcon *icon) {
    SBCloseBoxView *closeBox = [self valueForKey:@"_closeBox"];
    if (closeBox && !closeBox.hidden) {
        // if (self.dominantColor == nil)
            self.dominantColor = dominantColorFromIcon(self.icon);
        SBHomeScreenMaterialView *materialView = [closeBox materialView];
        UIView *tintView = [materialView valueForKey:@"_whiteTintView"];
        tintView.backgroundColor = self.dominantColor;
        CGFloat tintAlpha = readValue(@"SBCloseBoxTintAlpha", 0.85);
        tintView.alpha = tintAlpha;
        CGFloat borderWidth = readValue(@"SBCloseBoxBorderWidth", 0.0);
        tintView.layer.borderWidth = borderWidth;
        if (borderWidth > 0.0)
            tintView.layer.borderColor = self.dominantColor.CGColor;
        UIImageView *xView = [materialView valueForKey:@"_xPlusDView"];
        xView.image = [xView.image _flatImageWithColor:self.dominantColor];
        xView.alpha = tintAlpha;
    }
}

%hook SBIconView

%property(retain, nonatomic) UIColor *dominantColor;

- (void)_updateCloseBoxAnimated:(BOOL)animated {
    %orig;
    setColor(self, self.icon);
}

// - (void)prepareForReuse {
//     self.dominantColor = nil;
//     %orig;
// }

%end

#ifdef TARGET_OS_SIMULATOR

%hook SBIconColorSettings

- (BOOL)closeBoxesEverywhere {
    return YES;
}

%end

%hook SBIconView

- (BOOL)iconViewDisplaysCloseBox:(id)arg1 {
    return YES;
}

%end

#endif
