#import <UIKit/UIKit.h>

@interface SBIcon : NSObject
- (UIImage *)getIconImage:(int)type;
@end

@interface SBIconView : UIView
@property(retain, nonatomic) SBIcon *icon;
@end

@interface SBCloseBoxView : UIView
@end

@interface SBIconBlurryBackgroundView : UIView
@end

@interface UIImage (DominantColor)
- (UIColor *)dominantColor;
@end

@interface UIImage (Addition)
- (UIImage *)_flatImageWithColor:(UIColor *)color;
@end

struct pixel {
    unsigned char r, g, b, a;
};

@implementation UIImage (DominantColor)
 
- (UIColor *)dominantColor
{
    NSUInteger red = 0;
    NSUInteger green = 0;
    NSUInteger blue = 0;
    struct pixel* pixels = (struct pixel *)calloc(1, self.size.width * self.size.height * sizeof(struct pixel));
    if (pixels != nil)
    {
        CGContextRef context = CGBitmapContextCreate(
                                                 (void*) pixels,
                                                 self.size.width,
                                                 self.size.height,
                                                 8,
                                                 self.size.width * 4,
                                                 CGImageGetColorSpace(self.CGImage),
                                                 kCGImageAlphaPremultipliedLast
                                                 );
        if (context != NULL)
        {
            CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, self.size.width, self.size.height), self.CGImage);
            NSUInteger numberOfPixels = self.size.width * self.size.height;
            for (int i=0; i<numberOfPixels; i++) {
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

@end

%hook SBIconView

- (void)_updateCloseBoxAnimated:(BOOL)animated
{
	%orig;
	SBCloseBoxView *closeBox = MSHookIvar<SBCloseBoxView *>(self, "_closeBox");
	if (closeBox != nil) {
		UIImage *iconImage = [self.icon getIconImage:2];
		UIColor *dominantColor = [iconImage dominantColor];
		[MSHookIvar<UIView *>(closeBox, "_whiteTintView") setBackgroundColor:dominantColor];
		id r = [[NSUserDefaults standardUserDefaults] objectForKey:@"SBCloseBoxTintAlpha"];
		CGFloat tintAlpha = r != nil ? [r floatValue] : 0.65;
		MSHookIvar<UIView *>(closeBox, "_whiteTintView").alpha = tintAlpha;
		
		// The followings add a border to the close box (Not in the first release of tweak)
		/*
		MSHookIvar<UIView *>(closeBox, "_whiteTintView").layer.borderWidth = 2;
		MSHookIvar<UIView *>(closeBox, "_whiteTintView").layer.borderColor = dominantColor.CGColor;
		*/

		[MSHookIvar<UIImageView *>(closeBox, "_xColorBurnView") setImage:[MSHookIvar<UIImageView *>(closeBox, "_xColorBurnView").image _flatImageWithColor:dominantColor]];
		[MSHookIvar<UIView *>(closeBox, "_xColorBurnView") setAlpha:tintAlpha];
	}
}

%end
