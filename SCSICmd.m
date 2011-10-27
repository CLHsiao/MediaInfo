//
//  SCSICmd.m
//  GL3310UpdateFWTool
//
//  Created by CHIEN NICK on 2011/3/8.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "SCSICmd.h"


@implementation SCSICmd

-(id)init
{
	NSLog(@"+++++Enter init");
	DeviceIOControl = 0;
	
	NSLog(@"-----Leave init");
	if(![super init])
		return nil;
	else
		return self;
	
}

-(void)dealloc
{
	NSLog(@"+++++Enter dealloc%@", self);	
	[super dealloc];
	NSLog(@"-----Leave dealloc%@", self);
}


-(io_registry_entry_t)parent:(int)iLun;
{
	return parent[iLun];
}

-(DRIVE_INFO_COMMON)m_DriveInfo:(int)iLun
{
	return m_DriveInfo[iLun];
}

-(int)UstorCreateDeviceList:(UInt16)VID PID:(UInt16)PID
{
	
	NSLog(@"+++++Enter UstorCreateDeviceList");
	
	int nRet = 0;
	io_iterator_t		iter;  //should be release by the caller when the iteration is finished
	io_service_t		service; //should be release by the caller
	kern_return_t		kr;
	CFMutableDictionaryRef      DictRef;
	
	memset(m_DriveInfo, 0,  sizeof(DRIVE_INFO_COMMON)*MAX_DEVICE);
	int	iLun = 0;
	
	DictRef = nil;
	
	for (iLun = 0; iLun < MAX_DEVICE ; iLun++) parent[iLun] = 0;
	iLun = 0;
	
	// The bulk of this code locates all instances of our driver running on the system.
	
	// First find all children of our driver. As opposed to nubs, drivers are often not registered
	// via the registerServices call because nothing is expected to match to them. Unregistered
	// objects in the I/O Registry are not returned by IOServiceGetMatchingServices.
	
	// IOBlockStorageServices is our child in the I/O Registry
	DictRef = IOServiceMatching("IOBlockStorageServices");
	if(!DictRef)
	{
		NSLog(@"IOServiceMatching return NULL.\n");
		goto _err;
	}
	
	// Create an iterator over all matching IOService nubs.
	// This consumes a reference on dictRef.
	kr = IOServiceGetMatchingServices(kIOMasterPortDefault, DictRef, &iter);
	if(kr != KERN_SUCCESS)
	{
		NSLog(@"IOServiceMachingServices return 0x%08x\n", kr);
		goto _err;
	}
		
	// Iterate across all instances of IOBlockStorageServices
	while ((service = IOIteratorNext(iter)))
	{
		kr = IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent[iLun]);
		
		if (kr != KERN_SUCCESS)
		{
			NSLog(@"IORegistryEntryGetParentEntry return 0x%08x\n", kr);
			goto _err;
		}
		else
		{
			if (IOObjectConformsTo(parent[iLun], "com_GenesysLogic_driver_GLLUD"))
			{
				if([self DetectAndInitDev:VID PID:PID iLun:iLun])
				{
					iLun++;
				}
				else
				{
					IOObjectRelease(parent[iLun]);
				}
				//iLun++;
				
				if (iLun == MAX_DEVICE)
				{
					IOObjectRelease(service);
					nRet = iLun;
					break;
				}
				
				nRet = iLun;
			}
		}

		IOObjectRelease(service);
	}
	
_err:
	if(iter != IO_OBJECT_NULL)
	{
		IOObjectRelease(iter);
		iter = IO_OBJECT_NULL;
	}
	
	NSLog(@"-----Leave UstorCreateDeviceList");
	
	return nRet;
}


-(BOOL)DetectAndInitDev:(UInt16)VID PID:(UInt16)PID iLun:(int)iLun
{
	BOOL bRet = false;
	UInt16 InqVID = 0, InqPID = 0;
	INQUIRY_DATA InquiryData = {0};
	bRet = [self SendInquiry:&InquiryData iLun:iLun];
	if(!bRet)
		goto _err;
	
	if(memcmp(InquiryData.GeneId, "GENE", 4) != 0)
	{
		bRet = false;
		goto _err;
	}
	
	InqVID = ((InquiryData.USBVID[0] << 8) & 0xFF00) + InquiryData.USBVID[1];
	InqPID = ((InquiryData.USBPID[0] << 8) & 0xFF00) + InquiryData.USBPID[1];
	NSLog(@"DetectAndInitDev-- VID = 0x%04X, PID = 0x%04X\n", InqVID, InqPID);
	if(VID == 0 && PID == 0)
	{
		m_DriveInfo[iLun].InquiryData = InquiryData;
	}
	else
	{
		if(InqVID == VID && InqPID == PID)
		{
			//m_DriveInfo[iLun].InquiryData = InquiryData;
			memcpy(&(m_DriveInfo[iLun].InquiryData), &InquiryData, sizeof(INQUIRY_DATA));
		}
		else
		{
			bRet = false;
			goto _err;
		}
	}

_err:
	return bRet;
}

-(BOOL)SendInquiry:(INQUIRY_DATA *)pInquiryData iLun:(int)iLun
{
	BOOL bRet = true;
	int nLen = 0x2e;
	char buf[512] ={0};
	SCSICMDBLK CmdBlk ={0};
	
	CmdBlk.CdbLength		= 6;
	CmdBlk.Direction		= SCSI_DATA_IN;
	CmdBlk.TransferLength   = nLen;
	CmdBlk.ReturnBytes		= nLen;
	
	CmdBlk.Cdb[0] = 0x12;
	CmdBlk.Cdb[3] = 0x55;
	CmdBlk.Cdb[4] = nLen;
	
	bRet = [self UstorVendorScsiCmd:CmdBlk iLun:iLun];
	
	if(bRet)
	{
		bRet = [self RegistryGetData:(char *)buf Length:nLen KeyName:CFSTR(kMyPropertyKey) iLun:iLun];
		//if(bRet)
		//	NSLog(@"%02X %02X %02X %02X %02X %02X %02X %02X", buf[0], buf[1], buf[2],buf[3],buf[4],buf[5],buf[6],buf[7]);
		memcpy(pInquiryData, buf, nLen);
	}
	
	return bRet;
}




-(BOOL)UstorVendorScsiCmd:(SCSICMDBLK)CmdBlk iLun:(int)iLun
{
	//NSLog(@"+++++Enter UstorVendorScsiCmd.\n");
	int i = 0;
	char szMsg[256]={0};
	BOOL bRet = true;
	kern_return_t	kr;
	
	CFMutableDictionaryRef      DictRef;
	//create mutable dictionary for SCSICMDBLK
	CFDataRef	DataRef; //must release by caller
	DictRef = CFDictionaryCreateMutable(kCFAllocatorDefault, 
										0,
										&kCFTypeDictionaryKeyCallBacks,
										&kCFTypeDictionaryValueCallBacks);
	if(DictRef == NULL)
	{
		//CFRelease(DataRef);
		//return false;
		bRet = false;
		goto _err;
	}
	
	for(i = 0 ; i < CmdBlk.CdbLength ; i++)
	{
		sprintf(szMsg, "%s%02X", szMsg,CmdBlk.Cdb[i]);
		if(i != CmdBlk.CdbLength - 1)
			sprintf(szMsg, "%s ", szMsg);
	}
	//NSLog(@"%s", szMsg);
	//SCSICMDBLK CMD ={0};
	//NSLog(@"CDB Length = %d", CmdBlk.CdbLength);
	//NSLog(@"Transfer Length = %d", CmdBlk.TransferLength);
	//NSLog(@"%02X %02X %02X %02X %02X %02X", CmdBlk.Cdb[0], CmdBlk.Cdb[1], CmdBlk.Cdb[2], CmdBlk.Cdb[3], CmdBlk.Cdb[4], CmdBlk.Cdb[5]);
	//NSLog(@"%02X %02X %02X %02X %02X %02X", CmdBlk.DataBuffer[0], CmdBlk.DataBuffer[1], CmdBlk.DataBuffer[2], CmdBlk.DataBuffer[3], CmdBlk.DataBuffer[4], CmdBlk.DataBuffer[5]);
	DataRef = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, 
										  (UInt8 *)(&CmdBlk), 
										  sizeof(SCSICMDBLK), 
										  kCFAllocatorNull);
	
	if(DataRef == NULL)
	{
		bRet = false;
		goto _err;
	}
	
	CFDictionarySetValue(DictRef,
						 CFSTR(kMyPropertyKey),
						 DataRef);
	
	
	
	
	// This is the function that results in ::setProperties() being called in our
	// kernel driver. The dictionary we created is passed to the driver here.
	
	// BOOK Test
	
//	kr = IORegistryEntrySetCFProperties(parent, DictRef);
	kr = IORegistryEntrySetCFProperties(parent[iLun], DictRef);

	// BOOK Test
	
	if(kr != KERN_SUCCESS)
	{
		NSLog(@"Issue Vendor SCSI command fail\n");
		bRet = false;
	}

_err:
	CFRelease(DataRef);
	//if(DictRef!=nil)
	//	CFRelease(DictRef);
	//NSLog(@"-----Leave UstorVendorScsiCmd.\n");
	return bRet;
}

