//
//  SCSICmd.h
//  GL3310UpdateFWTool
//
//  Created by CHIEN NICK on 2011/3/8.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Define.h"
#import <string.h>

#define MAX_DEVICE		8

#define HIBYTE(PARAM)	(UInt8)(PARAM >> 8)
#define LOBYTE(PARAM)   (UInt8)PARAM

@interface SCSICmd : NSObject {
	//define member variable
	UInt8						DeviceIOControl;
	io_registry_entry_t			parent[MAX_DEVICE];
	char						g_szSPIType[64]; //for check SPI Flash type
	DRIVE_INFO_COMMON			m_DriveInfo[MAX_DEVICE];
}


//define member function
-(io_registry_entry_t)parent:(int)iLun;
-(DRIVE_INFO_COMMON)m_DriveInfo:(int)iLun;
-(int)UstorCreateDeviceList:(UInt16)VID PID:(UInt16)PID;
-(BOOL)DetectAndInitDev:(UInt16)VID PID:(UInt16)PID iLun:(int)iLun;
-(BOOL)SendInquiry:(INQUIRY_DATA*)pInquiryData iLun:(int)iLun;

-(BOOL)UstorVendorScsiCmd:(SCSICMDBLK)CmdBulk iLun:(int)iLun;
-(BOOL)UstorWriteExternalFlash:(UInt32)StartAddress LengthTotal:(UInt32)LengthTotal Data:(UInt8 *)Data LengthForOneTime:(UInt32)LengthForOneTime iLun:(int)iLun;
-(BOOL)UstorReadExternalFlash:(UInt32)StartAddress LengthTotal:(UInt32)LengthTotal Data:(UInt8 *)Data LengthForOneTime:(UInt32)LengthForOneTime iLun:(int)iLun;
//for EEP
-(BOOL)UstorWriteEEPDataToExternalFlash:(UInt8 *)Data LengthTotal:(UInt32)LengthTotal LengthForOneTime:(UInt32)LengthForOneTime iLun:(int)iLun;
-(BOOL)UstorReadEEPDataFromExternalFlash:(UInt8 *)Data LengthTotal:(UInt32)LengthTotal LengthForOneTime:(UInt32)LengthForOneTime iLun:(int)iLun;
-(BOOL)UstorConvertConfigToRawData:(FROM_EEP *)FromEEP RawData:(UInt16 *)pBuffer iLun:(int)iLun;
-(BOOL)UstorConvertRawDataToConfig:(FROM_EEP *)FromEEP RawData:(UInt16 *)pBuffer iLun:(int)iLun;
-(BOOL)UstorCombineBinAndEepFile:(UInt8 *)pBufferBin BufferEep:(UInt8 *)pBufferEep iLun:(int)iLun;


-(BOOL)RegistryGetData:(char *)buf Length:(UInt32)Length KeyName:(CFStringRef)KeyName iLun:(int)iLun;
-(BOOL)GetMediaType:(int)MediaSupport iLun:(int)iLun Data:(UInt8 *)Data;
-(BOOL)GetMediaInfo:(int)iLun Data:(UInt8)Data MediaInfo:(UInt8 *)pInfo;

-(BOOL)CheckFlashTypeAndSendCommand:(int)nType szPath:(char *)szPath iLun:(int)iLun;
-(BOOL)SendVendorForSpiFlash:(int)nFlashType nType:(int)nType szPath:(char *)szPath iLun:(int)iLun;
-(int)GetConfigData:(char *)szData nLen:(int)nLen DataBuf:(UInt8 *)bDataBuf;
-(int)GetConfigDataAndLength:(char *)szData nLen:(int)nLen DataBuf:(UInt8 *)bDataBuf;
-(char *)strlwr:(char *)szSource nLen:(int)nLen;




@end
