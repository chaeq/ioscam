#import "VirtualCamera.h"
#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/QuartzCore.h>
// Controlled test format only. Convert on the network queue, not capture queue.
static NSObject *FrameLock(void) {
    static NSObject *lock; static dispatch_once_t once;
    dispatch_once(&once, ^{ lock = [NSObject new]; }); return lock;
}
static CVPixelBufferRef latest;
static CFTimeInterval arrival;
static BOOL enabled, freezeLast, available;
static NSUInteger supplied, mismatched;
void VCSetEnabled(BOOL value) { @synchronized(FrameLock()) { enabled = value; } }
void VCSetFreeze(BOOL value) { @synchronized(FrameLock()) { freezeLast = value; } }
void VCInvalidateStream(void) { @synchronized(FrameLock()) { available = NO; } }
void VCSubmitImage(CGImageRef image) {
    CVPixelBufferRef pixel = NULL;
    NSDictionary *attrs = @{(id)kCVPixelBufferCGImageCompatibilityKey:@YES,
        (id)kCVPixelBufferCGBitmapContextCompatibilityKey:@YES};
    if (CVPixelBufferCreate(kCFAllocatorDefault,720,1280,kCVPixelFormatType_32BGRA,(__bridge CFDictionaryRef)attrs,&pixel)) return;
    CVPixelBufferLockBaseAddress(pixel,0);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(CVPixelBufferGetBaseAddress(pixel),720,1280,8,
        CVPixelBufferGetBytesPerRow(pixel),space,kCGBitmapByteOrder32Little|kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(space);
    if (!context) { CVPixelBufferUnlockBaseAddress(pixel,0); CVPixelBufferRelease(pixel); return; }
    CGContextSetRGBFillColor(context,0,0,0,1); CGContextFillRect(context,CGRectMake(0,0,720,1280));
    CGFloat scale=MIN(720.0/CGImageGetWidth(image),1280.0/CGImageGetHeight(image));
    CGFloat w=CGImageGetWidth(image)*scale,h=CGImageGetHeight(image)*scale;
    CGContextDrawImage(context,CGRectMake((720-w)/2,(1280-h)/2,w,h),image);
    CGContextRelease(context); CVPixelBufferUnlockBaseAddress(pixel,0);
    @synchronized(FrameLock()) {
        if (latest) CVPixelBufferRelease(latest);
        latest=pixel; arrival=CACurrentMediaTime(); available=YES;
    }
}
CMSampleBufferRef VCCopyReplacement(CMSampleBufferRef original) {
    CVPixelBufferRef pixel=NULL;
    @synchronized(FrameLock()) {
        if (!enabled || !latest || (!(available && CACurrentMediaTime()-arrival<2) && !freezeLast)) return NULL;
        CVPixelBufferRef real=CMSampleBufferGetImageBuffer(original);
        if (!real || CVPixelBufferGetWidth(real)!=720 || CVPixelBufferGetHeight(real)!=1280 ||
            CVPixelBufferGetPixelFormatType(real)!=kCVPixelFormatType_32BGRA) { mismatched++; return NULL; }
        pixel=CVPixelBufferRetain(latest);
    }
    CMVideoFormatDescriptionRef format=NULL; CMSampleBufferRef result=NULL;
    CMSampleTimingInfo timing={CMSampleBufferGetDuration(original),CMSampleBufferGetPresentationTimeStamp(original),kCMTimeInvalid};
    OSStatus error=CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault,pixel,&format);
    if (!error) {
        error=CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault,pixel,format,&timing,&result);
        CFRelease(format);
    }
    CVPixelBufferRelease(pixel); if (error) return NULL;
    CMSetAttachment(result,CFSTR("VCAM.Substituted"),kCFBooleanTrue,kCMAttachmentMode_ShouldNotPropagate);
    @synchronized(FrameLock()) { supplied++; } return result;
}
BOOL VCWasSubstituted(CMSampleBufferRef sample) { return CMGetAttachment(sample,CFSTR("VCAM.Substituted"),NULL)==kCFBooleanTrue; }
NSString *VCStatus(void) {
    @synchronized(FrameLock()) {
        return [NSString stringWithFormat:@"Hook %@ | supplied %lu | format rejects %lu | %@", enabled?@"ON":@"OFF",
            (unsigned long)supplied,(unsigned long)mismatched,available && CACurrentMediaTime()-arrival<2?@"PC fresh":@"PC stale"];
    }
}