-(BOOL)UstorWriteExternalFlash:(UInt32)StartAddress LengthTotal:(UInt32)LengthTotal Data:(UInt8 *)Data LengthForOneTime:(UInt32)LengthForOneTime iLun:(int)iLun
{
	BOOL bRet = true;
	UInt32 DataIndex;
	UInt32 Address;
	int LengthRemain;
	SCSICMDBLK CmdBlk;
	memset(&CmdBlk, 0, sizeof(SCSICMDBLK));
		
	CmdBlk.CdbLength		=	6;
	CmdBlk.Direction		= SCSI_DATA_OUT;
	CmdBlk.ReturnBytes		= 0;
	
	CmdBlk.Cdb[0] = 0xE5;
	
	
	for(Address = StartAddress, LengthRemain = LengthTotal, DataIndex = 0;
		LengthRemain > 0 ;
		Address+=LengthForOneTime, LengthRemain -=LengthForOneTime, DataIndex+=LengthForOneTime)
	{
		

		CmdBlk.Cdb[2] = (UInt8)(Address >> 8);
		CmdBlk.Cdb[3] = (UInt8)Address;//(UInt8)(Address << 8) >> 8;
		
		if(LengthRemain > LengthForOneTime)
		{
			CmdBlk.TransferLength	= LengthForOneTime;
			CmdBlk.Cdb[4] = (UInt8)LengthForOneTime;
			memcpy(CmdBlk.DataBuffer, Data + DataIndex, LengthForOneTime);
		}
		else
		{
			CmdBlk.TransferLength	= LengthRemain;
			CmdBlk.Cdb[4] = (UInt8)LengthRemain;
			memcpy(&CmdBlk.DataBuffer, Data + DataIndex, LengthRemain);
		}
	
		if(![self UstorVendorScsiCmd:CmdBlk iLun:iLun])
		{
			//fprintf(stderr, "Write Firmware fail.\n");
			NSLog(@"Write Firmware fail.\n");
			bRet = false;
			break;
		}
	}
	
	return bRet;
}

-(BOOL)UstorReadExternalFlash:(UInt32)StartAddress LengthTotal:(UInt32)LengthTotal Data:(UInt8 *)Data LengthForOneTime:(UInt32)LengthForOneTime iLun:(int)iLun
{
	BOOL bRet = true;
	UInt32 DataIndex;
	UInt32 Address;
	int LengthRemain;
	SCSICMDBLK CmdBlk;
	memset(&CmdBlk, 0, sizeof(SCSICMDBLK));
	
	CmdBlk.CdbLength		=	6;
	CmdBlk.Direction		= SCSI_DATA_IN;
	
	
	CmdBlk.Cdb[0] = 0xE4;
	
	
	for(Address = StartAddress, LengthRemain = LengthTotal, DataIndex = 0;
		LengthRemain > 0 ;
		Address+=LengthForOneTime, LengthRemain -=LengthForOneTime, DataIndex+=LengthForOneTime)
	{
		
		
		CmdBlk.Cdb[2] = (UInt8)(Address >> 8);
		CmdBlk.Cdb[3] = (UInt8)Address;//(UInt8)(StartAddress << 8) >> 8;
		
		if(LengthRemain > LengthForOneTime)
		{
			CmdBlk.ReturnBytes		= LengthForOneTime;
			CmdBlk.TransferLength	= LengthForOneTime;
			CmdBlk.Cdb[4] = (UInt8)LengthForOneTime;
			//memcpy(&CmdBlk, Data + DataIndex, LengthForOneTime);
		}
		else
		{
			CmdBlk.ReturnBytes		= LengthRemain;
			CmdBlk.TransferLength	= LengthRemain;
			CmdBlk.Cdb[4] = (UInt8)LengthRemain;
			//memcpy(&CmdBlk, Data + DataIndex, LengthRemain);
		}
		
		if(![self UstorVendorScsiCmd:CmdBlk iLun:iLun])
		{
			//fprintf(stderr, "Read Firmware fail.\n");
			NSLog(@"Read Firmware fail.\n");
			bRet = false;
			break;
		}
		
		// BOOK Test
		
//		[self RegistryGetData:(char *)(Data+DataIndex) Length:LengthForOneTime KeyName:CFSTR(kMyPropertyKey)];
		[self RegistryGetData:(char *)(Data+DataIndex) Length:LengthForOneTime KeyName:CFSTR(kMyPropertyKey) iLun:iLun];		
		//NSLog(@"%02X %02X %02X %02X %02X %02X", *(Data+DataIndex), *(Data+DataIndex+1), *(Data+DataIndex+2),*(Data+DataIndex+3), *(Data+DataIndex+4), *(Data+DataIndex+5));
		// BOOK Test
	}
	
	return bRet;
}

// BOOK Test

-(BOOL)GetMediaType:(int)MediaSupport iLun:(int)iLun Data:(UInt8 *)Data
{
	BOOL		bRet = false;
	SCSICMDBLK	CmdBlk;
	
	memset(&CmdBlk, 0, sizeof(SCSICMDBLK));
	
	CmdBlk.CdbLength = 6;
	CmdBlk.Direction = SCSI_DATA_IN;
	CmdBlk.TransferLength = 1;
	CmdBlk.ReturnBytes = 1;
	
	CmdBlk.Cdb[0] = 0xED;
	CmdBlk.Cdb[1] = MediaSupport;
	
	if (![self UstorVendorScsiCmd:CmdBlk iLun:iLun])
	{
		NSLog(@"GetMediaType fail.\n");
		bRet = false;		
	}

	[self RegistryGetData:(char *)Data Length:1 KeyName:CFSTR(kMyPropertyKey) iLun:iLun];

	return bRet;
}

-(BOOL)GetMediaInfo:(int)iLun Data:(UInt8)Data MediaInfo:(UInt8 *)pInfo
{
#define READ_MEDIA_INFO_LEN			8
	BOOL bRet = false;
	SCSICMDBLK CmdBlk;
	memset(&CmdBlk, 0, sizeof(SCSICMDBLK));
	CmdBlk.CdbLength = 6;
	CmdBlk.Direction = SCSI_DATA_IN;
	CmdBlk.TransferLength = READ_MEDIA_INFO_LEN;
	CmdBlk.ReturnBytes = READ_MEDIA_INFO_LEN;
	CmdBlk.Cdb[0] = 0xF1;
	CmdBlk.Cdb[1] = Data;
	
	if (![self UstorVendorScsiCmd:CmdBlk iLun:iLun])
	{
		NSLog(@"GetMediaInformation fail.\n");
		bRet = false;		
	}
	
	[self RegistryGetData:(char *)pInfo Length:READ_MEDIA_INFO_LEN KeyName:CFSTR(kMyPropertyKey) iLun:iLun];
	return bRet;
}

// BOOK Test

// BOOK Test

//-(BOOL)RegistryGetData:(char *)buf Length:(UInt32)Length KeyName:(CFStringRef)KeyName;
-(BOOL)RegistryGetData:(char *)buf Length:(UInt32)Length KeyName:(CFStringRef)KeyName iLun:(int)iLun

// BOOK Test

{
	BOOL bRet = false;
	kern_return_t  kr;
	CFDataRef      dataRef;
	UInt8          tmp[512]={0};
	CFMutableDictionaryRef      DictRef;
	
	// BOOK Test
	
//	kr = IORegistryEntryCreateCFProperties(parent, &DictRef, kCFAllocatorDefault, 0);
	kr = IORegistryEntryCreateCFProperties(parent[iLun], &DictRef, kCFAllocatorDefault, 0);
	
	// BOOK Test
	
	if (kr != KERN_SUCCESS) 
	{
		//fprintf(stderr, "IORegistryEntryCreateCFProperties returned 0x%08x.\n", kr);
		NSLog(@"IORegistryEntryCreateCFProperties returned 0x%08x.\n", kr);
	}
	
	bRet = CFDictionaryContainsKey(DictRef, KeyName);
	if (bRet)
	{
		dataRef = CFDictionaryGetValue(DictRef, KeyName);
		CFDataGetBytes(dataRef, CFRangeMake(0,CFDataGetLength(dataRef)), tmp);
		memcpy(buf, tmp, Length);
	}
	
	if (dataRef) CFRelease(dataRef);
	
	return bRet;
}


-(BOOL)CheckFlashTypeAndSendCommand:(int)nType szPath:(char *)szPath iLun:(int)iLun
{
	BOOL bRet = false;
	int      i ;
	FILE	 *fConfig;
	
	if ((fConfig = fopen(szPath, "rb")) == NULL)
	{
		return false;
	}
	else
		fclose(fConfig);
	
	
	for( i = 0; i < GL3310_FLASH_NUM ; i++)
	{
		//bRet = SendVendorForSpiFlash(i, nType);
		bRet = [self SendVendorForSpiFlash:i nType:nType szPath:szPath iLun:iLun];
		if(bRet) break;
	}
	
	return bRet;
}

-(int)GetConfigData:(char *)szData nLen:(int)nLen DataBuf:(UInt8 *)bDataBuf
{
	int nCnt = 0;
	char *szTemp = NULL; //temp of szData
	char *szString = NULL;
	char *szToken = NULL;
	const char cStep[] = " ";
	
	szTemp = (char *)malloc(nLen);
	if(!szTemp)
		return nCnt;
	
	strncpy(szTemp, szData, nLen);
	
	szString = szTemp;
	szToken = strtok(szString, cStep);
	
	while( szToken != NULL )
	{										
		sscanf(szToken, "%02X", &bDataBuf[nCnt]);
		szToken = strtok( NULL, cStep );
		nCnt++;
	}
	
	if(szTemp)
	{
		free(szTemp);
		szTemp = NULL;
	}
	return nCnt;
}

