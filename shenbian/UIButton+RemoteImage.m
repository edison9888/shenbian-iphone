//
//  UIButton+RemoteImage.m
//  shenbian
//
//  Created by xhan on 4/21/11.
//  Copyright 2011 百度. All rights reserved.
//

#import "UIButton+RemoteImage.h"
#import "SDWebImageManager.h"

@implementation UIButton(RemoteImage)

- (void)setImageWithURL:(NSURL *)url
{
    [self setImageWithURL:url placeholderImage:nil];
}


- (void)setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder
{
    SDWebImageManager *manager = [SDWebImageManager sharedManager];
	
    // Remove in progress downloader from queue
    [manager cancelForDelegate:self];
	
//    self.image = placeholder;
	[self setBackgroundImage:placeholder forState:UIControlStateNormal];
	
    if (url)
    {
        [manager downloadWithURL:url delegate:self];
    }
}

- (void)cancelCurrentImageLoad
{
    [[SDWebImageManager sharedManager] cancelForDelegate:self];
}

- (void)webImageManager:(SDWebImageManager *)imageManager didFinishWithImage:(UIImage *)image
{
//    self.image = image;
	[self setBackgroundImage:image forState:UIControlStateNormal];
}

@end
