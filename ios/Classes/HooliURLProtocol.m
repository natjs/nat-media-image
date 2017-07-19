//
//  HooliURLProtocol.m
//
//  Created by huangyake on 17/1/7.
//  Copyright © 2017 Instapp. All rights reserved.
//

#import "HooliURLProtocol.h"
#import <Photos/Photos.h>
#import <AssetsLibrary/AssetsLibrary.h>

static NSString * const URLProtocolHandledKey = @"URLProtocolHandledKey";

@interface HooliURLProtocol ()


@end

@implementation HooliURLProtocol

#define _FOUR_CC(c1,c2,c3,c4) ((uint32_t)(((c4) << 24) | ((c3) << 16) | ((c2) << 8) | (c1)))
#define _TWO_CC(c1,c2) ((uint16_t)(((c2) << 8) | (c1)))


+(BOOL)canInitWithRequest:(NSURLRequest *)request{
//    NSURL* theUrl = [request URL];
    
    NSString *scheme = [[request URL] scheme];
    if ( ([scheme caseInsensitiveCompare:@"http"] == NSOrderedSame ||
          [scheme caseInsensitiveCompare:@"https"] == NSOrderedSame))
    {
        return NO;
        //看看是否已经处理过了，防止无限循环
        
    }else if(([scheme caseInsensitiveCompare:@"nat"] == NSOrderedSame)){
        if ([NSURLProtocol propertyForKey:URLProtocolHandledKey inRequest:request]) {
            return NO;
        }
        
        
        
        return YES;
    }
    return NO;

}

//通常该方法你可以简单的直接返回request，但也可以在这里修改request，比如添加header，修改host等，并返回一个新的request，这是一个抽象方法，子类必须实现。
+ (NSURLRequest *) canonicalRequestForRequest:(NSURLRequest *)request {
//    NSMutableURLRequest *mutableReqeust = [request mutableCopy];
//    mutableReqeust = [self redirectHostInRequset:mutableReqeust];
    return request;
}


- (NSHTTPURLResponse *)getResponse:(NSData *)data type:(NSString *)type{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"";

    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[self.request URL] statusCode:200 HTTPVersion:@"1.1" headerFields:@{@"Connection":@"keep-alive",@"Content-Length":[NSString stringWithFormat:@"%lld",(long long)data.length],@"Content-Transfer-Encoding":@"binary",@"Content-Type":type,@"Server":@"Nat"}];
    NSLog(@"%@",response);
    return response;
    
}


- (NSHTTPURLResponse *)getaudioResponse:(NSData *)data type:(NSString *)type start:(NSString *)start end:(NSString *)end length:(NSString *)length statusCode:(NSInteger)statusCode{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"";
    NSLog(@"%@",[self.request allHTTPHeaderFields]);
    
    if (!start) {
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[self.request URL] statusCode:statusCode HTTPVersion:@"1.1" headerFields:@{@"Content-Length":[NSString stringWithFormat:@"%lld",(long long)data.length],@"Content-Transfer-Encoding":@"binary",@"Content-Type":type,@"Accept-Range":@"bytes",@"Access-Control-Allow-Origin":@"*",@"Access-Control-Max-Age":@"2592000",@"Cache-Control":@"public, max-age=31536000",@"Content-Disposition":@"inline; filename=\"asset\"",@"Server":@"Nat",@"Proxy-Connection":@"Keep-alive"}];
        NSLog(@"%@",response);
        return response;
    }else{
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[self.request URL] statusCode:statusCode HTTPVersion:@"1.1" headerFields:@{@"Content-Length":length,@"Content-Transfer-Encoding":@"binary",@"Content-Type":type,@"Content-Range":[NSString stringWithFormat:@"bytes %@-%@/%lld",start,end,(long long)data.length],@"Accept-Range":@"bytes",@"Access-Control-Allow-Origin":@"*",@"Access-Control-Max-Age":@"2592000",@"Cache-Control":@"public, max-age=31536000",@"Content-Disposition":@"inline; filename=\"asset\"",@"Server":@"Nat",@"Proxy-Connection":@"Keep-alive"}];
        NSLog(@"%@",response);
        return response;
 
    }
    
    
}