-(int)GetConfigDataAndLength:(char *)szData nLen:(int)nLen DataBuf:(UInt8 *)bDataBuf
{
	int nCnt = 0;
	char *szTemp = NULL; //temp of szData
	char *szString = NULL;
	char *szToken = NULL;
	const char cStep[] = " ";
	
	szTemp = (char *)malloc(nLen);
	if(!szTemp)
		return nCnt;
	
	strncpy(szTemp, szData, nLen);
	
	szString = strchr(szTemp, ':') + 1;
	szToken = strtok(szString, cStep);
	
	while( szToken != NULL )
	{										
		sscanf(szToken, "%02X", &bDataBuf[nCnt]);
		szToken = strtok( NULL, cStep );
		nCnt++;
	}
	
	if(szTemp)
	{
		free(szTemp);
		szTemp = NULL;
	}
	return nCnt;
}

-(char *)strlwr:(char *)szSource nLen:(int)nLen
{
	//char *szRet = nil;
	int i = 0;
	for(i = 0; i < nLen; i++)
	{
		if(szSource[i] == 'A') szSource[i] = 'a';
		else if(szSource[i] == 'B') szSource[i] = 'b';
		else if(szSource[i] == 'C') szSource[i] = 'c';
		else if(szSource[i] == 'D') szSource[i] = 'd';
		else if(szSource[i] == 'E') szSource[i] = 'e';
		else if(szSource[i] == 'F') szSource[i] = 'f';
		else if(szSource[i] == 'G') szSource[i] = 'g';
		else if(szSource[i] == 'H') szSource[i] = 'h';
		else if(szSource[i] == 'I') szSource[i] = 'i';
		else if(szSource[i] == 'J') szSource[i] = 'j';
		else if(szSource[i] == 'K') szSource[i] = 'k';
		else if(szSource[i] == 'L') szSource[i] = 'l';
		else if(szSource[i] == 'M') szSource[i] = 'm';
		else if(szSource[i] == 'N') szSource[i] = 'n';
		else if(szSource[i] == 'O') szSource[i] = 'o';
		else if(szSource[i] == 'P') szSource[i] = 'p';
		else if(szSource[i] == 'Q') szSource[i] = 'q';
		else if(szSource[i] == 'R') szSource[i] = 'r';
		else if(szSource[i] == 'S') szSource[i] = 's';
		else if(szSource[i] == 'T') szSource[i] = 't';
		else if(szSource[i] == 'U') szSource[i] = 'u';
		else if(szSource[i] == 'V') szSource[i] = 'v';
		else if(szSource[i] == 'W') szSource[i] = 'w';
		else if(szSource[i] == 'X') szSource[i] = 'x';
		else if(szSource[i] == 'Y') szSource[i] = 'y';
		else if(szSource[i] == 'Z') szSource[i] = 'z';
	}
	//return szRet;
	return szSource;
}


