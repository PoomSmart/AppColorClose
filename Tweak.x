#import <HBLog.h>
#import <PSHeader/PS.h>
#import <SpringBoard/SBIconImageInfo.h>
#import <SpringBoard/SBIcon.h>
#import <SpringBoard/SBIconView.h>
#import <UIKit/UIImage+Private.h>

@interface SBIconView (AppColorClose)
@property (retain, nonatomic) UIColor *dominantColor;
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

@interface SBIconImageView : UIView
@property (retain, nonatomic) UIImage *displayedImage;
- (UIImage *)contentsImage;
- (UIImage *)snapshot;
@end

@interface SBIconView (SpringBoard)
- (SBIconImageView *)_iconImageView;
- (UIImage *)iconImageSnapshot;
@end

@interface SBIcon (SpringBoard)
- (id)iconServicesIconForImage;
- (NSString *)applicationBundleIdentifierForImage;
@end

@interface ISImageDescriptor : NSObject
- (instancetype)initWithSize:(CGSize)size scale:(CGFloat)scale;
@property (nonatomic) BOOL shouldApplyMask;
@end

@interface ISIcon : NSObject
- (id)prepareImageForDescriptor:(ISImageDescriptor *)descriptor;
- (id)imageForDescriptor:(ISImageDescriptor *)descriptor;
@end

@interface ISBundleIdentifierIcon : ISIcon
- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier;
@end

@interface IFImage : NSObject
@property (readonly, nonatomic) CGImageRef CGImage;
@property (readonly, nonatomic) CGFloat scale;
@property (readonly, nonatomic) BOOL placeholder;
@end

struct pixel {
    unsigned char r, g, b, a;
};

static UIImage *imageFromIconServicesIcon(ISIcon *isIcon) {
    if (!isIcon)
        return nil;
    Class descriptorClass = NSClassFromString(@"ISImageDescriptor");
    ISImageDescriptor *descriptor = [[descriptorClass alloc] initWithSize:CGSizeMake(60, 60) scale:2];
    descriptor.shouldApplyMask = YES;

    IFImage *isImage = nil;
    if ([isIcon respondsToSelector:@selector(prepareImageForDescriptor:)])
        isImage = [isIcon prepareImageForDescriptor:descriptor];
    HBLogDebug(@"[AppColorClose] prepare ISIcon=%@ image=%@ placeholder=%d CGImage=%p", isIcon, isImage, (int)isImage.placeholder, isImage.CGImage);
    if (!isImage.CGImage || isImage.placeholder)
        return nil;
    CGFloat scale = isImage.scale > 0 ? isImage.scale : 2;
    return [UIImage imageWithCGImage:isImage.CGImage scale:scale orientation:UIImageOrientationUp];
}

static UIImage *snapshotOfView(UIView *view) {
    if (!view || CGRectIsEmpty(view.bounds))
        return nil;
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, 0);
#if DEBUG
    BOOL drawn = [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:NO];
#endif
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    HBLogDebug(@"[AppColorClose] snapshot view=%@ drawn=%d image=%@ size=%@", view, drawn, image, NSStringFromCGSize(image.size));
    return image;
}

static UIColor *dominantColorFromImage(UIImage *iconImage) {
    CGImageRef iconCGImage = iconImage.CGImage;
    if (!iconCGImage)
        return nil;
    size_t width = CGImageGetWidth(iconCGImage);
    size_t height = CGImageGetHeight(iconCGImage);
    HBLogDebug(@"[AppColorClose] sample image=%@ px=%zux%zu alpha=%u bpc=%zu bpp=%zu", iconImage, width, height, (unsigned)CGImageGetAlphaInfo(iconCGImage), CGImageGetBitsPerComponent(iconCGImage), CGImageGetBitsPerPixel(iconCGImage));
    if (width == 0 || height == 0)
        return nil;

    struct pixel *pixels = calloc(width * height, sizeof(struct pixel));
    if (!pixels)
        return nil;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width * 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    UIColor *color = nil;
    if (context) {
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), iconCGImage);
        NSUInteger red = 0, green = 0, blue = 0, count = 0;
        NSUInteger numberOfPixels = width * height;
        for (NSUInteger i = 0; i < numberOfPixels; ++i) {
            if (pixels[i].a < 16)
                continue;
            red += pixels[i].r;
            green += pixels[i].g;
            blue += pixels[i].b;
            count++;
        }
        HBLogDebug(@"[AppColorClose] opaque=%lu/%lu firstRGBA=%u,%u,%u,%u", (unsigned long)count, (unsigned long)numberOfPixels, pixels[0].r, pixels[0].g, pixels[0].b, pixels[0].a);
        if (count > 0)
            color = [UIColor colorWithRed:(red / (CGFloat)count) / 255.0 green:(green / (CGFloat)count) / 255.0 blue:(blue / (CGFloat)count) / 255.0 alpha:1.0];
        CGContextRelease(context);
    } else {
        HBLogDebug(@"[AppColorClose] bitmap context failed");
    }
    free(pixels);
    return color;
}

