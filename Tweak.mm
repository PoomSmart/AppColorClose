#import "../PS.h"

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

static UIColor *dominantColorFromIcon(SBIcon *icon)
{
	UIImage *iconImage = [icon getIconImage:2];
	NSUInteger red = 0;
	NSUInteger green = 0;
	NSUInteger blue = 0;
	CGImageRef iconCGImage = iconImage.CGImage;
	struct pixel *pixels = (struct pixel *)calloc(1, iconImage.size.width * iconImage.size.height * sizeof(struct pixel));
	if (pixels != nil)
    {
		CGContextRef context = CGBitmapContextCreate((void *)pixels, iconImage.size.width, iconImage.size.height, 8, iconImage.size.width * 4, CGImageGetColorSpace(iconCGImage), kCGImageAlphaPremultipliedLast);
		if (context != NULL) {
			CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, iconImage.size.width, iconImage.size.height), iconCGImage);
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

%hook SBIconView

- (void)_updateCloseBoxAnimated:(BOOL)animated
{
	%orig;
	SBCloseBoxView *closeBox = MSHookIvar<SBCloseBoxView *>(self, "_closeBox");
	if (closeBox != nil && closeBox.hidden == NO) {
		UIColor *dominantColor = dominantColorFromIcon(self.icon);
		[MSHookIvar<UIView *>(closeBox, "_whiteTintView") setBackgroundColor:dominantColor];
		id r = [[NSUserDefaults standardUserDefaults] objectForKey:@"SBCloseBoxTintAlpha"];
		#if CGFLOAT_IS_DOUBLE
		CGFloat tintAlpha = r ? [r doubleValue] : 0.65f;
		#else
		CGFloat tintAlpha = r ? [r floatValue] : 0.65f;
		#endif
		MSHookIvar<UIView *>(closeBox, "_whiteTintView").alpha = tintAlpha;

		MSHookIvar<UIView *>(closeBox, "_whiteTintView").layer.borderWidth = 2.0f;
		MSHookIvar<UIView *>(closeBox, "_whiteTintView").layer.borderColor = dominantColor.CGColor;

		MSHookIvar<UIImageView *>(closeBox, "_xColorBurnView").image = [MSHookIvar<UIImageView *>(closeBox, "_xColorBurnView").image _flatImageWithColor:dominantColor];
		MSHookIvar<UIView *>(closeBox, "_xColorBurnView").alpha = tintAlpha;
	}
}

%end