-(BOOL)SendVendorForSpiFlash:(int)nFlashType nType:(int)nType szPath:(char *)szPath iLun:(int)iLun
{
	BOOL bRet = true;
	char		szGetStr[512] = {0};

	FILE		*fConfig;
	int			iSleep = 0;
	SCSICMDBLK	CmdBlk = {0};

	UInt8		Cdb[20]={0}, DataBuf[16]={0}, TmpBuf[16]={0};
	
	BOOL		Status;
	char        szSPIType[64] = {0};
	char        szTmpSPIType[64] = {0};
	int			i;
	BOOL	    bCompareStatus=DO_NOTHING;
	char	    szGetCmdData[256]={0};
	BOOL		bSkipGetStr = false;
	
	switch(nFlashType)
	{
		case ID_SST:
			sprintf(szTmpSPIType, "%s", "[SST");
			break;
		case ID_PMC:
			sprintf(szTmpSPIType, "%s", "[PMC");
			break;
		case ID_ST:
			sprintf(szTmpSPIType, "%s", "[ST");
			break;
		case ID_WINBON:
			sprintf(szTmpSPIType, "%s", "[Winbon");
			break;
		case ID_EON:
			sprintf(szTmpSPIType, "%s", "[EON");
			break;
		case ID_MXIC:
			sprintf(szTmpSPIType, "%s", "[MXIC");
			break;
		case ID_OTHER:
			sprintf(szTmpSPIType, "%s", "[OTHER");
			break;
		default:
			break;
	}
	
	if ((fConfig = fopen(szPath, "rb")) != NULL)
	{
		for(i = 1 ; i <= CHECK_FLASH_LOOP_CNT ; i++)
		{
			bCompareStatus = DO_NOTHING;
			if(nType == 0)
				sprintf(szSPIType, "%s%d]", szTmpSPIType, i);	
			else if(nType == 1)
				strcpy(szSPIType, g_szSPIType);
			
			
			do
			{
				fgets(szGetStr, sizeof(szGetStr), fConfig);
				//NSLog(@"%s", szGetStr);
				if ( strstr(szGetStr, szSPIType) ) 
				{	
					//NSLog(@"%s",szGetStr);
					bSkipGetStr = FALSE; 
					do
					{
						if(!bSkipGetStr)
						{
							fgets(szGetStr, sizeof(szGetStr), fConfig);
							//NSLog(@"%s", szGetStr);
						}
						
						if(nType == 0)
						{
							if(!strstr([self strlwr:szGetStr nLen:sizeof(szGetStr)], "data:")  && 
							   !strstr([self strlwr:szGetStr nLen:sizeof(szGetStr)], "delay:") && 
							   !strstr([self strlwr:szGetStr nLen:sizeof(szGetStr)], "writeflash") && 
							   !strstr([self strlwr:szGetStr nLen:sizeof(szGetStr)], "indata") &&
							   !strstr([self strlwr:szGetStr nLen:sizeof(szGetStr)], "outdata")
							   )
							{
								//ZeroMemory(Cdb, sizeof(Cdb));
								memset(Cdb, 0, sizeof(Cdb));
//								int nCdbLen = GetConfigData(szGetStr, sizeof(szGetStr), Cdb);
								int nCdbLen = [self GetConfigData:szGetStr nLen:sizeof(szGetStr) DataBuf:Cdb];
								
								fgets(szGetCmdData, sizeof(szGetCmdData), fConfig);
								if(strstr([self strlwr:szGetCmdData nLen:sizeof(szGetCmdData)], "outdata"))
								{
									bSkipGetStr = FALSE;
									
									CmdBlk.Direction = SCSI_DATA_OUT;
									memset(DataBuf, 0 , sizeof(DataBuf));
									//CmdBlk.TransferLength = GetConfigDataAndLength(szGetCmdData, 
									//											   sizeof(szGetCmdData),
									//											   DataBuf);
									CmdBlk.TransferLength = [self GetConfigDataAndLength:szGetCmdData nLen:sizeof(szGetCmdData) DataBuf:DataBuf];
									
									//CmdBlk.DataBuf = DataBuf;
									memcpy(CmdBlk.DataBuffer, DataBuf, sizeof(DataBuf));
								}
								else if(strstr([self strlwr:szGetCmdData nLen:sizeof(szGetCmdData)], "indata"))
								{
									bSkipGetStr = FALSE;
									
									CmdBlk.Direction = SCSI_DATA_IN;
									memset(DataBuf, 0, sizeof(DataBuf));
									//CmdBlk.TransferLength = GetConfigDataAndLength(szGetCmdData, 
									//											   sizeof(szGetCmdData),
									//											   DataBuf);
									CmdBlk.TransferLength = [self GetConfigDataAndLength:szGetCmdData nLen:sizeof(szGetCmdData) DataBuf:DataBuf];
									CmdBlk.ReturnBytes = CmdBlk.TransferLength;
									//ZeroMemory(DataBuf, sizeof(DataBuf));
									memset(DataBuf, 0, sizeof(DataBuf));
									//CmdBlk.DataBuf = DataBuf;
								}
								else 
								{
									if(Cdb[1] == 0x02)
									{
										CmdBlk.Direction = SCSI_DATA_OUT;
										CmdBlk.TransferLength = Cdb[3];
										
										strcpy(szGetStr, szGetCmdData);
										bSkipGetStr = FALSE;
										
										
										switch (Cdb[3])
										{
											case 1:
												sscanf(szGetStr, "data:%02X", 
													   &DataBuf[0]);
												break;
											case 2:
												sscanf(szGetStr, "data:%02X %02X", 
													   &DataBuf[0], &DataBuf[1]);
												break;
											case 3:
												sscanf(szGetStr, "data:%02X %02X %02X", 
													   &DataBuf[0], &DataBuf[1], &DataBuf[2]);
												break;
											case 4:
												sscanf(szGetStr, "data:%02X %02X %02X %02X", 
													   &DataBuf[0], &DataBuf[1], &DataBuf[2], &DataBuf[3]);
												break;
											case 5:
												sscanf(szGetStr, "data:%02X %02X %02X %02X %02X", 
													   &DataBuf[0], &DataBuf[1], &DataBuf[2], &DataBuf[3], 
													   &DataBuf[4]);
												break;
											case 6:
												sscanf(szGetStr, "data:%02X %02X %02X %02X %02X %02X",
													   &DataBuf[0], &DataBuf[1], &DataBuf[2], &DataBuf[3], 
													   &DataBuf[4], &DataBuf[5]);
												break;
											case 7:
												sscanf(szGetStr, "data:%02X %02X %02X %02X %02X %02X %02X", 
													   &DataBuf[0], &DataBuf[1], &DataBuf[2], &DataBuf[3], 
													   &DataBuf[4], &DataBuf[5], &DataBuf[6]);
												break;
											case 8:
												sscanf(szGetStr, "data:%02X %02X %02X %02X %02X %02X %02X %02X",
													   &DataBuf[0], &DataBuf[1], &DataBuf[2], &DataBuf[3], 
													   &DataBuf[4], &DataBuf[5], &DataBuf[6], &DataBuf[7]);
												break;
										}//End switch (Cdb[3])									
										//CmdBlk.DataBuf = DataBuf;
										memcpy(CmdBlk.DataBuffer, DataBuf, sizeof(DataBuf));
									}//End if (Cdb[1] == 0x02)
									else if (Cdb[1] == 0x04)
									{
										CmdBlk.Direction = SCSI_DATA_IN;
										CmdBlk.TransferLength = Cdb[5];
										CmdBlk.ReturnBytes = Cdb[5];
										//CmdBlk.DataBuf = DataBuf;
										
										bSkipGetStr = FALSE;
										//ZeroMemory(szGetStr, sizeof(szGetStr));
										memset(szGetStr, 0, sizeof(szGetStr));
										strcpy(szGetStr, szGetCmdData);
										
									}
									/*
									else if (Cdb[1] == 0x0A)
									{
										m_dwSPIInfoAddr = 0;
										CmdBlk.Direction = SCSI_DATA_IN;
										CmdBlk.TransferLength = sizeof(m_dwSPIInfoAddr);
										CmdBlk.ReturnBytes = CmdBlk.TransferLength;
										//CmdBlk.DataBuf = &m_dwSPIInfoAddr;
										
										bSkipGetStr = TRUE;
										//ZeroMemory(szGetStr, sizeof(szGetStr));
										memset(szGetStr, 0, sizeof(szGetStr));
										strcpy(szGetStr, szGetCmdData);
									}
									 */
									else //Cdb[1] != 0x02 && Cdb[1] != 0x04
									{
										CmdBlk.Direction = SCSI_NO_DATA;
										CmdBlk.TransferLength = 0;
										//CmdBlk.DataBuf = NULL;
										
										bSkipGetStr = TRUE;
										//ZeroMemory(szGetStr, sizeof(szGetStr));
										memset(szGetStr, 0, sizeof(szGetStr));
										strcpy(szGetStr, szGetCmdData);
									}
								}//end else, clhsiao test
								
								/*
								// BOOK Test
								
								if (Cdb0 != 0x00 || Cdb1 != 0x00 || Cdb2 != 0x00 || Cdb3 != 0x00)
								{
									//+++++clhsiao test
									for(j = nCdbLen -1; j >= 0; j--)
									{
										Cdb[4+j] = Cdb[j];
									}
									
									 //Cdb[9] = Cdb[5];
									 //Cdb[8] = Cdb[4];
									 //Cdb[7] = Cdb[3];
									 //Cdb[6] = Cdb[2];
									 //Cdb[5] = Cdb[1];
									 //Cdb[4] = Cdb[0];
									
									
									Cdb[3] = Cdb3;
									Cdb[2] = Cdb2;
									Cdb[1] = Cdb1;
									Cdb[0] = Cdb0;
									
									nCdbLen += 4;
								}
								
								// BOOK Test
								 */
								
								//+++++clhsiao test
								CmdBlk.CdbLength = nCdbLen;
								//CmdBlk.CdbLength = sizeof(Cdb);
								//-----clhsiao test
								
								//CmdBlk.Cdb = Cdb;
								memcpy(CmdBlk.Cdb, Cdb, sizeof(CmdBlk.Cdb));
								
								//UstorOpenDevice(devHandle, INSTANCE);
								//Status = UstorVendorScsiCmd(devHandle, INSTANCE, &CmdBlk);
								//UstorCloseDevice(devHandle, INSTANCE);
								
								// BOOK Test
								
//								Status = [self UstorVendorScsiCmd:CmdBlk];
								Status = [self UstorVendorScsiCmd:CmdBlk iLun:iLun];
								
								// BOOK Test
								
								if (!Status)
								{	
									NSLog(@"scsi command fail\n");
									
									sleep(1);
									//UstorOpenDevice(devHandle, INSTANCE);
									//Status = UstorVendorScsiCmd(devHandle, INSTANCE, &CmdBlk);
									//UstorCloseDevice(devHandle, INSTANCE);
									
									// BOOK Test
									
//									Status = [self UstorVendorScsiCmd:CmdBlk];
									Status = [self UstorVendorScsiCmd:CmdBlk iLun:iLun];
									
									// BOOK Test
									
									if(!Status)
									{
										fclose(fConfig);
										return FALSE;
									}
								}
								else
								{		
									/*
									// BOOK Test
									
									if (Cdb0 != 0x00 || Cdb1 != 0x00 || Cdb2 != 0x00 || Cdb3 != 0x00)
									{
										Cdb[1] = Cdb[5];
										Cdb[5] = Cdb[9];
									}
									 */
									
									// BOOK Test
									
									//+++++clhsiao test
									if(CmdBlk.Direction == SCSI_DATA_IN)
										
										// BOOK Test
										
//										[self RegistryGetData:(char *)DataBuf Length:CmdBlk.TransferLength KeyName:CFSTR(kMyPropertyKey)];//clhsiao test
										[self RegistryGetData:(char *)DataBuf Length:CmdBlk.TransferLength KeyName:CFSTR(kMyPropertyKey) iLun:iLun];
									
										// BOOK Test
							
									if(strstr([self strlwr:szGetCmdData nLen:sizeof(szGetCmdData)], "indata"))
									{
										memset(TmpBuf, 0, sizeof(TmpBuf));
										//int nCmpLen = GetConfigDataAndLength(szGetCmdData, 
										//									 sizeof(szGetCmdData),
										//									 TmpBuf);
										int nCmpLen = [self GetConfigDataAndLength:szGetCmdData nLen:sizeof(szGetCmdData) DataBuf:TmpBuf];
										if(memcmp(TmpBuf, DataBuf, nCmpLen) == 0)
										{
											bSkipGetStr = FALSE; //clhsiao test
											bCompareStatus = COMPARE_SUCCESS;
											strcpy(g_szSPIType, szSPIType);
											NSLog(@"%s", g_szSPIType);	
										}
										else
										{
											NSLog(@"Compare fail!!\n");	
											bCompareStatus = COMPARE_FAIL;	
										}
									}
									else
									{
									//-----clhsiao test
										if (Cdb[1] == 0x04)
										{
											//clhsiao add for Jim
											//fgets(szGetStr, sizeof(szGetStr), fConfig); //clhsiao test,
											UInt8 bTemp[16]={0};
											//int nLen = GetConfigDataAndLength(szGetCmdData, 
											//								  sizeof(szGetCmdData),
											//								  bTemp);
											int nLen = [self GetConfigDataAndLength:szGetCmdData nLen:sizeof(szGetCmdData) DataBuf:bTemp];
											switch(nLen)
											//switch (Cdb[5])
											{
													
												case 1:
													sscanf(szGetStr, "data:%02X", &TmpBuf[0]);
													
													if (TmpBuf[0] != DataBuf[0])
													{											
														NSLog(@"Compare fail!!\n");	
														bCompareStatus = COMPARE_FAIL;											
													}
													else
													{
														bCompareStatus = COMPARE_SUCCESS;
														strcpy(g_szSPIType, szSPIType);
														NSLog(@"%s",g_szSPIType);											
													}
													break;
													case 2:
													sscanf(szGetStr, "data:%02X %02X", &TmpBuf[0], &TmpBuf[1]);
													
													NSLog(@"%02X  %02X", TmpBuf[0], TmpBuf[1]);
													NSLog(@"%02X  %02X", DataBuf[0], DataBuf[1]);
													if ((TmpBuf[0] != DataBuf[0]) || (TmpBuf[1] != DataBuf[1]))
													{											
														NSLog(@"Compare fail!!");											
														bCompareStatus = COMPARE_FAIL;										
													}
													else
													{
														bCompareStatus = COMPARE_SUCCESS;
														strcpy(g_szSPIType, szSPIType);
														NSLog(@"%s", g_szSPIType);											
													}
													break;
													case 3:
													sscanf(szGetStr, "data:%02X %02X %02X",
														   &TmpBuf[0], &TmpBuf[1], &TmpBuf[2]);
													
													NSLog(@"%02X  %02X  %02X", TmpBuf[0], TmpBuf[1], TmpBuf[2]);
													NSLog(@"%02X  %02X  %02X", DataBuf[0], DataBuf[1], DataBuf[2]);
													if ((TmpBuf[0] != DataBuf[0]) || (TmpBuf[1] != DataBuf[1]) || (TmpBuf[2] != DataBuf[2]))
													{											
														NSLog(@"Compare fail!!");																					
														bCompareStatus = COMPARE_FAIL;											
													}
													else
													{
														bCompareStatus = COMPARE_SUCCESS;
														strcpy(g_szSPIType, szSPIType);
														NSLog(@"%s", g_szSPIType);											
													}
													break;
													case 4:
													sscanf(szGetStr, "data:%02X %02X %02X %02X",
														   &TmpBuf[0], &TmpBuf[1], &TmpBuf[2], &TmpBuf[3]);
													
													NSLog(@"%02X  %02X  %02X  %02X", TmpBuf[0], TmpBuf[1], TmpBuf[2], TmpBuf[3]);
													NSLog(@"%02X  %02X  %02X  %02X", DataBuf[0], DataBuf[1], DataBuf[2], DataBuf[3]);
													if ((TmpBuf[0] != DataBuf[0]) || (TmpBuf[1] != DataBuf[1]) || (TmpBuf[2] != DataBuf[2]) || (TmpBuf[3] != DataBuf[3]))
													{											
														NSLog(@"Compare fail!!");																					
														bCompareStatus = COMPARE_FAIL;											
													}
													else
													{
														bCompareStatus = COMPARE_SUCCESS;
														strcpy(g_szSPIType, szSPIType);
														NSLog(@"%s", g_szSPIType);											
													}
													break;
													case 5:
													sscanf(szGetStr, "data:%02X %02X %02X %02X %02X", 
														   &TmpBuf[0], &TmpBuf[1], &TmpBuf[2], &TmpBuf[3], &TmpBuf[4]);
													
													if ((TmpBuf[0] != DataBuf[0]) || (TmpBuf[1] != DataBuf[1]) || (TmpBuf[2] != DataBuf[2]) || (TmpBuf[3] != DataBuf[3]) || (TmpBuf[4] != DataBuf[4]))
													{											
														NSLog(@"Compare fail!!");
														bCompareStatus = COMPARE_FAIL;											
													}
													else
													{
														bCompareStatus = COMPARE_SUCCESS;
														strcpy(g_szSPIType, szSPIType);
														NSLog(@"%s", g_szSPIType);										
													}
													
													break;
													case 6:
													sscanf(szGetStr, "data:%02X %02X %02X %02X %02X %02X",
														   &TmpBuf[0], &TmpBuf[1], &TmpBuf[2], &TmpBuf[3], &TmpBuf[4], &TmpBuf[5]);
													
													if ((TmpBuf[0] != DataBuf[0]) || (TmpBuf[1] != DataBuf[1]) || (TmpBuf[2] != DataBuf[2]) || (TmpBuf[3] != DataBuf[3]) || (TmpBuf[4] != DataBuf[4]) || (TmpBuf[5] != DataBuf[5]))
													{											
														NSLog(@"Compare fail!!");											
														bCompareStatus = COMPARE_FAIL;										
													}
													else
													{
														bCompareStatus = COMPARE_SUCCESS;
														strcpy(g_szSPIType, szSPIType);
														NSLog(@"%s", g_szSPIType);										
													}
													
													break;
													case 7:
													sscanf(szGetStr, "data:%02X %02X %02X %02X %02X %02X %02X",
														   &TmpBuf[0], &TmpBuf[1], &TmpBuf[2], &TmpBuf[3], &TmpBuf[4], &TmpBuf[5], &TmpBuf[6]);
													
													if ((TmpBuf[0] != DataBuf[0]) || (TmpBuf[1] != DataBuf[1]) || (TmpBuf[2] != DataBuf[2]) || (TmpBuf[3] != DataBuf[3]) || (TmpBuf[4] != DataBuf[4]) || (TmpBuf[5] != DataBuf[5]) || (TmpBuf[6] != DataBuf[6]))
													{											
														NSLog(@"Compare fail!!");
														bCompareStatus = COMPARE_FAIL;										
													}
													else
													{
														bCompareStatus = COMPARE_SUCCESS;
														strcpy(g_szSPIType, szSPIType);
														NSLog(@"%s", g_szSPIType);										
													}
													
													break;
													case 8:
													sscanf(szGetStr, "data:%02X %02X %02X %02X %02X %02X %02X %02X", 
														   &TmpBuf[0], &TmpBuf[1], &TmpBuf[2], &TmpBuf[3], &TmpBuf[4], &TmpBuf[5], &TmpBuf[6], &TmpBuf[7]);
													
													if ((TmpBuf[0] != DataBuf[0]) || (TmpBuf[1] != DataBuf[1]) || (TmpBuf[2] != DataBuf[2]) || (TmpBuf[3] != DataBuf[3]) || (TmpBuf[4] != DataBuf[4]) || (TmpBuf[5] != DataBuf[5]) || (TmpBuf[6] != DataBuf[6]) || (TmpBuf[7] != DataBuf[7]))
													{											
														NSLog(@"Compare fail!!");											
														bCompareStatus = COMPARE_FAIL;										
													}
													else
													{
														bCompareStatus = COMPARE_SUCCESS;
														strcpy(g_szSPIType, szSPIType);
														NSLog(@"%s", g_szSPIType);									
													}
													break;
											}//End switch (Cdb[5])
											
										}//End if (Cdb[1] == 0x04)
										/*
										//+++++clhsiao test
										else if(Cdb[1] == 0x0A)
										{
											//m_dwSPIInfoAddr = strtoul((char *)DataBuf, NULL, 16);
											
											m_dwSPIInfoAddr = ((m_dwSPIInfoAddr & 0xff000000) >> 24 ) | 
											((m_dwSPIInfoAddr & 0x00ff0000) >> 8 )  | 
											((m_dwSPIInfoAddr & 0x0000ff00) << 8 )  | 
											((m_dwSPIInfoAddr & 0x000000ff) << 24) ;											
											DbgPrint("SPI Info. address = %08X", m_dwSPIInfoAddr);
											
											//bSkipGetStr = TRUE;
										}
										//-----clhsiao test
										 */
									}//end else, clhsiao test
								}//End else (if (!Status))
							}//End if (!strstr(szGetStr, "Data:") && !strstr(szGetStr, "Delay:") && !strstr(szGetStr, "WriteFlash"))
							else if (strstr([self strlwr:szGetStr nLen:sizeof(szGetStr)], "delay:") && !strstr([self strlwr:szGetStr nLen:sizeof(szGetStr)], "writeFlash"))
							{
								sscanf(szGetStr, "delay:%d", &iSleep);
								usleep(iSleep*1000);
								NSLog(@"Delay %d ms", iSleep);
								bSkipGetStr = FALSE;
							}
							/*
							//+++++clhsiao test
							else if(strstr(strlwr(szGetStr), "write start"))
							{
								int nRow = 0;
								ZeroMemory(m_bSPIInfo, sizeof(m_bSPIInfo));
								do
								{
									ZeroMemory(szGetStr, sizeof(szGetStr));
									fgets(szGetStr, sizeof(szGetStr), fConfig);
									nRow = GetConfigData(szGetStr, sizeof(szGetStr), m_bSPIInfo+nRow);									
								}
								while(strstr(strlwr(szGetStr), "write end"));
								
								//handle check sum of SPI Info.
								DWORD dwCheckSum = 0;
								for(int k = 0; k < SPI_INFO_LEN - 4; k++)								
									dwCheckSum += m_bSPIInfo[k];
								
								m_bSPIInfo[SPI_INFO_LEN - 4] = (BYTE)(dwCheckSum >> 24);
								m_bSPIInfo[SPI_INFO_LEN - 3] = (BYTE)(dwCheckSum >> 16);
								m_bSPIInfo[SPI_INFO_LEN - 2] = (BYTE)(dwCheckSum >> 8);
								m_bSPIInfo[SPI_INFO_LEN - 1] = (BYTE)dwCheckSum;
								
								bSkipGetStr = FALSE;
							}
							 */
							else
								bSkipGetStr = FALSE;
							//-----clhsiao test
							
							
							if(bCompareStatus == COMPARE_FAIL)
							{
								rewind(fConfig);
								//bSkipGetStr = FALSE;
								break;
							}
							//+++++clhsiao test
							//else if(bCompareStatus == COMPARE_SUCCESS)
							//	bSkipGetStr = FALSE;
							//-----clhsiao test
							
							if (strstr([self strlwr:szGetStr nLen:sizeof(szGetStr)], "writeflash"))							
							{
								/*
								//+++++clhsiao test
								int nDelay = 0;
								m_nMicroSecond = 0;
								sscanf(szGetStr, "WriteFlash %d", &nDelay);
								m_nMicroSecond = nDelay;
								//DelayMicroSecond(nDelay);
								//-----clhsiao test
								 */
								
								//break;  //break   do...while
								if(bCompareStatus == COMPARE_SUCCESS)
								{
									fclose(fConfig);
									return TRUE;
								}
							}							
							
						}//End if (iType == 0)
						else if (nType == 1)
						{
							if (strstr([self strlwr:szGetStr nLen:sizeof(szGetStr)], "writeflash"))
							{
								fgets(szGetStr, sizeof(szGetStr), fConfig);
								
								//ZeroMemory(Cdb, sizeof(Cdb));
								memset(Cdb, 0, sizeof(Cdb));
								
								
								//int nCdbLen = GetConfigData(szGetStr, sizeof(szGetStr), Cdb);
								int nCdbLen = [self GetConfigData:szGetStr nLen:sizeof(szGetStr) DataBuf:Cdb];
								
								/*
								// BOOK Test
								
								if (Cdb0 != 0x00 || Cdb1 != 0x00 || Cdb2 != 0x00 || Cdb3 != 0x00)
								{
									for(j = nCdbLen -1; j >= 0; j--)
									{
										Cdb[4+j] = Cdb[j];
									}
									
									
									 //Cdb[9] = Cdb[5];
									 //Cdb[8] = Cdb[4];
									 //Cdb[7] = Cdb[3];
									 //Cdb[6] = Cdb[2];
									 //Cdb[5] = Cdb[1];
									 //Cdb[4] = Cdb[0];
									
									
									Cdb[3] = Cdb3;
									Cdb[2] = Cdb2;
									Cdb[1] = Cdb1;
									Cdb[0] = Cdb0;
									
									nCdbLen += 4;
								}
								
								// BOOK Test
								 */
								
								CmdBlk.Direction = SCSI_NO_DATA;
								CmdBlk.TransferLength = 0;
								//CmdBlk.DataBuf = NULL;		
								
								//+++++clhsiao test
								CmdBlk.CdbLength = nCdbLen;
								//CmdBlk.CdbLength = sizeof(Cdb);
								//-----clhsiao test
								
								//CmdBlk.Cdb = Cdb;
								memcpy(CmdBlk.Cdb, Cdb, sizeof(CmdBlk.Cdb));
								
								//UstorOpenDevice(devHandle, INSTANCE);
								//Status = UstorVendorScsiCmd(devHandle, INSTANCE, &CmdBlk);
								
								// BOOK Test
								
//								[self UstorVendorScsiCmd:CmdBlk];
								[self UstorVendorScsiCmd:CmdBlk iLun:iLun];
								
								// BOOK Test
								
								//UstorCloseDevice(devHandle, INSTANCE);
								
								if (!Status)
								{
									//MessageBox("Command fail!! (iType == 1)", "Error", MB_OK);
									fclose(fConfig);
									return FALSE;
								}
								
								fgets(szGetStr, sizeof(szGetStr), fConfig);
								
								if (strstr([self strlwr:szGetStr nLen:sizeof(szGetStr)], "delay:"))
								{
									sscanf(szGetStr, "delay:%d", &iSleep);
									//Sleep(iSleep);
									usleep(iSleep*1000);
								}	
								fclose(fConfig);
								return TRUE; 
							}//End if (strstr(szGetStr, "WriteFlash"))
						}//End else if (iType == 1)
					} while (!feof(fConfig));
					
					break;
				}//End if (strstr(szGetStr, szSPIFlash))				 
				
				
				if(i == CHECK_FLASH_LOOP_CNT) 
				{
					NSLog(@"break\n");
					fclose(fConfig);
					return FALSE;
				}
				
			} while (!feof(fConfig));
			
		}//end for i<= 10
		fclose(fConfig);
	}//End if ((fConfig = fopen(sPath, "rb")) != NULL)
	return bRet;
}


