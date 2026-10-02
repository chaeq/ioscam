#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import "VirtualCamera.h"
@interface VCDelegateProxy : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property(nonatomic,weak) id<AVCaptureVideoDataOutputSampleBufferDelegate> target;
@end
@implementation VCDelegateProxy
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sample fromConnection:(AVCaptureConnection *)connection {
    id<AVCaptureVideoDataOutputSampleBufferDelegate> target=self.target;
    if (![target respondsToSelector:_cmd]) return;
    CMSampleBufferRef replacement=VCCopyReplacement(sample);
    [target captureOutput:output didOutputSampleBuffer:replacement?:sample fromConnection:connection];
    if (replacement) CFRelease(replacement);
}
- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sample fromConnection:(AVCaptureConnection *)connection {
    id<AVCaptureVideoDataOutputSampleBufferDelegate> target=self.target;
    if ([target respondsToSelector:_cmd]) [target captureOutput:output didDropSampleBuffer:sample fromConnection:connection];
}
@end
static char proxyKey;
@interface AVCaptureVideoDataOutput (VCHook)
- (void)vc_setDelegate:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)delegate queue:(dispatch_queue_t)queue;
@end
@implementation AVCaptureVideoDataOutput (VCHook)
- (void)vc_setDelegate:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)delegate queue:(dispatch_queue_t)queue {
    if (!delegate) {
        [self vc_setDelegate:nil queue:queue];
        objc_setAssociatedObject(self,&proxyKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); return;
    }
    VCDelegateProxy *proxy=[VCDelegateProxy new]; proxy.target=delegate;
    [self vc_setDelegate:proxy queue:queue];
    objc_setAssociatedObject(self,&proxyKey,proxy,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSLog(@"[VCAM] Intercepted delegate registration: %@",NSStringFromClass([delegate class]));
}
@end
void VCInstallHook(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Method original=class_getInstanceMethod(AVCaptureVideoDataOutput.class,@selector(setSampleBufferDelegate:queue:));
        Method replacement=class_getInstanceMethod(AVCaptureVideoDataOutput.class,@selector(vc_setDelegate:queue:));
        if (original && replacement) { method_exchangeImplementations(original,replacement); NSLog(@"[VCAM] Hook installed"); }
    });
}