static UIColor *dominantColorFromIconView(SBIconView *iconView) {
    SBIcon *icon = iconView.icon;
    SBIconImageView *imageView = [iconView respondsToSelector:@selector(_iconImageView)] ? [iconView _iconImageView] : nil;
    HBLogDebug(@"[AppColorClose] icon=%@ leaf=%@ imageView=%@", icon, [icon leafIdentifier], imageView);

    NSMutableArray<UIImage *> *candidates = [NSMutableArray array];
    if ([iconView respondsToSelector:@selector(iconImageSnapshot)]) {
        UIImage *snapshot = [iconView iconImageSnapshot];
        HBLogDebug(@"[AppColorClose] iconImageSnapshot=%@", snapshot);
        if (snapshot)
            [candidates addObject:snapshot];
    }
    if ([imageView respondsToSelector:@selector(snapshot)]) {
        UIImage *snapshot = [imageView snapshot];
        HBLogDebug(@"[AppColorClose] imageView.snapshot=%@", snapshot);
        if (snapshot)
            [candidates addObject:snapshot];
    }
    UIImage *viewSnapshot = snapshotOfView(imageView);
    if (viewSnapshot)
        [candidates addObject:viewSnapshot];
    UIImage *displayed = imageView.displayedImage ?: [imageView contentsImage];
    HBLogDebug(@"[AppColorClose] displayed=%@ contents=%@", imageView.displayedImage, [imageView contentsImage]);
    if (displayed)
        [candidates addObject:displayed];

    ISIcon *isIcon = [icon respondsToSelector:@selector(iconServicesIconForImage)] ? [icon iconServicesIconForImage] : nil;
    NSString *bundleID = [icon applicationBundleID] ?: ([icon respondsToSelector:@selector(applicationBundleIdentifierForImage)] ? [icon applicationBundleIdentifierForImage] : nil);
    if (!isIcon && bundleID.length) {
        Class iconClass = NSClassFromString(@"ISBundleIdentifierIcon");
        isIcon = [[iconClass alloc] initWithBundleIdentifier:bundleID];
    }
    UIImage *isImage = imageFromIconServicesIcon(isIcon);
    if (isImage)
        [candidates addObject:isImage];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
    SBIconImageInfo info = { .size = CGSizeMake(48, 48), .scale = 1, .continuousCornerRadius = 12 };
    UIImage *legacy = nil;
    if ([icon respondsToSelector:@selector(generateIconImageWithInfo:)])
        legacy = [icon generateIconImageWithInfo:info];
    else if ([icon respondsToSelector:@selector(getIconImage:)])
        legacy = [icon getIconImage:2];
#pragma clang diagnostic pop
    HBLogDebug(@"[AppColorClose] legacy=%@", legacy);
    if (legacy)
        [candidates addObject:legacy];

    for (UIImage *image in candidates) {
        UIColor *color = dominantColorFromImage(image);
        if (color) {
            HBLogDebug(@"[AppColorClose] color=%@", color);
            return color;
        }
    }
    HBLogDebug(@"[AppColorClose] no usable raster");
    return nil;
}

static CGFloat readValue(NSString *key, CGFloat defaultValue) {
    id r = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    return r ? [r doubleValue] : defaultValue;
}

static void setColor(SBIconView *self) {
    SBCloseBoxView *closeBox = [self valueForKey:@"_closeBox"];
    if (!closeBox || closeBox.hidden)
        return;
    HBLogDebug(@"[AppColorClose] setColor view=%@ closeBox=%@", self, closeBox);
    UIColor *color = dominantColorFromIconView(self);
    if (!color) {
        HBLogDebug(@"[AppColorClose] skip, no color");
        return;
    }
    self.dominantColor = color;
    SBHomeScreenMaterialView *materialView = [closeBox materialView];
    UIView *tintView = [materialView valueForKey:@"_whiteTintView"];
    HBLogDebug(@"[AppColorClose] material=%@ tint=%@ x=%@", materialView, tintView, [materialView valueForKey:@"_xPlusDView"]);
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

%hook SBIconView

%property (retain, nonatomic) UIColor *dominantColor;

- (void)_updateCloseBoxAnimated:(BOOL)animated {
    %orig;
    setColor(self);
}

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