-(BOOL)UstorConvertConfigToRawData:(FROM_EEP *)FromEEP RawData:(UInt16 *)pBuffer iLun:(int)iLun
{
	BOOL		bRet = false;
	UInt8		CheckSum=0;
	UInt8		ptr, len;
	int			i, j;
	int			nCheckSumIndex = 0;
	int			dwEEPLen = 0;

	if(m_DriveInfo[iLun].InquiryData.UFDChipID == INQ_ID_GL3310 ||
	   m_DriveInfo[iLun].InquiryData.UFDChipID == INQ_ID_GL3311	)
	{
		nCheckSumIndex = FromEEP->nCheckSumIndex - 1;
		if(nCheckSumIndex <=0 || nCheckSumIndex == 0xFE)
		{
			NSLog(@"Check sum index error!\n");
			bRet = false;
			return bRet;
		}
		if (HIBYTE(FromEEP->AtaPid) != HIBYTE(FromEEP->AtapiPid)) goto DataTooLarge;
		
		if(m_DriveInfo[iLun].InquiryData.UFDChipID == INQ_ID_GL3310)
		{
			dwEEPLen = GL3310_EEP_LENGTH;
			pBuffer[0] = FromEEP->Vid;
			pBuffer[1] = FromEEP->AtaPid;
			pBuffer[2] = (FromEEP->AtapiPid << 8) + FromEEP->InitDelay;
			pBuffer[3] = (FromEEP->MaxPowerU3 << 8) + FromEEP->MaxPowerU2;
			pBuffer[6] = (FromEEP->Amp30G << 8) + FromEEP->Amp15G;
			pBuffer[7] = (FromEEP->Config1 << 8) + FromEEP->WatchDog; 
			pBuffer[8] = (FromEEP->Config3 << 8 ) + FromEEP->Config2;
			pBuffer[9] = (FromEEP->LedU3 << 8) + FromEEP->LedU2; 
			pBuffer[10]= (FromEEP->Reserve3 << 8) + FromEEP->Reserve2; 
			
			//clhsiao add for add new eep
			for(i = 11 , j = 0; i < nCheckSumIndex; i++, j++)
			{
				if(i >= NEW_ADD_NUMBER) break;
				pBuffer[i] = FromEEP->NewAdd[j];
			}
			
			pBuffer[nCheckSumIndex] = FromEEP->Reserve;
		}
		else if(m_DriveInfo[iLun].InquiryData.UFDChipID == INQ_ID_GL3311)
		{
			dwEEPLen = GL3311_EEP_LENGTH;
			pBuffer[0] = FromEEP->Vid;
			pBuffer[1] = FromEEP->AtaPid;
			pBuffer[2] = (FromEEP->AtapiPid << 8) + FromEEP->InitDelay;
			pBuffer[3] = (FromEEP->MaxPowerU3 << 8) + FromEEP->MaxPowerU2;
			pBuffer[6] = (FromEEP->Amp30G << 8) + FromEEP->Amp15G;
			pBuffer[7] = (FromEEP->Config1 << 8) + FromEEP->WatchDog; 
			pBuffer[8] = (FromEEP->Config3 << 8 ) + FromEEP->Config2;
			
			//clhsiao add for add new eep
			for(i = 9 , j = 0; i < nCheckSumIndex; i++, j++)
			{
				if(i >= NEW_ADD_NUMBER) break;
				pBuffer[i] = FromEEP->NewAdd[j];
			}
			
			pBuffer[nCheckSumIndex] = FromEEP->Reserve;
		}
		
		
		ptr = nCheckSumIndex+1; //12
		len = strlen(FromEEP->VendorStr);
		if (len != 0)
		{
			pBuffer[4] = ptr;
			pBuffer[ptr++] = 0x0300 + (len+1)*2;
			if (ptr+len >= dwEEPLen) goto DataTooLarge;
			for (i=0; i<len; i++) pBuffer[ptr++] = FromEEP->VendorStr[i];
		}
		
		len = strlen(FromEEP->ProductStr);
		if (len != 0)
		{
			pBuffer[4] += (UInt16)ptr << 8;
			pBuffer[ptr++] = 0x0300 + (len+1)*2;
			if (ptr+len >= dwEEPLen) goto DataTooLarge;
			for (i=0; i<len; i++) pBuffer[ptr++] = FromEEP->ProductStr[i];
		}
		
		len = strlen(FromEEP->SerialStr);
		if (len != 0)
		{
			pBuffer[5] = ptr;
			pBuffer[ptr++] = 0x0300 + (len+1)*2;
			if (ptr+len >= dwEEPLen) goto DataTooLarge;
			for (i=0; i<len; i++) pBuffer[ptr++] = FromEEP->SerialStr[i];
		}
		
		len = strlen(FromEEP->InterfaceStr);
		if (len != 0)
		{
			pBuffer[5] += (UInt16)ptr << 8;
			pBuffer[ptr++] = 0x0300 + (len+1)*2;
			if (ptr+len >= dwEEPLen) goto DataTooLarge;
			for (i=0; i<len; i++) pBuffer[ptr++] = FromEEP->InterfaceStr[i];
		}
		
		
		//INQ_VENDOR_STRING
		len = INQ_VENDOR_LEN;
		if(len != 0)
		{
			for(i = 0, j = 0; i < len ; i++, j+=2)
				pBuffer[ptr++] = ((FromEEP->InqVendorStr[j]) << 8) + FromEEP->InqVendorStr[j+1];
		}
		
		//INQ_PRODUCT_STRING
		len = INQ_PRODUCT_LEN;
		if(len != 0)
		{
			for(i = 0, j = 0; i < len ; i++, j+=2)
				pBuffer[ptr++] = ((FromEEP->InqProductStr[j]) << 8) + FromEEP->InqProductStr[j+1];
		}
		
		for (i=0; i< nCheckSumIndex; i++) 
		{
			//CheckSum += HIBYTE(pBuffer[i]) + LOBYTE(pBuffer[i]);
			CheckSum += HIBYTE(pBuffer[i]);
			CheckSum += LOBYTE(pBuffer[i]);
		}
		CheckSum += LOBYTE(pBuffer[nCheckSumIndex])+0xAA;
		pBuffer[nCheckSumIndex] += (UInt16)(CheckSum << 8 & 0xFF00);
	}
	else if(m_DriveInfo[iLun].InquiryData.CardReaderChipID == INQ_ID_GL3220 ||
			m_DriveInfo[iLun].InquiryData.CardReaderChipID == INQ_ID_GL3221	)
	{
		nCheckSumIndex = FromEEP->nCheckSumIndex;
		if(nCheckSumIndex <=0 || nCheckSumIndex == 0xFE)
		{
			NSLog(@"Check sum index error!\n");
			bRet = false;
			return bRet;
		}
		
		pBuffer[0] = FromEEP->Vid;
		pBuffer[1] = FromEEP->Pid;
		pBuffer[2] = (UInt16)(FromEEP->MaxPower << 8) + FromEEP->MediaInDrv;
		pBuffer[3] = FromEEP->LunPerDev;
		pBuffer[6] = (UInt16)(FromEEP->MediaInLun[1] << 8) + FromEEP->MediaInLun[0];
		pBuffer[7] = (UInt16)(FromEEP->MediaInLun[3] << 8) + FromEEP->MediaInLun[2];
		pBuffer[8] = (UInt16)(FromEEP->MediaInLun[5] << 8 )+ FromEEP->MediaInLun[4];
		//Data[9] = EepData.GL3220.wConfig;
		pBuffer[nCheckSumIndex] = FromEEP->Config;
		
		ptr = nCheckSumIndex+1;
		len = strlen(FromEEP->VendorStr);
		if (len != 0)
		{
			pBuffer[4] = ptr;
			pBuffer[ptr++] = 0x0300 + (len+1)*2;
			if (ptr+len >= dwEEPLen) goto DataTooLarge;
			for (i=0; i<len; i++) pBuffer[ptr++] = FromEEP->VendorStr[i];
		}
		
		len = strlen(FromEEP->ProductStr);
		if (len != 0)
		{
			pBuffer[4] += (UInt16)ptr << 8;
			pBuffer[ptr++] = 0x0300 + (len+1)*2;
			if (ptr+len >= dwEEPLen) goto DataTooLarge;
			for (i=0; i<len; i++) pBuffer[ptr++] = FromEEP->ProductStr[i];
		}
		
		len = strlen(FromEEP->SerialStr);
		if (len != 0)
		{
			pBuffer[5] = ptr;
			pBuffer[ptr++] = 0x0300 + (len+1)*2;
			if (ptr+len >= dwEEPLen) goto DataTooLarge;
			for (i=0; i<len; i++) pBuffer[ptr++] = FromEEP->SerialStr[i];
		}
		
		len = strlen(FromEEP->InterfaceStr);
		if (len != 0)
		{
			pBuffer[5] += (UInt16)ptr << 8;
			pBuffer[ptr++] = 0x0300 + (len+1)*2;
			if (ptr+len >= dwEEPLen) goto DataTooLarge;
			for (i=0; i<len; i++) pBuffer[ptr++] = FromEEP->InterfaceStr[i];
		}
		
		if (strlen(FromEEP->CardStr[0]) != 0)
		{
			pBuffer[3] += (UInt16)ptr << 8;
			
			for (i=0; (i<MAX_CARD_TYPE) && (strlen(FromEEP->CardStr[i])!=0); i++)
			{		
				int CardStrLen = strlen(FromEEP->CardStr[i]);
				for ( j=0; j<CARD_STR_LEN-1-CardStrLen; j++) strcat(FromEEP->CardStr[i], " ");
				pBuffer[ptr++] = ((UInt16)FromEEP->CardStr[i][1] << 8) + FromEEP->CardStr[i][0];
				pBuffer[ptr++] = ((UInt16)FromEEP->CardStr[i][3] << 8) + FromEEP->CardStr[i][2];
			}
		}
		
		for (i=0; i< nCheckSumIndex; i++) CheckSum += HIBYTE(pBuffer[i]) + LOBYTE(pBuffer[i]);
		CheckSum += LOBYTE(pBuffer[nCheckSumIndex])+0xAA;
		pBuffer[nCheckSumIndex] += (UInt16)CheckSum << 8;
	}
	else
	{
		NSLog(@"Can't find any supported chip id\n");
		bRet = false;
	}
	
	bRet = true;
	
DataTooLarge:
	return bRet;
}



