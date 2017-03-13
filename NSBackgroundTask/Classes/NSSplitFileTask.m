//
//  NSSplitFileTask.m
//  Pods
//
//  Created by Ricardo Bocchi on 11/03/17.
//
//

#import "NSBackgroundTask.h"

@implementation NSSplitFileTask

    @synthesize delegate;
    
    
- (id) init{
    self = [super init];
    
    _splitFiles = [NSMutableArray array];
    
    return self;
}

-(void) addSplitFile: (NSSplitFile *) splitFile{
    [_splitFiles addObject:splitFile];
}

-(void) runTask{
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        BOOL error = false;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        
        @try {
            
            for (NSSplitFile *splitFile in _splitFiles) {
                
                if(![fileManager fileExistsAtPath: splitFile.fileSrc]){
                    NSLog(@"file %@ not found to split", splitFile.fileSrc);
                    [self.delegate onError: [NSString stringWithFormat: @"file %@ not found to split", splitFile.fileSrc]];
                    error = true;
                    break;
                }
                
                NSData *data = [fileManager contentsAtPath: splitFile.fileSrc];
                
                int mb = 1048576;
                int kb = 1024 * 4;
                int partSize = mb * splitFile.filePartMaxSize;
                int partCount = [data length] / partSize;
                int endPartSize = [data length] % partSize;
                
                if(endPartSize > 0){
                    partCount++;
                }else{
                    endPartSize = partSize;
                }
                
                NSLog(@"data len %d", [data length]);
                NSLog(@"parts count %d", partCount);
                
                splitFile.filePartCount = partCount;
                
                for (int i = 0; i < partCount; i++) {
                    NSData *part = [data subdataWithRange:NSMakeRange(i * partSize, endPartSize)];
                    
                    if(![splitFile.filePathPath hasSuffix:@"/"]){
                        splitFile.filePathPath = [splitFile.filePathPath stringByAppendingString:@"/"];
                    }
                    
                    NSString *count = [NSString stringWithFormat:@"%d", i + 1];
                    NSString *partPathName = [NSString stringWithFormat:@"%@%@_%@.%@", splitFile.filePathPath, splitFile.filePartName, count, splitFile.filePartSufix];
                    
                    NSLog(@"save part file at %@", partPathName);
                    
                    if([fileManager fileExistsAtPath:partPathName]){
                        NSError *deleteError;
                        [fileManager removeItemAtPath:partPathName error:&deleteError];
                        
                        if(deleteError){
                            NSLog(@"error on delete file %@ -> %@", partPathName, deleteError);
                            [self.delegate onError: [deleteError description]];
                            error = true;
                            break;
                        }
                    }
                    
                    [part writeToFile:partPathName atomically:true];
                    
                    [splitFile.fileParts addObject: partPathName];
                }
            }
            
            if(!error)
                [self.delegate onComplete: _splitFiles];
            
        } @catch (NSException *exception) {
            NSLog(@"split file error %@", exception);
            [self.delegate onError: [exception reason]];
        }
        
    });
}

    
@end