- (void)startLoading
{
//    NSMutableURLRequest *mutableReqeust = [[self request] mutableCopy];
//    //标示改request已经处理过了，防止无限循环
//    [NSURLProtocol setProperty:@YES forKey:URLProtocolHandledKey inRequest:mutableReqeust];
//    self.connection = [NSURLConnection connectionWithRequest:mutableReqeust delegate:self];
//    NSData *data;
//    NSString *mimeType;
//    NSString *encoding;
    
    NSString *urlStrong = [[self.request URL] absoluteString];
    BOOL isImage = NO, isAudio = NO, isVideo = NO;
    
    if ([urlStrong hasPrefix:@"nat://static/image"]) {
        isImage = YES;
    }
    
    if ([urlStrong hasPrefix:@"nat://static/audio"]) {
        isAudio = YES;
    }
    
    if ([urlStrong hasPrefix:@"nat://static/video"]) {
        isVideo = YES;
    }
    
    
    if (isImage) {
        if ([[UIDevice currentDevice].systemVersion floatValue] >= 8)
        {
            NSString *str = [[self.request URL] absoluteString];
            str = [str substringFromIndex:19];
            PHFetchResult *result = [PHAsset fetchAssetsWithLocalIdentifiers:@[str] options:nil];
            [[PHImageManager defaultManager] requestImageDataForAsset:result.firstObject options:nil resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
                
                    [self.client URLProtocol:self didReceiveResponse:[self getResponse:imageData type:[NSString stringWithFormat:@"image/%@",[HooliURLProtocol typeForImageData:imageData]]] cacheStoragePolicy:NSURLCacheStorageNotAllowed];
                    [self.client URLProtocol:self didLoadData:imageData];
                    [self.client URLProtocolDidFinishLoading:self];

            }];
            
            
            
        }else{
            NSString *str = [[self.request URL] absoluteString];
            str = [str substringFromIndex:19];
            str = [@"assets-library://" stringByAppendingString:str];
            __block ALAssetsLibrary *lib = [[ALAssetsLibrary alloc] init];
            [lib assetForURL:[NSURL URLWithString:str] resultBlock:^(ALAsset *asset) {
                
                ALAssetRepresentation *rep = [asset defaultRepresentation];
                Byte *buffer = (Byte*)malloc((unsigned long)rep.size);
                NSUInteger buffered = [rep getBytes:buffer fromOffset:0.0 length:((unsigned long)rep.size) error:nil];
                NSData *data = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
                // UI的更新记得放在主线程,要不然等子线程排队过来都不知道什么年代了,会很慢的
                [self.client URLProtocol:self didReceiveResponse:[self getResponse:data type:[NSString stringWithFormat:@"image/%@",[HooliURLProtocol typeForImageData:data]]] cacheStoragePolicy:NSURLCacheStorageNotAllowed];
//
                [self.client URLProtocol:self didLoadData:data];
                [self.client URLProtocolDidFinishLoading:self];
            } failureBlock:^(NSError *error) {
                [self.client URLProtocol:self didFailWithError:error];
            }];
        }

    }else if (isVideo || isAudio){
        NSString *str = [[self.request URL] absoluteString];
        str = [str substringFromIndex:19];
        NSData *data = [NSData dataWithContentsOfFile:str];
        NSString *range = [self.request.allHTTPHeaderFields valueForKey:@"Range"];
        NSInteger statusCode = 206;
         NSArray *arr= [HooliURLProtocol stringWithRangeString:range];
//
        NSUInteger start = [arr.firstObject unsignedIntegerValue];
        NSUInteger end = [arr.lastObject unsignedIntegerValue];
        NSFileHandle* file = [NSFileHandle fileHandleForReadingAtPath:str];
        if (start > 0) {
            [file seekToFileOffset:start];
        }
        
        NSData* readData;
//        if (end < 0) {
//            readData = [file readDataToEndOfFile];
//        } else {
            readData = [file readDataOfLength:(end - start)];
//        }
        [file closeFile];
//        NSLog(@"readData --- %ld-------",readData.length);
        
        
       
        NSString *length;
        if (range) {
            long long len = end-start;
            length = [NSString stringWithFormat:@"%lld",len+1];
            

        }else{
           statusCode = 200;
        }
//        NSError *error;
        if (isAudio) {
            [self.client URLProtocol:self didReceiveResponse:[self getaudioResponse:data type:@"audio/aac" start:arr.firstObject end:arr.lastObject length:length statusCode:statusCode] cacheStoragePolicy:NSURLCacheStorageAllowed];
//            [self.client URLProtocol:self didFailWithError:error];
            [self.client URLProtocol:self didLoadData:readData];
            [self.client URLProtocolDidFinishLoading:self];

        }else{
            
            [self.client URLProtocol:self didReceiveResponse:[self getaudioResponse:data type:@"video/mov" start:arr.firstObject end:arr.lastObject length:length statusCode:statusCode] cacheStoragePolicy:NSURLCacheStorageAllowed];
//            [self.client URLProtocol:self didFailWithError:error];
            [self.client URLProtocol:self didLoadData:readData];
            [self.client URLProtocolDidFinishLoading:self];

        }

    }


    

}
- (void)stopLoading
{
    
//     [self.connection cancel];
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

+ (NSArray *)stringWithRangeString:(NSString *)str
{
    if (!str.length )
    {
        return nil;
    }
    NSMutableArray *resultArr= [NSMutableArray arrayWithCapacity:0];
    NSString *pattern = @"bytes=(\\d*)-(\\d*)";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    NSArray *matches = [regex matchesInString:str options:0 range:NSMakeRange(0, str.length)];
    
    if (matches) {
        NSTextCheckingResult* match = matches.firstObject;
        NSString *start = [str substringWithRange:[match rangeAtIndex:1]];
        NSString *end = [str substringWithRange:[match rangeAtIndex:2]];
        [resultArr addObject:start];
        [resultArr addObject:end];
        
    }
    return resultArr;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b
{
    return [super requestIsCacheEquivalent:a toRequest:b];
}
@end