-(BOOL)UstorCombineBinAndEepFile:(UInt8 *)pBufferBin BufferEep:(UInt8 *)pBufferEep iLun:(int)iLun
{
	BOOL bRet = true;
	
	if(m_DriveInfo[iLun].InquiryData.UFDChipID == INQ_ID_GL3310)
	{
		UInt8 ZeroBuffer[GL3310_EEP_LENGTH*2] = {0};
		UInt8 FFBuffer[GL3310_EEP_LENGTH*2];
		memset(FFBuffer, 0xFF, GL3310_EEP_LENGTH*2);
		if(memcmp(pBufferBin + GL3310_EEP_START_ADDRESS, ZeroBuffer, GL3310_EEP_LENGTH*2) != 0 && 
		   memcmp(pBufferBin + GL3310_EEP_START_ADDRESS, FFBuffer, GL3310_EEP_LENGTH*2) != 0)
		{
			bRet = false;
			NSLog(@"EEP address of BIN file is not empty\n");
			return bRet;
		}
		memcpy(pBufferBin + GL3310_EEP_START_ADDRESS ,pBufferEep, GL3310_EEP_LENGTH*2 );
	}
	else if(m_DriveInfo[iLun].InquiryData.UFDChipID == INQ_ID_GL3311)
	{
		UInt8 ZeroBuffer[GL3311_EEP_LENGTH*2] = {0};
		UInt8 FFBuffer[GL3311_EEP_LENGTH*2];
		memset(FFBuffer, 0xFF, GL3311_EEP_LENGTH*2);
		if(memcmp(pBufferBin + GL3311_EEP_START_ADDRESS, ZeroBuffer, GL3311_EEP_LENGTH*2) != 0 && 
		   memcmp(pBufferBin + GL3311_EEP_START_ADDRESS, FFBuffer, GL3311_EEP_LENGTH*2) != 0)
		{
			bRet = false;
			NSLog(@"EEP address of BIN file is not empty\n");
			return bRet;
		}

		
		UInt8 TempBuffer[GL3311_FW_LENGTH] = {0};
		memcpy(TempBuffer, pBufferEep, GL3311_EEP_LENGTH*2);
		memcpy(TempBuffer+GL3311_EEP_LENGTH*2, pBufferBin, GL3311_FW_LENGTH - GL3311_EEP_LENGTH*2);
		
		memset(pBufferBin, 0, GL3311_FW_LENGTH);
		memcpy(pBufferBin, TempBuffer, GL3311_FW_LENGTH);
	}
	else if(m_DriveInfo[iLun].InquiryData.CardReaderChipID == INQ_ID_GL3220)
	{
		UInt8 ZeroBuffer[GL3220_EEP_LENGTH*2] = {0};
		UInt8 FFBuffer[GL3220_EEP_LENGTH*2];
		memset(FFBuffer, 0xFF, GL3220_EEP_LENGTH*2);
		if(memcmp(pBufferBin + GL3220_EEP_START_ADDRESS, ZeroBuffer, GL3220_EEP_LENGTH*2) != 0 && 
		   memcmp(pBufferBin + GL3220_EEP_START_ADDRESS, FFBuffer, GL3220_EEP_LENGTH*2) != 0)
		{
			bRet = false;
			NSLog(@"EEP address of BIN file is not empty\n");
			return bRet;
		}
		
		memcpy(pBufferBin + GL3220_EEP_START_ADDRESS, pBufferEep, GL3220_EEP_LENGTH*2 );
	}
	else if(m_DriveInfo[iLun].InquiryData.CardReaderChipID == INQ_ID_GL3221)
	{
		UInt8 ZeroBuffer[GL3221_EEP_LENGTH*2] = {0};
		UInt8 FFBuffer[GL3221_EEP_LENGTH*2];
		memset(FFBuffer, 0xFF, GL3221_EEP_LENGTH*2);
		if(memcmp(pBufferBin + GL3221_EEP_START_ADDRESS, ZeroBuffer, GL3221_EEP_LENGTH*2) != 0 && 
		   memcmp(pBufferBin + GL3221_EEP_START_ADDRESS, FFBuffer, GL3221_EEP_LENGTH*2) != 0)
		{
			bRet = false;
			NSLog(@"EEP address of BIN file is not empty\n");
			return bRet;
		}
		
		memcpy(pBufferBin + GL3221_EEP_START_ADDRESS, pBufferEep, GL3221_EEP_LENGTH*2 );
	}
	return bRet;
}

