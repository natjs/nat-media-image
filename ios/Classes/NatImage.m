//
//  NatImage.m
//
//  Created by huangyake on 17/1/7.
//  Copyright © 2017 Instapp. All rights reserved.
//

#import "NatImage.h"
#import "TZImagePickerController.h"
#import <CoreImage/CoreImage.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <ImageIO/ImageIO.h>
#import "SDWebImageCompat.h"
#import "SDWebImageDownloader.h"
#import <Photos/Photos.h>
#import "HooliURLProtocol.h"

#define _FOUR_CC(c1,c2,c3,c4) ((uint32_t)(((c4) << 24) | ((c3) << 16) | ((c2) << 8) | (c1)))
#define _TWO_CC(c1,c2) ((uint16_t)(((c2) << 8) | (c1)))

@interface NatImage ()
@property(nonatomic, strong)NSMutableArray *photos;
@end

@implementation NatImage

+ (NatImage *)singletonManger{
    static id manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
        [NSURLProtocol registerClass:[HooliURLProtocol class]];
    });
    return manager;
}

- (void)pick:(NSDictionary *)params :(NatCallback)callback{
    NSInteger limit = [params[@"limit"] integerValue];
    BOOL showCamera = [params[@"showCamera"] boolValue];
    
    if (limit <= 0 || limit > 9) {
        limit = 9;
    }
    
    ALAuthorizationStatus author = [ALAssetsLibrary authorizationStatus];
    
    if (author == ALAuthorizationStatusRestricted || author ==ALAuthorizationStatusDenied){
        //无权限
        callback(nil,@{@"error":@{@"msg":@"MEDIA_IMAGE_PERMISSION_DENIED ",@"code":@1}});
        return;
    }
    
    TZImagePickerController *picker = [[TZImagePickerController alloc] initWithMaxImagesCount:limit delegate:nil];
    picker.photoWidth = 2048;
    picker.allowPickingVideo = NO;
    picker.allowTakePicture = showCamera;
    
    [picker setDidFinishPickingPhotosWithInfosHandle:^(NSArray<UIImage *> *photos, NSArray *assets, BOOL isSelectOriginalPhoto, NSArray<NSDictionary *> *infos) {
        NSMutableArray *array = [NSMutableArray arrayWithCapacity:assets.count];
        if ([assets.lastObject isKindOfClass:[ALAsset class]]) {
            //        alas
            for (ALAsset *alass in assets) {
                NSString *str = [[alass valueForProperty:ALAssetPropertyAssetURL] resourceSpecifier];
                str = [str substringFromIndex:2];
                str = [@"nat://static/image/" stringByAppendingString:str];
                [array addObject:str];
            }
            
            
        }else{
            for (PHAsset *phasset in assets) {
                NSString *idif = phasset.localIdentifier;
                idif = [@"nat://static/image/" stringByAppendingString:idif];
                [array addObject:idif];
            }
        }
        callback(nil,@{@"paths":array});
        
    }];
    
    [[self getCurrentVC] presentViewController:picker animated:YES completion:nil];

}
- (void)preview:(NSArray *)files :(NSDictionary *)params :(NatCallback)callback{
    self.photos = [NSMutableArray arrayWithCapacity:0];
     NSString *style = params[@"style"];
    NSInteger current = [params[@"current"] integerValue];
    if (![files isKindOfClass:[NSArray class]] || files.count ==0) {
        callback(nil,@{@"error":@{@"msg":@"MEDIA_SRC_NOT_SUPPORTED",@"code":@110120}});
        return;
    }
    for (NSString *str in files) {
        
        if (str) {
           NSURL *url = [NSURL URLWithString:str];
            if ([url.scheme isEqual:@"http"] || [url.scheme isEqual:@"https"] || [url.scheme isEqual:@"nat"]) {
                MWPhoto *photo = [MWPhoto photoWithURL:url];
                [self.photos addObject:photo];
            }else{
                callback(@{@"error":@{@"msg":@"MEDIA_SRC_NOT_SUPPORTED",@"code":@110120}},nil);
            }
        }else{
            callback(@{@"error":@{@"msg":@"MEDIA_SRC_NOT_SUPPORTED",@"code":@110120}},nil);
        }
    }
    if ([style isEqual:@"dots"] && self.photos.count>9) {
        style = @"label";
    }

    MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithDelegate:self];
    [browser setCurrentPhotoIndex:current];
    browser.style = style;
    //分享按钮
    browser.displayActionButton = YES;
    browser.displayNavArrows = NO;  //是否分页切换导航
    //是否显示选择按钮在图片上,默认否
