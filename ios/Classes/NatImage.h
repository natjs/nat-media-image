//
//  NatImage.h
//
//  Created by huangyake on 17/1/7.
//  Copyright © 2017 Instapp. All rights reserved.
//


#import <Foundation/Foundation.h>
#import "MWPhotoBrowser.h"


@interface NatImage : NSObject<MWPhotoBrowserDelegate>
typedef void (^NatCallback)(id error, id result);
+ (NatImage *)singletonManger;
//图片选择器 参数 :
//      limit     图片张数  默认为9
//      quality   图片质量
//      width     宽
//      height    高
// 返回值 @{@"path":@"图片路径"}
- (void)pick:(NSDictionary *)params :(NatCallback)callback;

//图片浏览器  参数 :
//      files     图片路径数组
//      params   : {
//      current   默认第几张
//      style   String (dots | label | none, def: dots)
//      }
- (void)preview:(NSArray *)files :(NSDictionary *)params :(NatCallback)callback;

//获取图片宽高  图片格式
- (void)info:(NSString *)path :(NatCallback)callback;
//获取图片的exif信息  
- (void)exif:(NSString *)path :(NatCallback)callback;

@end
