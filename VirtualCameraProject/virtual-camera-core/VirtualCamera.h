#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreGraphics/CoreGraphics.h>
void VCSubmitImage(CGImageRef image);
void VCInvalidateStream(void);
void VCSetEnabled(BOOL enabled);
void VCSetFreeze(BOOL freeze);
CMSampleBufferRef VCCopyReplacement(CMSampleBufferRef original) CF_RETURNS_RETAINED;
BOOL VCWasSubstituted(CMSampleBufferRef sample);
NSString *VCStatus(void);
void VCInstallHook(void);
