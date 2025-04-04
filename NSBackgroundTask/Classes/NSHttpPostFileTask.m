
#import "NSBackgroundTask.h"
#import "AFNetworking.h"
#import "GZIP.h"


@implementation NSHttpPostFileTask

@synthesize delegate;

-(id) initWithUrl: (NSString *) url{
    self = [super init];
    _url = url;
    _httpHeaders = [NSMutableDictionary dictionary];
    _postFiles = [NSMutableArray array];
    return self;
}

-(void) setUseGzip:(BOOL) useGzip{
    _userGzip = useGzip;
}

-(void) setDebug:(BOOL)debug{
    _debug = debug;
}

-(void) setUseFormData:(BOOL) useFormData{
    _useFormData = useFormData;
}

-(void) addPostFile: (NSHttpPostFile *) postFile{
    [_postFiles addObject: postFile];
}

-(void) addHeaderWithName: (NSString *) name andValue: (NSString *) value{
    [_httpHeaders setValue:value forKey:name];
}

-(void) runTask{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        if(_debug)
            NSLog(@"post files started  ");

        // NSURLRequest *request = [NSURLRequest requestWithURL:url];
        
        if(_debug)
            NSLog(@"post data url %@. files to sent %d", _url, [_postFiles count]);
        
        _index = -1;
        [self next];
        
    });
}

-(void) next{
    if(++_index >= [_postFiles count]){
        if(_debug)
            NSLog(@"post files finished");
        [self.delegate onComplete:_postFiles];
        return;
    }
    
    if(_debug)
        NSLog(@"post file index %d", _index);
    
    NSHttpPostFile *postFile = [_postFiles objectAtIndex:_index];
    
    [self post:postFile];
}

-(void) post:(NSHttpPostFile *) postFile{

    @try {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@", _url]];
        
        if(![fileManager fileExistsAtPath: postFile.fileSrc  ]){
            NSLog(@"file %@ not found to post", postFile.fileSrc);
            [self.delegate onError: [NSString stringWithFormat:@"file %@ not found to post", postFile.fileSrc]];
            return;
        }
        
        NSData *data = [NSData dataWithContentsOfFile:postFile.fileSrc];
        
        if(_userGzip){
            NSLog(@"applay gzip on data");
            data = [data gzippedData];
        }else{
            NSLog(@"not applay gzip on data");
        }
        
        NSString *base64Encoded = [data base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
        base64Encoded = [base64Encoded stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"];
        
        [postFile.json setObject:base64Encoded forKey:postFile.jsonKey];
        
        NSString *post = @"";
        
        if(_useFormData){
            for(NSString *key in postFile.json){
                post = [NSString stringWithFormat:@"%@%@=%@&", post, key, [postFile.json objectForKey:key]];
            }
        }else{
            NSError *error;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:postFile.json
                                                               options:NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
                                                                 error:&error];
            
            if (!jsonData) {
                NSLog(@"error create json: %@", error);
                [self.delegate onError: [NSString stringWithFormat:@"error create json %@", error]];
                return;
            } else {
                post = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            }
            
        }
        
        
        NSData *postData =  [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
        NSString *postLength = [NSString stringWithFormat:@"%d", [postData length]];
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        [request setURL: url];
        [request setHTTPMethod:@"POST"];
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        
        for (NSString *key in _httpHeaders) {
            [request setValue:[_httpHeaders objectForKey:key] forHTTPHeaderField:key];
        }
        
        [request setHTTPBody:postData];
        
        NSLog(@"run post data");
        
        NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        
        
        [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *r, NSError *error) {
            
            
            @try {
                NSString *requestReply = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
                
                NSHTTPURLResponse *response = (NSHTTPURLResponse *) r;
                
                if(_debug)
                    NSLog(@"request status: %d, result: %@", response.statusCode, requestReply);
                else
                    NSLog(@"request status: %d", response.statusCode);
                
                if(error){
                    [self.delegate onError:[NSString stringWithFormat:@" request error: %@", error]];
                    return;
                }
                
                for(NSString *name in response.allHeaderFields){
                    [postFile.responseHeaders setObject:name forKey:[response.allHeaderFields objectForKey: name]];
                }
                
                postFile.result = requestReply;
                
                
                if(response.statusCode != 200){
                    
                    NSString *reason = [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode];
                    NSRestException *rest = [[NSRestException alloc] initWithName:@"NSRestException" reason:reason userInfo:nil];
                    rest.statusCode = response.statusCode;
                    rest.content = requestReply;
                    rest.message = reason;
                    
                    [self.delegate onError: rest];
                    return;
                }
                
                [self next];
                
            } @catch (NSException *exception) {
                [self.delegate onError: [exception reason]];
            }
            
            
        }] resume];
        
        [postFile.json removeObjectForKey:postFile.jsonKey];

    } @catch (NSException *exception) {
        [self.delegate onError: [exception reason]];
    }
}

@end