//    browser.displaySelectionButtons =YES;
    //控制条件控件是否显示,默认否
//    browser.alwaysShowControls = YES;
    //自动适用大小,默认是
    browser.zoomPhotosToFill =YES;
    //是否允许用网格查看所有图片,默认是
//    browser.enableGrid = YES;
    //是否第一张,默认否 browser.startOnGrid =YES;
    //是否开始对缩略图网格代替第一张照片 browser.enableSwipeToDismiss = YES;
    //播放页码  [browser setCurrentPhotoIndex:0];
    
    UIViewController *vc = [self getCurrentVC];
//    if ([vc isKindOfClass:[UINavigationController class]]) {
//        [(UINavigationController *)vc pushViewController:browser animated:YES];
//    }else if(vc.navigationController){
//        [vc.navigationController pushViewController:browser animated:YES];
//    }else{
   
        [vc presentViewController:browser animated:YES completion:nil];
        [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
//    }
    

}
- (void)info:(NSString *)path :(NatCallback)callback{
    NSURL * url  = [NSURL URLWithString:path];
    if (url==nil) {
        callback(@{@"error":@{@"msg":@"MEDIA_SRC_NOT_SUPPORTED",@"code":@110120}},nil);
        return;
    }
        [[SDWebImageDownloader sharedDownloader] downloadImageWithURL:url options:SDWebImageDownloaderUseNSURLCache progress:nil completed:^(UIImage *image, NSData *data, NSError *error, BOOL finished) {
            if (data) {
                NSMutableDictionary *dic = [self getExifInfoWithImageData:data];
                NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:0];
                if(dic[@"PixelHeight"])dictionary[@"height"] = dic[@"PixelHeight"];
                if(dic[@"PixelWidth"])dictionary[@"width"] = dic[@"PixelWidth"];
                NSString *str = [NatImage typeForImageData:data];
                if(str.length)dictionary[@"type"] = str;
                if ([str isEqualToString:@"unknow"]) {
                     callback(@{@"error":@{@"msg":@"MEDIA_FILE_TYPE_NOT_SUPPORTED",@"code":@110110}},nil);
                    return ;
                }
                callback(nil,dictionary);

            }else{
                callback(@{@"error":@{@"msg":@"MEDIA_NETWORK_ERROR ",@"code":@110050}},nil);
            }
        }];
//        UIImage *result = [UIImage imageWithData:data];
//        NSLog(@"%@",[self getExifInfoWithImageData:data]);
        
//    }else if([url.scheme caseInsensitiveCompare:@"assets-library"]){
//        __block ALAssetsLibrary *lib = [[ALAssetsLibrary alloc] init];
//        [lib assetForURL:url resultBlock:^(ALAsset *asset) {
//            
//            ALAssetRepresentation *rep = [asset defaultRepresentation];
//            Byte *buffer = (Byte*)malloc((unsigned long)rep.size);
//            NSUInteger buffered = [rep getBytes:buffer fromOffset:0.0 length:((unsigned long)rep.size) error:nil];
//            NSData *data = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
//            NSMutableDictionary *dic = [self getExifInfoWithImageData:data];
//            NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:0];
//            if(dic[@"PixelHeight"])dictionary[@"height"] = dic[@"PixelHeight"];
//            if(dic[@"PixelWidth"])dictionary[@"width"] = dic[@"PixelWidth"];
//            NSString *str = [NatImage typeForImageData:data];
//            if(str.length)dictionary[@"type"] = str;
//            callback(nil,dictionary);
//
//        } failureBlock:^(NSError *error) {
//            callback(@{@"error":@{@"code":@(error.code),@"msg":error.domain}},nil);
//        }];
//    }
    
}