-(BOOL)UstorConvertRawDataToConfig:(FROM_EEP *)FromEEP RawData:(UInt16 *)Data iLun:(int)iLun
{
	BOOL bRet = TRUE;
	UInt8 CheckSum=0;
	UInt8 ptr, len;
	int	 nCheckSumIndex = 0;
	int  i, j;
	
	memset(FromEEP, 0, sizeof(FROM_EEP));
	
	if(LOBYTE(Data[4]) != 0)
		nCheckSumIndex = LOBYTE(Data[4]) - 1;
	else if(HIBYTE(Data[4]) != 0)
		nCheckSumIndex = HIBYTE(Data[4]) - 1;
	else if(LOBYTE(Data[5]) != 0)
		nCheckSumIndex = LOBYTE(Data[5]) - 1;
	else if(HIBYTE(Data[5]) != 0)
		nCheckSumIndex = HIBYTE(Data[5]) - 1;
	
	NSLog(@"Ustor: CheckSumIndex = %d\n", nCheckSumIndex);
	
	if(nCheckSumIndex <= 0 || nCheckSumIndex == 0xFE)
	{
		NSLog(@"Check sum index is not valid!\n");
		bRet = false;
		goto _err;
	}
	
	
	//checking checksum of EEP data
	for (i=0; i<nCheckSumIndex; i++) CheckSum += HIBYTE(Data[i]) + LOBYTE(Data[i]);
	CheckSum += LOBYTE(Data[nCheckSumIndex])+0xAA;
	
	if (CheckSum != HIBYTE(Data[nCheckSumIndex]))
	{
		NSLog(@"EEP data check sum error!\n");
		bRet = false;
		goto _err;
	}
	
	if([self m_DriveInfo:iLun].InquiryData.UFDChipID == INQ_ID_GL3310 || 
	   [self m_DriveInfo:iLun].InquiryData.UFDChipID == INQ_ID_GL3311)
	{
		if([self m_DriveInfo:iLun].InquiryData.UFDChipID == INQ_ID_GL3310)
		{
			FromEEP->Vid = Data[0];
			FromEEP->AtaPid = Data[1];
			FromEEP->AtapiPid = (Data[1]&0xff00) + HIBYTE(Data[2]);
			FromEEP->InitDelay = LOBYTE(Data[2]);
			FromEEP->MaxPowerU2 = LOBYTE(Data[3]);
			FromEEP->MaxPowerU3 = HIBYTE(Data[3]);
			FromEEP->Amp15G = LOBYTE(Data[6]);
			FromEEP->Amp30G = HIBYTE(Data[6]);
			FromEEP->WatchDog = LOBYTE(Data[7]);
			FromEEP->Config1 = HIBYTE(Data[7]);
			FromEEP->Config2 = LOBYTE(Data[8]);
			FromEEP->Config3 = HIBYTE(Data[8]);
			FromEEP->LedU3 = HIBYTE(Data[9]);
			FromEEP->LedU2  = LOBYTE(Data[9]);
			FromEEP->Reserve3  = HIBYTE(Data[10]);
			FromEEP->Reserve2  = LOBYTE(Data[10]);
			
			for(i = 11, j = 0 ; i < nCheckSumIndex; i++, j++)
			{
				if(i >= NEW_ADD_NUMBER) break;
				FromEEP->NewAdd[j] = Data[i];
			}
			
			FromEEP->Reserve = LOBYTE(Data[nCheckSumIndex]);
		}
		else
		{
			FromEEP->Vid = Data[0];
			FromEEP->AtaPid = Data[1];
			FromEEP->AtapiPid = (Data[1]&0xff00) + HIBYTE(Data[2]);
			FromEEP->InitDelay = LOBYTE(Data[2]);
			FromEEP->MaxPowerU2 = LOBYTE(Data[3]);
			FromEEP->MaxPowerU3 = HIBYTE(Data[3]);
			FromEEP->Amp15G = LOBYTE(Data[6]);
			FromEEP->Amp30G = HIBYTE(Data[6]);
			FromEEP->WatchDog = LOBYTE(Data[7]);
			FromEEP->Config1 = HIBYTE(Data[7]);
			FromEEP->Config2 = LOBYTE(Data[8]);
			FromEEP->Config3 = HIBYTE(Data[8]);
			
			//clhsiao add for add new eep
			for(i = 9, j = 0 ; i < nCheckSumIndex; i++, j++)
			{
				if(i >= NEW_ADD_NUMBER) break;
				FromEEP->NewAdd[j] = Data[i];
			}
			
			FromEEP->Reserve = LOBYTE(Data[nCheckSumIndex]);
		}
		
		ptr = LOBYTE(Data[4]);
		if (ptr!=0)
		{
			len = LOBYTE(Data[ptr++])/2 - 1;
			for (i=0; i<len; i++) FromEEP->VendorStr[i] = LOBYTE(Data[ptr++]);
		}
		
		ptr = HIBYTE(Data[4]);
		if (ptr!=0)
		{
			len = LOBYTE(Data[ptr++])/2 - 1;
			for (i=0; i<len; i++) FromEEP->ProductStr[i] = LOBYTE(Data[ptr++]);
		}
		
		ptr = LOBYTE(Data[5]);
		if (ptr!=0)
		{
			len = LOBYTE(Data[ptr++])/2 - 1;
			for (i=0; i<len; i++) FromEEP->SerialStr[i] = LOBYTE(Data[ptr++]);
		}
		
		ptr = HIBYTE(Data[5]);
		if (ptr!=0)
		{
			len = LOBYTE(Data[ptr++])/2 - 1;
			for (i=0; i<len; i++) FromEEP->InterfaceStr[i] = LOBYTE(Data[ptr++]);
		}
		
		//INQ_VENDOR_STRING
		len = INQ_VENDOR_LEN;
		if(len != 0)
		{
			for(i = 0, j = 0; i< len ; i++, j += 2)
			{
				FromEEP->InqVendorStr[j] = HIBYTE(Data[ptr]);
				FromEEP->InqVendorStr[j+1] = LOBYTE(Data[ptr++]);
			}
		}
		
		//INQ_PRODUCT_STRING
		len = INQ_PRODUCT_LEN;
		if(len != 0)
		{
			for(i = 0, j = 0; i < len; i++, j += 2)
			{
				FromEEP->InqProductStr[j] = HIBYTE(Data[ptr]);
				FromEEP->InqProductStr[j+1] = LOBYTE(Data[ptr++]);
			}
		}
		
	}
	else if([self m_DriveInfo:iLun].InquiryData.CardReaderChipID == INQ_ID_GL3220 || 
			[self m_DriveInfo:iLun].InquiryData.CardReaderChipID == INQ_ID_GL3221)
	{
		FromEEP->Vid = Data[0];
		FromEEP->Pid = Data[1];
		FromEEP->MaxPower = HIBYTE(Data[2]);
		FromEEP->MediaInDrv = LOBYTE(Data[2]);
		FromEEP->LunPerDev = LOBYTE(Data[3]);
		FromEEP->MediaInLun[0] = LOBYTE(Data[6]);
		FromEEP->MediaInLun[1] = HIBYTE(Data[6]);
		FromEEP->MediaInLun[2] = LOBYTE(Data[7]);
		FromEEP->MediaInLun[3] = HIBYTE(Data[7]);
		FromEEP->MediaInLun[4] = LOBYTE(Data[8]);
		FromEEP->MediaInLun[5] = HIBYTE(Data[8]);
		FromEEP->Config = LOBYTE(Data[nCheckSumIndex]);
		//EepData.GL3220.wConfig = Data[9];
		//EepData.GL3220.bReserved = LOBYTE(Data[GL3220_CHECK_SUM_IDX]);
		
		ptr = LOBYTE(Data[4]);
		if (ptr!=0)
		{
			len = LOBYTE(Data[ptr++])/2 - 1;
			for (i=0; i<len; i++) FromEEP->VendorStr[i] = LOBYTE(Data[ptr++]);
		}
		
		ptr = HIBYTE(Data[4]);
		if (ptr!=0)
		{
			len = LOBYTE(Data[ptr++])/2 - 1;
			for (i=0; i<len; i++) FromEEP->ProductStr[i] = LOBYTE(Data[ptr++]);
		}
		
		ptr = LOBYTE(Data[5]);
		if (ptr!=0)
		{
			len = LOBYTE(Data[ptr++])/2 - 1;
			for (i=0; i<len; i++) FromEEP->SerialStr[i] = LOBYTE(Data[ptr++]);
		}
		
		ptr = HIBYTE(Data[5]);
		if (ptr!=0)
		{
			len = LOBYTE(Data[ptr++])/2 - 1;
			for (i=0; i<len; i++) FromEEP->InterfaceStr[i] = LOBYTE(Data[ptr++]);
		}
		
		//handle Card String
		ptr = HIBYTE(Data[3]);
		if (ptr!=0)
		{	
			for (i=0; Data[ptr]!=0; i++, ptr+=2)
			{
				FromEEP->CardStr[i][0] = LOBYTE(Data[ptr]);
				FromEEP->CardStr[i][1] = HIBYTE(Data[ptr]);
				FromEEP->CardStr[i][2] = LOBYTE(Data[ptr+1]);
				FromEEP->CardStr[i][3] = HIBYTE(Data[ptr+1]);
			}
		}
		
	}//end else...if...
	
_err:
	return bRet;
}




