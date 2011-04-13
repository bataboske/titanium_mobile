/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2011 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "StreamModule.h"
#import "TiStreamProxy.h"
#import "TiBuffer.h"

#ifdef USE_TI_STREAM
@interface StreamModule(Private)
-(void)performInvocation:(NSInvocation*)invocation; // TODO: Move this somewhere common?
-(void)invokeRWOperation:(SEL)operation withArgs:(id)args;
@end

@implementation StreamModule

#pragma mark Internal

// Need this wrapper method to avoid leaking some autorelease objects
-(void)performInvocation:(NSInvocation*)invocation
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    [invocation invoke];
    [pool release];
}

-(void)invokeRWOperation:(SEL)operation withArgs:(id)args
{
    id<TiStreamInternal> stream = nil; // Conform to proxy because we're gonna ship that mother some internal messages
    TiBuffer* buffer = nil;
    id offset = nil; // Spec specifies 'int' but we may do our own type coercion
    id length = nil;
    KrollCallback* callback = nil;
    
    // TODO: Do we throw an exception based on arg typing here?  For now, assume we throw an exception on arg type...
    ENSURE_ARG_AT_INDEX(stream, args, 0, TiStreamProxy); // Conform to class because that's good practice
    ENSURE_ARG_AT_INDEX(buffer, args, 1, TiBuffer);
    
    if ([args count] > 3) {
        ENSURE_ARG_AT_INDEX(offset, args, 2, NSObject);
        ENSURE_ARG_AT_INDEX(length, args, 3, NSObject);
        ENSURE_ARG_AT_INDEX(callback, args, 4, KrollCallback);
    }
    else {
        ENSURE_ARG_AT_INDEX(callback, args, 2, KrollCallback);
    }
    
    int offsetValue = [TiUtils intValue:offset];
    int lengthValue = [TiUtils intValue:length def:[[buffer data] length]];
    
    NSInvocation* invoke = [NSInvocation invocationWithMethodSignature:[stream methodSignatureForSelector:operation]];
    [invoke setTarget:stream];
    [invoke setSelector:operation];
    [invoke setArgument:&buffer atIndex:2];
    [invoke setArgument:&offsetValue atIndex:3];
    [invoke setArgument:&lengthValue atIndex:4];
    [invoke setArgument:&callback atIndex:5];
    [invoke retainArguments];
    
    [self performSelectorInBackground:@selector(performInvocation:) withObject:invoke];
}

#pragma mark Public API : Functions

-(TiStreamProxy*)createStream:(id)args
{
    // TODO: CREATE STREAMS
    return nil;
}

-(void)read:(id)args
{
    [self invokeRWOperation:@selector(readToBuffer:offset:length:callback:) withArgs:args];
}

-(void)write:(id)args
{
    [self invokeRWOperation:@selector(writeFromBuffer:offset:length:callback:) withArgs:args];
}

-(TiBuffer*)readAll:(id)args
{
    id<TiStreamInternal> stream = nil; // Conform to proxy because we're gonna ship that mother some internal messages
    TiBuffer* buffer = nil;
    KrollCallback* callback = nil;
    
    ENSURE_ARG_AT_INDEX(stream, args, 0, TiStreamProxy);
    
    if ([args count] > 1) {
        ENSURE_ARG_AT_INDEX(buffer, args, 1, TiBuffer);
        ENSURE_ARG_AT_INDEX(callback, args, 2, KrollCallback);
    }
    
    if (buffer == nil) {
        buffer = [[[TiBuffer alloc] _initWithPageContext:[self executionContext]] autorelease];
    }
    
    // Handle asynch
    if (callback != nil) {
        SEL operation = @selector(readToBuffer:offset:length:callback:);
        int offset = 0;
        int length = 0;
        
        NSInvocation* invoke = [NSInvocation invocationWithMethodSignature:[stream methodSignatureForSelector:operation]];
        [invoke setTarget:stream];
        [invoke setSelector:operation];
        [invoke setArgument:&buffer atIndex:2];
        [invoke setArgument:&offset atIndex:3];
        [invoke setArgument:&length atIndex:4];
        [invoke setArgument:&callback atIndex:5];
        [invoke retainArguments];
        [self performSelectorInBackground:@selector(performInvocation:) withObject:invoke];
        
        return nil;
    }
    
    [stream readToBuffer:buffer offset:0 length:0 callback:nil];
    return buffer;
}

-(NSNumber*)writeStream:(id)args
{
    id<TiStreamInternal> inputStream = nil;
    id<TiStreamInternal> outputStream = nil;
    id chunkSize = nil;
    KrollCallback* callback = nil;
    
    ENSURE_ARG_AT_INDEX(inputStream, args, 0, TiStreamProxy);
    ENSURE_ARG_AT_INDEX(outputStream, args, 1, TiStreamProxy);
    ENSURE_ARG_AT_INDEX(chunkSize, args, 2, NSObject);
    ENSURE_ARG_OR_NIL_AT_INDEX(callback, args, 3, KrollCallback);

    int size = [TiUtils intValue:chunkSize];
    if (callback != nil) {
        NSInvocation* invoke = [NSInvocation invocationWithMethodSignature:[inputStream methodSignatureForSelector:@selector(writeToStream:chunkSize:callback:)]];
        [invoke setTarget:inputStream];
        [invoke setSelector:@selector(writeToStream:chunkSize:callback:)];
        [invoke setArgument:&outputStream atIndex:2];
        [invoke setArgument:&size atIndex:3];
        [invoke setArgument:&callback atIndex:4];
        [invoke retainArguments];
        [self performSelectorInBackground:@selector(performInvocation:) withObject:invoke];
        
        return nil;
    }
    
    return NUMINT([inputStream writeToStream:outputStream chunkSize:size callback:nil]);
}

-(void)pump:(id)args
{
    id<TiStreamInternal> stream = nil;
    KrollCallback* callback = nil;
    id chunkSize = nil;
    id asynch = nil;
    
    ENSURE_ARG_AT_INDEX(stream, args, 0, TiStreamProxy);
    ENSURE_ARG_AT_INDEX(callback, args, 1, KrollCallback);
    ENSURE_ARG_AT_INDEX(chunkSize, args, 2, NSObject);
    ENSURE_ARG_OR_NIL_AT_INDEX(asynch, args, 3, NSObject);
    
    int size = [TiUtils intValue:chunkSize];

    if ([TiUtils boolValue:asynch def:YES]) {
        NSInvocation* invoke = [NSInvocation invocationWithMethodSignature:[stream methodSignatureForSelector:@selector(pumpToCallback:chunkSize:)]];
        [invoke setTarget:stream];
        [invoke setSelector:@selector(pumpToCallback:chunkSize:)];
        [invoke setArgument:&callback atIndex:2];
        [invoke setArgument:&size atIndex:3];
        [invoke retainArguments];
        
        [self performSelectorInBackground:@selector(performInvocation:) withObject:invoke];
        return;
    }
    
    [stream pumpToCallback:callback chunkSize:size];
}

@end
#endif