- (void)exif:(NSString *)path :(NatCallback)callback{
    if (!path) {
       callback(@{@"error":@{@"msg":@"MEDIA_SRC_NOT_SUPPORTED",@"code":@110120}},nil);
        return;
    }
    NSURL *url = [NSURL URLWithString:path];
        [[SDWebImageDownloader sharedDownloader] downloadImageWithURL:url options:SDWebImageDownloaderUseNSURLCache progress:nil completed:^(UIImage *image, NSData *data, NSError *error, BOOL finished) {
            
            if (error) {
                callback(@{@"error":@{@"msg":@"MEDIA_NETWORK_ERROR ",@"code":@110050}},nil);
                return;
            }
            
            NSMutableDictionary *dic = [self getExifInfoWithImageData:data];
            NSLog(@"dic  %@",dic);
            if (dic) {
                NSDictionary *tiff = dic[@"{tiff}"];
                NSDictionary *exif = dic[@"{Exif}"];
                NSMutableDictionary *info = [exif mutableCopy];
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                dateFormatter.dateFormat = @"yyyy:MM:dd HH:mm:ss";
                if (info == nil) {
                    info = [NSMutableDictionary dictionaryWithCapacity:0];
                }
                if(dic[@"PixelWidth"])info[@"ImageWidth"] = dic[@"PixelWidth"];
                if(dic[@"PixelHeight"]) info[@"ImageLength"] = dic[@"PixelHeight"];
                if (dic[@"{Exif}"]) {
                    if(exif[@"DateTimeDigitized"]){
                        NSDate *date = [dateFormatter dateFromString:exif[@"DateTimeDigitized"]];
                        NSTimeInterval time = [date timeIntervalSince1970];
                        info[@"DateTimeDigitized"] = [NSNumber numberWithUnsignedInteger:time * 1000];
                    }
                    
                    if(exif[@"DateTimeOriginal"]){
                        NSDate *date = [dateFormatter dateFromString:exif[@"DateTimeOriginal"]];
                        NSTimeInterval time = [date timeIntervalSince1970];
                        info[@"DateTimeOriginal"] = [NSNumber numberWithUnsignedInteger:time * 1000];
                    }
                    
                    if (exif[@"ExifVersion"]) {
                        NSString *version = @"";
                        for (NSNumber *number in exif[@"ExifVersion"]) {
                            version = [version stringByAppendingFormat:@"%@.",number];
                        }
                        version = [version substringToIndex:version.length-1];
                        info[@"ExifVersion"] = version;
                    }
                    
                    
                    
                    if (exif[@"ISOSpeedRatings"]) {
                        info[@"ISOSpeedRatings"] = [exif[@"ISOSpeedRatings"] firstObject];
                    }

                }
                
                if (tiff) {
                    for (NSString *key in tiff.allKeys) {
                        if (![key isEqualToString:@"DateTime"]) {
                            [info setObject:tiff[key] forKey:key];
                        }else{
                            if (tiff[@"DateTime"]) {
                                NSDate *date = [dateFormatter dateFromString:tiff[@"DateTime"]];
                                NSTimeInterval time = [date timeIntervalSince1970];
                                info[@"DateTime"] = [NSNumber numberWithUnsignedInteger:time * 1000];
                            }
                            
                        }
                    }

                }
                callback(nil,info);
            }else{
               callback(@{@"error":@{@"msg":@"MEDIA_DECODE_ERROR ",@"code":@110060}},nil);
            }
        }];
}