-(BOOL)UstorWriteEEPDataToExternalFlash:(UInt8 *)Data LengthTotal:(UInt32)LengthTotal LengthForOneTime:(UInt32)LengthForOneTime iLun:(int)iLun
{
	BOOL bRet = TRUE;
	return bRet;
}

-(BOOL)UstorReadEEPDataFromExternalFlash:(UInt8 *)Data LengthTotal:(UInt32)LengthTotal LengthForOneTime:(UInt32)LengthForOneTime iLun:(int)iLun
{
	BOOL bRet = TRUE;
	UInt32 nEEPStartAddress = 0;
	UInt32 nEEPLength = 0;
	//eep data start address
	if([self m_DriveInfo:iLun].InquiryData.UFDChipID == INQ_ID_GL3310)
	{
		nEEPStartAddress = GL3310_EEP_START_ADDRESS;
		nEEPLength = GL3310_EEP_LENGTH*2;
	}
	else if([self m_DriveInfo:iLun].InquiryData.UFDChipID == INQ_ID_GL3311)
	{
		nEEPStartAddress = GL3311_EEP_START_ADDRESS;
		nEEPLength = GL3311_EEP_LENGTH*2;
	}
	else if([self m_DriveInfo:iLun].InquiryData.CardReaderChipID == INQ_ID_GL3220)
	{
		nEEPStartAddress = GL3220_EEP_START_ADDRESS;
		nEEPLength = GL3220_EEP_LENGTH*2;
	}
	else if([self m_DriveInfo:iLun].InquiryData.CardReaderChipID == INQ_ID_GL3221)
	{
		nEEPStartAddress = GL3221_EEP_START_ADDRESS;
		nEEPLength = GL3221_EEP_LENGTH*2;
	}
		
	if(nEEPLength > LengthTotal)
	{
		NSLog(@"Less of input buffer is too small\n");
		bRet = false;
		goto _err;
	}
	
	if(![self UstorReadExternalFlash:nEEPStartAddress LengthTotal:nEEPLength Data:Data LengthForOneTime:LengthForOneTime iLun:iLun ])
	{
		NSLog(@"Read EEP data form external flash fail\n");
		bRet = false;
		goto _err;
	}
	
_err:
	return bRet;
}


@end