//获取图片的exif . tiff信息
- (NSMutableDictionary *)getExifInfoWithImageData:(NSData *)imageData{
    
    
    CGImageSourceRef cImageSource = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
    NSDictionary *dict =  (NSDictionary *)CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(cImageSource, 0, NULL));
    NSMutableDictionary *dictInfo = [NSMutableDictionary dictionaryWithDictionary:dict];
    return dictInfo;
}

- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser{
    return self.photos.count;
}

- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index{
    
    return self.photos[index];
}

- (NSDictionary *)JPEGmetaData:(UIImage *)image
{
    if (self == nil)
    {
        return nil;
    }
    
    // 转换成jpegData,信息要多一些
    NSData *jpegData              = UIImageJPEGRepresentation(image, 1.0);
    CGImageSourceRef source       = CGImageSourceCreateWithData((__bridge CFDataRef)jpegData, NULL);
    CFDictionaryRef imageMetaData = CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
    CFRelease(source);
    
    NSDictionary *metaDataInfo    = CFBridgingRelease(imageMetaData);
    return metaDataInfo;
}

- (NSDictionary *)PNGmetaData:(UIImage *)image
{
    if (self == nil)
    {
        return nil;
    }
    
    NSData *pngData               = UIImagePNGRepresentation(image);
    CGImageSourceRef source       = CGImageSourceCreateWithData((__bridge CFDataRef)pngData , NULL);
    CFDictionaryRef imageMetaData = CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
    CFRelease(source);
    
    NSDictionary *metaDataInfo    = CFBridgingRelease(imageMetaData);
    return metaDataInfo;
}

- (UIViewController *)getCurrentVC
{
    UIViewController *result = nil;
    
    UIWindow * window = [[UIApplication sharedApplication] keyWindow];
    if (window.windowLevel != UIWindowLevelNormal)
    {
        NSArray *windows = [[UIApplication sharedApplication] windows];
        for(UIWindow * tmpWin in windows)
        {
            if (tmpWin.windowLevel == UIWindowLevelNormal)
            {
                window = tmpWin;
                break;
            }
        }
    }
    
    UIView *frontView = [[window subviews] objectAtIndex:0];
    id nextResponder = [frontView nextResponder];
    
    if ([nextResponder isKindOfClass:[UIViewController class]])
        result = nextResponder;
    else
        result = window.rootViewController;
    
    return result;
}

+ (NSString *)typeForImageData:(NSData *)data{
    
    
    if (!data) return @"";
    uint64_t length = CFDataGetLength((__bridge CFDataRef)data);
    if (length < 16) return @"";
    
    const char *bytes = (char *)CFDataGetBytePtr((__bridge CFDataRef)data);
    
    uint32_t magic4 = *((uint32_t *)bytes);
    switch (magic4) {
            
        case _FOUR_CC(0x00, 0x00, 0x01, 0x00): { // ICO
            return @"ico";
        } break;
            
            
        case _FOUR_CC('G', 'I', 'F', '8'): { // GIF
            return @"gif";
        } break;
            
        case _FOUR_CC(0x89, 'P', 'N', 'G'): {  // PNG
            uint32_t tmp = *((uint32_t *)(bytes + 4));
            if (tmp == _FOUR_CC('\r', '\n', 0x1A, '\n')) {
                return @"png";
            }
        } break;
            
        case _FOUR_CC('R', 'I', 'F', 'F'): { // WebP
            uint32_t tmp = *((uint32_t *)(bytes + 8));
            if (tmp == _FOUR_CC('W', 'E', 'B', 'P')) {
                return @"webp";
            }
        } break;
    }
    
    if (memcmp(bytes,"\377\330\377",3) == 0) return @"jpeg";
    return @"unknow";
    
}

@end
