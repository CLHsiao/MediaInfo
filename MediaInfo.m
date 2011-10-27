#import "MediaInfo.h"

@implementation MediaInfo

-(void)dealloc
{
	[super dealloc];
}

-(void) awakeFromNib
{
	NSLog(@"awakeFromNib");
	ScsiCmd = [[SCSICmd alloc] init];
	[combleSelClockRate selectItemAtIndex:0];
	[combleSelClockRate setObjectValue:[combleSelClockRate objectValueOfSelectedItem]];
	[combleSelCurLimination selectItemAtIndex:0];
	[combleSelCurLimination setObjectValue:[combleSelCurLimination objectValueOfSelectedItem]];
	
	[comboSelUHSControl selectItemAtIndex:6];
	[comboSelUHSControl setObjectValue:[comboSelUHSControl objectValueOfSelectedItem]];
	//[comboSelReadCommandDelay selectItemAtIndex:0];
	//[comboSelReadCommandDelay setObjectValue:[comboSelReadCommandDelay objectValueOfSelectedItem]];
	[comboSelWriteCommandDelay selectItemAtIndex:0];
	[comboSelWriteCommandDelay setObjectValue:[comboSelWriteCommandDelay objectValueOfSelectedItem]];
	[comboSelSDDataOutDelay selectItemAtIndex:0];
	[comboSelSDDataOutDelay setObjectValue:[comboSelSDDataOutDelay objectValueOfSelectedItem]];
	
	//[combleSelClockRate addItemWithObjectValue:@"111111"];
	//[combleSelClockRate addItemWithObjectValue:@"222222"];
	
	//[radioVoltageOne setEnabled:NO];
	[self RefreshUI];
}

- (BOOL) RefreshUI
{
	BOOL bRet = true;
	int i = 0;
	int nLunCnt = 0;
	
	[ListResult setString:@""];
	
	nLunCnt = [ScsiCmd UstorCreateDeviceList:0 PID:0];
	if(nLunCnt == 0)
	{
		[ListResult setString:@"Can't find device\n"];
		[btnGetInfo setEnabled:NO];
		[btnSend setEnabled:NO];
		bRet = false;
		goto _err;
	}
	
	for(i = 0; i < nLunCnt; i++)
	{
		//if(i > 1) break;
		
		if([ScsiCmd m_DriveInfo:i].InquiryData.CardReaderChipID == INQ_ID_GL3220 || 
		   [ScsiCmd m_DriveInfo:i].InquiryData.CardReaderChipID == INQ_ID_GL3221)
		{
			[radioVoltageOne setEnabled:YES];
			[radioVoltageTwo setEnabled:YES];
			[radioEnableSSC setEnabled:YES];
			[radioDisableeSSC setEnabled:YES];
			[btnGetInfo setEnabled:YES];
			[btnSend setEnabled:YES];
			[ListResult setString:@"Device is found"];
			break;
		}
		else if([ScsiCmd m_DriveInfo:i].InquiryData.CardReaderChipID == INQ_ID_GL822)
		{
			[radioVoltageOne setEnabled:NO];
			[radioVoltageTwo setEnabled:NO];
			[radioEnableSSC setEnabled:NO];
			[radioDisableeSSC setEnabled:NO];
			[btnGetInfo setEnabled:YES];
			[btnSend setEnabled:YES];
			[ListResult setString:@"Device is found"];
			break;
		}
		else
		{
			[btnGetInfo setEnabled:NO];
			[btnSend setEnabled:NO];
			[ListResult setString:@"Device not supported!\n"];
		}
	}
	
	for (i = 0; i < nLunCnt; i++)
	{
		IOObjectRelease([ScsiCmd parent:i]);
	}
	
_err:
	return bRet;
	
}

- (IBAction)PressExitButton:(id)sender {
	exit(0);
}

#define MEDIA_SUPPORT			0x01
#define MEDIA_CURRENT			0x00

#define NO_MEDIA_REPORT			0x00
#define CF_REPORT				0x01
#define SM_REPORT				0x02
#define SD_REPORT				0x03
#define MS_REPORT				0x04
#define XD_REPORT				0x05
#define FLASH_REPORT			0x06
#define IDE_REPORT				0x07
#define MICRO_SD_REPORT			0x08
#define M2_REPORT				0x09


#define SD1_INTERFACE_READ		0x00
#define SD2_INTERFACE_READ		0x01
#define MS1_INTERFACE_READ		0X02
#define MS2_INTERFACE_READ		0X03
#define CF1_INTERFACE_READ		0x04
#define SD1_INTERFACE_WRITE		0x80
#define SD2_INTERFACE_WRITE		0x81
#define MS1_INTERFACE_WRITE		0x82
#define MS2_INTERFACE_WRITE		0x83
#define CF_INTERFACE_WRITE		0x84

#define BITMASK_SDR104			0x80
#define BITMASK_SDR50			0x40
#define BITMASK_DDR50			0x20
#define BITMASK_S18A			0x10
#define BITMASK_S18R			0x80


#define SSC_CONTROL				0x80

- (void) HandleShowResult:(UInt8)CardType Data:(UInt8 *)Info CardPluged:(BOOL *)pCardPluged
{
	int  nClock = 0;
	char szMsg[256] ={0};
	char szSpeed[256] = {0};
	char szVoltage[256] = {0};
	char szCurrent[256] = {0};
	char szCommandDelay[256] = {0};
	char szUHSControl[256] = {0};
	char szSSC[64] = {0};
	BOOL bFindSD = TRUE;
	BOOL bShowSpeed = false;
	
	switch(CardType)
	{
		case CF1_INTERFACE_READ:
			if((Info[0] & 0xFF) == 0x01)
				sprintf(szMsg, "CF Card   >>> type: PIO,    mode number: %d\n", Info[2]&0xFF);
			else if((Info[0] & 0xFF) == 0x02)
				sprintf(szMsg, "CF Card   >>> type: UDMA,    mode number: %d\n", Info[2]&0xFF);
			else if((Info[0] & 0xFF) == 0x00)
				sprintf(szMsg, "CF Card   >>> CF Card is not plugin\n");
			//[ListResult insertText:@"11 \n"];
			//[ListResult insertText:@"11 \n"];
            [ListResult insertText:[NSString stringWithUTF8String:szMsg]];
			//[ListResult insertText:[[NSString alloc] initWithCString:szMsg]];
			break;
		
		case SD1_INTERFACE_READ:
			//check card clock
			if([ScsiCmd m_DriveInfo:0].InquiryData.CardReaderChipID == INQ_ID_GL3220 || 
			   [ScsiCmd m_DriveInfo:0].InquiryData.CardReaderChipID == INQ_ID_GL3221)
			{
				nClock = Info[3]&0xFF;
				if(nClock == 0)	
					nClock = 25;
				switch(nClock)
				{
					case 50:
						sprintf(szSpeed, "%s", "HS");
						bShowSpeed = true;
						break;
					case 25:
						sprintf(szSpeed, "%s", "DS");
						bShowSpeed = true;
						break;
					default:
						bShowSpeed = false;
						break;
				}
				
				//check voltage
				if(Info[0] & BITMASK_S18A)
					sprintf(szVoltage, "%s", "working at 1.8V");
				else
					sprintf(szVoltage, "%s", "working at 3.3V");
				
				//check SSC control
				if (Info[1] & SSC_CONTROL) 
					sprintf(szSSC, "%s", "SSC Enable");
				else 
					sprintf(szSSC, "%s", "SSC Disable");
				
				//check current limitation
				if (Info[4] == 0xFF)
					sprintf(szCurrent, "%s", "Reader current limitation = 200 mA");
				else if (Info[4] == 0x1F)
					sprintf(szCurrent, "%s", "Reader current limitation = 400 mA");
				else if (Info[4] == 0x2F)
					sprintf(szCurrent, "%s", "Reader current limitation = 600 mA");
				else if (Info[4] == 0x3F)
					sprintf(szCurrent, "%s", "Reader current limitation = 800 mA");
				
				if (Info[5] == 0xFF)
					sprintf(szCurrent, "%s%s", szCurrent, ", Card current limitation = 200 mA\n");
				else if (Info[5] == 0x1F)
					sprintf(szCurrent, "%s%s", szCurrent, ", Card current limitation = 400 mA\n");
				else if (Info[5] == 0x2F)
					sprintf(szCurrent, "%s%s", szCurrent, ", Card current limitation = 600 mA\n");
				else if (Info[5] == 0x3F)
					sprintf(szCurrent, "%s%s", szCurrent, ", Card current limitation = 800 mA\n");
				
				
				//v1.0.2
				sprintf(szCommandDelay, "SD command delay = 0x%02x, data out delay = 0x%02x", Info[7]&0x0c, Info[6]);
				sprintf(szUHSControl, ", UHS control = 0x%02x", Info[7]&0x70);
				
				
				//check card speed
				if(Info[0]&BITMASK_DDR50)
				{
					if(bShowSpeed)
						sprintf(szMsg, "SD1(Read) >>> type: %s,    %dMHz, %s, %s\n", szSpeed, nClock, szVoltage, szSSC);
					else
						sprintf(szMsg, "SD1(Read) >>> type: DDR50,    %dMHz, %s, %s\n", nClock, szVoltage, szSSC);
				}
				else if(Info[0]&BITMASK_SDR50)
				{
					if(bShowSpeed)
						sprintf(szMsg, "SD1(Read) >>> type: %s,    %dMHz, %s, %s\n", szSpeed, nClock, szVoltage, szSSC);
					else
						sprintf(szMsg, "SD1(Read) >>> type: SDR50,    %dMHz, %s, %s\n", nClock, szVoltage, szSSC);
				}
				else if(Info[0]&BITMASK_SDR104)
				{
					if(bShowSpeed)
						sprintf(szMsg, "SD1(Read) >>> type: %s,    %dMHz, %s, %s\n", szSpeed, nClock, szVoltage, szSSC);
					else
						sprintf(szMsg, "SD1(Read) >>> type: SDR104,    %dMHz, %s, %s\n", nClock, szVoltage, szSSC);
				}
				else if( (Info[0]&0xFF) == 0x01)
				{
					if(bShowSpeed)
						sprintf(szMsg, "SD1(Read) >>> type: %s,    %dMHz, %s, %s\n", szSpeed, nClock, szVoltage, szSSC);
					else
						sprintf(szMsg, "SD1(Read) >>> type: 4-bit,    %dMHz, %s, %s\n", nClock, szVoltage, szSSC);
					
				}
				else if( (Info[0]&0xFF) == 0x02)
				{
					sprintf(szMsg, "SD1(Read) >>> type: 1-bit MMC,    %dMHz, %s, %s\n", nClock, szVoltage, szSSC);
				}
				else if( (Info[0]&0xFF) == 0x03)
				{
					sprintf(szMsg, "SD1(Read) >>> type: 4-bit MMC,    %dMHz, %s, %s\n", nClock, szVoltage, szSSC);
				}
				else if( (Info[0]&0xFF) == 0x04)
				{
					sprintf(szMsg, "SD1(Read) >>> type: 8-bit MMC,    %dMHz, %s, %s\n", nClock, szVoltage, szSSC);
				}
				else if( (Info[0]&0xFF) == 0x05)
				{
					sprintf(szMsg, "SD1(Read) >>> type: 1-bit,    %dMHz, %s, %s\n", nClock, szVoltage, szSSC);
				}
				else if( (Info[0]&0xFF) == 0x00)
				{
					bFindSD = FALSE;
					sprintf(szMsg, "SD1       >>> SD Card is not plugin\n");
					*pCardPluged = false;
				}
				[ListResult insertText:@"\n"];
				[ListResult insertText:@"\n"];
                [ListResult insertText:[NSString stringWithUTF8String:szMsg]];
				//[ListResult insertText:[[NSString alloc] initWithCString:szMsg]];
				if(bFindSD)
				{
                    [ListResult insertText:[NSString stringWithUTF8String:szCurrent]];
                    [ListResult insertText:[NSString stringWithUTF8String:szCommandDelay]];
                    [ListResult insertText:[NSString stringWithUTF8String:szUHSControl]];
					//[ListResult insertText:[[NSString alloc] initWithCString:szCurrent]];
					//[ListResult insertText:[[NSString alloc] initWithCString:szCommandDelay]];
					//[ListResult insertText:[[NSString alloc] initWithCString:szUHSControl]];
				}
				break;
				
						
				case SD1_INTERFACE_WRITE:
				//check card clock
				nClock = Info[3]&0xFF;
				if(nClock == 0)	
					nClock = 25;
				switch(nClock)
				{
					case 50:
						sprintf(szSpeed, "%s", "HS");
						bShowSpeed = true;
						break;
					case 25:
						sprintf(szSpeed, "%s", "DS");
						bShowSpeed = true;
						break;
					default:
						bShowSpeed = false;
						break;
				}
				
				//check voltage
				if(Info[0] & BITMASK_S18A)
					sprintf(szVoltage, "%s", "working at 1.8V");
				else
					sprintf(szVoltage, "%s", "working at 3.3V");
				
				
				//check SSC control
				if (Info[1] & SSC_CONTROL) 
					sprintf(szSSC, "%s", "SSC Enable");
				else 
					sprintf(szSSC, "%s", "SSC Disable");
				
				//check current limitation
				if (Info[4] == 0xFF)
					sprintf(szCurrent, "%s", "Reader current limitation = 200 mA");
				else if (Info[4] == 0x1F)
					sprintf(szCurrent, "%s", "Reader current limitation = 400 mA");
				else if (Info[4] == 0x2F)
					sprintf(szCurrent, "%s", "Reader current limitation = 600 mA");
				else if (Info[4] == 0x3F)
					sprintf(szCurrent, "%s", "Reader current limitation = 800 mA");
				
				if (Info[5] == 0xFF)
					sprintf(szCurrent, "%s%s", szCurrent, ", Card current limitation = 200 mA\n");
				else if (Info[5] == 0x1F)
					sprintf(szCurrent, "%s%s", szCurrent, ", Card current limitation = 400 mA\n");
				else if (Info[5] == 0x2F)
					sprintf(szCurrent, "%s%s", szCurrent, ", Card current limitation = 600 mA\n");
				else if (Info[5] == 0x3F)
					sprintf(szCurrent, "%s%s", szCurrent, ", Card current limitation = 800 mA\n");
				
				
				//v1.0.2
				sprintf(szCommandDelay, "SD command delay = 0x%02x, data out delay = 0x%02x", Info[7]&0x0c, Info[6]);
				sprintf(szUHSControl, ", UHS control = 0x%02x", Info[7]&0x70);
				
				//check card speed
				if(Info[0]&BITMASK_DDR50)
				{
					if(bShowSpeed)
						sprintf(szMsg, "SD1(Write) >>> type: %s,    %dMHz, %s, %s\n", szSpeed, nClock, szVoltage, szSSC);
					else
						sprintf(szMsg, "SD1(Write) >>> type: DDR50,    %dMHz, %s, %s\n", nClock, szVoltage, szSSC);
				}
				else if(Info[0]&BITMASK_SDR50)
				{
					if(bShowSpeed)
						sprintf(szMsg, "SD1(Write) >>> type: %s,    %dMHz, %s, %s\n", szSpeed, nClock, szVoltage, szSSC);
					else
						sprintf(szMsg, "SD1(Write) >>> type: SDR50,    %dMHz, %s, %s\n", nClock, szVoltage, szSSC);
				}
				else if(Info[0]&BITMASK_SDR104)
				{
					if(bShowSpeed)
						sprintf(szMsg, "SD1(Write) >>> type: %s,    %dMHz, %s, %s\n", szSpeed, nClock, szVoltage, szSSC);
					else
						sprintf(szMsg, "SD1(Write) >>> type: SDR104,    %dMHz, %s, %s\n", nClock, szVoltage, szSSC);
				}
				else if( (Info[0]&0xFF) == 0x01)
				{
					if(bShowSpeed)
						sprintf(szMsg, "SD1(Write) >>> type: %s,    %dMHz, %s, %s\n", szSpeed, nClock, szVoltage, szSSC);
					else
						sprintf(szMsg, "SD1(Write) >>> type: 4-bit,    %dMHz, %s, %s\n", nClock, szVoltage, szSSC);
					
				}
				else if( (Info[0]&0xFF) == 0x02)
				{
					sprintf(szMsg, "SD1(Write) >>> type: 1-bit MMC,    %dMHz, %s, %s\n", nClock, szVoltage, szSSC);
				}
				else if( (Info[0]&0xFF) == 0x03)
				{
					sprintf(szMsg, "SD1(Write) >>> type: 4-bit MMC,    %dMHz, %s, %s\n", nClock, szVoltage, szSSC);
				}
				else if( (Info[0]&0xFF) == 0x04)
				{
					sprintf(szMsg, "SD1(Write) >>> type: 8-bit MMC,    %dMHz, %s, %s\n", nClock, szVoltage, szSSC);
				}
				else if( (Info[0]&0xFF) == 0x05)
				{
					sprintf(szMsg, "SD1(Write) >>> type: 1-bit,    %dMHz, %s, %s\n", nClock, szVoltage, szSSC);
				}
				else if( (Info[0]&0xFF) == 0x00)
				{
					bFindSD = FALSE;
					sprintf(szMsg, "SD1        >>> SD Card is not plugin\n");
					*pCardPluged = false;
				}
			}
			else if([ScsiCmd m_DriveInfo:0].InquiryData.CardReaderChipID == INQ_ID_GL822)
			{
				if((Info[0]&0xFF) == 0x01)
					sprintf(szMsg, "SD1       >>> type: 4-bit SD");
				else if((Info[0]&0xFF) == 0x02)
					sprintf(szMsg, "SD1       >>> type: 1-bit MMC");
				else if((Info[0]&0xFF) == 0x03)
					sprintf(szMsg, "SD1       >>> type: 4-bit MMC");
				else if((Info[0]&0xFF) == 0x04)
					sprintf(szMsg, "SD1       >>> type: 8-bit MMC");
				else if((Info[0]&0xFF) == 0x05)
					sprintf(szMsg, "SD1       >>> type: 1-bit SD");
				else if((Info[0]&0xFF) == 0x00)
					sprintf(szMsg, "SD1       >>> SD Card is not plug in.\n");
				
			}
			
			[ListResult insertText:@"\n"];
			[ListResult insertText:@"\n"];
            [ListResult insertText:[NSString stringWithUTF8String:szMsg]];
			//[ListResult insertText:[[NSString alloc] initWithCString:szMsg]];
			if(bFindSD)
			{
                [ListResult insertText:[NSString stringWithUTF8String:szCurrent]];
                [ListResult insertText:[NSString stringWithUTF8String:szCommandDelay]];
                [ListResult insertText:[NSString stringWithUTF8String:szUHSControl]];
				//[ListResult insertText:[[NSString alloc] initWithCString:szCurrent]];
				//[ListResult insertText:[[NSString alloc] initWithCString:szCommandDelay]];
				//[ListResult insertText:[[NSString alloc] initWithCString:szUHSControl]];
			}
			break;
			
		case MS1_INTERFACE_READ:
			if((Info[0]&0xFF) == 0x01)
				sprintf(szMsg, "MS1       >>> type: 1-bit(serial)\n");
			else if((Info[0]&0xFF) == 0x02)
				sprintf(szMsg, "MS1       >>> type: 4-bit(parallel) MS/PRO\n");
			else if((Info[0]&0xFF) == 0x03)
				sprintf(szMsg, "MS1       >>> type: 8-bit MSPRO-HG\n");
			else if((Info[0]&0xFF) == 0x00)
				sprintf(szMsg, "MS1       >>> MS Card is not plug in.\n");
			[ListResult insertText:@"\n"];
			[ListResult insertText:@"\n"];
            [ListResult insertText:[NSString stringWithUTF8String:szMsg]];
			//[ListResult insertText:[[NSString alloc] initWithCString:szMsg]];
			break;
		
		case SD2_INTERFACE_READ:
			if((Info[0]&0xFF) == 0x01)
				sprintf(szMsg, "SD2       >>> type: 4-bit,   %dMHz\n", Info[3]&0xFF);
			else if((Info[0]&0xFF) == 0x02)
				sprintf(szMsg, "SD2       >>> type: 1-bit MMC,   %dMHz\n", Info[3]&0xFF);
			else if((Info[0]&0xFF) == 0x03)
				sprintf(szMsg, "SD2       >>> type: 4-bit MMC,   %dMHz\n", Info[3]&0xFF);
			else if((Info[0]&0xFF) == 0x04)
				sprintf(szMsg, "SD2       >>> type: 8-bit MMC,   %dMHz\n", Info[3]&0xFF);
			else if((Info[0]&0xFF) == 0x05)
				sprintf(szMsg, "SD2       >>> type: 1-bit,   %dMHz\n", Info[3]&0xFF);
			else if((Info[0]&0xFF) == 0x00)
				sprintf(szMsg, "SD2       >>> SD Card is not plug in.\n");
			[ListResult insertText:@"\n"];
			[ListResult insertText:@"\n"];
            [ListResult insertText:[NSString stringWithUTF8String:szMsg]];
			//[ListResult insertText:[[NSString alloc] initWithCString:szMsg]];
			break;
			
		case MS2_INTERFACE_READ:
			if((Info[0]&0xFF) == 0x01)
				sprintf(szMsg, "MS2       >>> type: 1-bit(serial)\n");
			else if((Info[0]&0xFF) == 0x02)
				sprintf(szMsg, "MS2       >>> type: 4-bit(parallel) MS/PRO\n");
			else if((Info[0]&0xFF) == 0x03)
				sprintf(szMsg, "MS2       >>> type: 8-bit MSPRO-HG\n");
			else if((Info[0]&0xFF) == 0x00)
				sprintf(szMsg, "MS2       >>> MS Card is not plug in.\n");
			[ListResult insertText:@"\n"];
			[ListResult insertText:@"\n"];
            [ListResult insertText:[NSString stringWithUTF8String:szMsg]];
			//[ListResult insertText:[[NSString alloc] initWithCString:szMsg]];
			break;
	}
	//[ListResult insertText:@"11 \n"];
	//[ListResult insertText:@"11 \n"];
	//[ListResult insertText:[[NSString alloc] initWithCString:szMsg]];
}

- (IBAction)PressGetMediaInfoButton:(id)sender {
	// BOOK Test
	
	[ListResult setString:@""];
	int i = 0, iLunCnt = 0;
	UInt8 MediaType = 0;
	UInt8 MediaTypeEx = 0;
	//UInt8 Info[6] = {0};
	UInt8 Info[8] = {0}; //v1.0.1
	
	//for get MediaInfo
	//BOOL    bCardPluged = false;
	
	iLunCnt = [ScsiCmd UstorCreateDeviceList:0 PID:0];
	
	if (iLunCnt == 0) 
	{
		[ListResult insertText:@"Can't find device\n"];
		return;
	}
	
	for (i = 0; i < iLunCnt; i++)
	{
		//if(iLunCnt > 1) break; //only support one device
		
		BOOL    bCardPluged = false;
		[ScsiCmd GetMediaType:(int)MEDIA_SUPPORT iLun:i Data:&MediaType];
		
		//if (Data == 0) [ScsiCmd GetMediaType:(int)MEDIA_CURRENT iLun:i Data:&Data];

		NSLog(@"MediaType =  0x%X", MediaType);
		
		//BOOL bShowSpeed = false;

		if([ScsiCmd m_DriveInfo:i].InquiryData.CardReaderChipID == INQ_ID_GL3220 || 
		   [ScsiCmd m_DriveInfo:i].InquiryData.CardReaderChipID == INQ_ID_GL3221)
		{
			switch(MediaType)
			{
				case CF_REPORT:
					[ScsiCmd GetMediaInfo:i Data:CF1_INTERFACE_READ MediaInfo:Info];
					[self HandleShowResult:CF1_INTERFACE_READ Data:Info CardPluged:&bCardPluged];
					break;
				case SD_REPORT:
					bCardPluged = true;
					[ScsiCmd GetMediaInfo:i Data:SD1_INTERFACE_READ MediaInfo:Info];
					NSLog(@"%02X", Info[3]&0xFF);
					[self HandleShowResult:SD1_INTERFACE_READ Data:Info CardPluged:&bCardPluged];
					
					if(bCardPluged)
					{
						[ScsiCmd GetMediaInfo:i Data:SD1_INTERFACE_WRITE MediaInfo:Info];
						[self HandleShowResult:SD1_INTERFACE_WRITE Data:Info CardPluged:&bCardPluged];
					}
					break;
				case MS_REPORT:
					[ScsiCmd GetMediaInfo:i Data:MS1_INTERFACE_READ MediaInfo:Info];
					[self HandleShowResult:MS1_INTERFACE_READ Data:Info CardPluged:&bCardPluged];
					break;
				case NO_MEDIA_REPORT:
					[ScsiCmd GetMediaType:(int)MEDIA_CURRENT iLun:i Data:&MediaTypeEx];
					NSLog(@"MediaTypeEx =  0x%X", MediaType);
					switch(MediaTypeEx)
					{
						case SD_REPORT:
						case MICRO_SD_REPORT:
							[ScsiCmd GetMediaInfo:i Data:SD2_INTERFACE_READ MediaInfo:Info];
							[self HandleShowResult:SD2_INTERFACE_READ Data:Info CardPluged:&bCardPluged];
							break;
						case MS_REPORT:
						case M2_REPORT:
							[ScsiCmd GetMediaInfo:i Data:MS2_INTERFACE_READ MediaInfo:Info];
							[self HandleShowResult:MS2_INTERFACE_READ Data:Info CardPluged:&bCardPluged];
							break;
						default:
							break;
						
					}
					break;
				default:
					break;
			}//END SWITCH
			//break;
		}
		else if([ScsiCmd m_DriveInfo:0].InquiryData.CardReaderChipID == INQ_ID_GL822)
		{
			switch(MediaType)
			{
				case NO_MEDIA_REPORT:
					[ScsiCmd GetMediaType:(int)MEDIA_CURRENT iLun:i Data:&MediaTypeEx];
					NSLog(@"MediaTypeEx =  0x%X", MediaType);
					switch(MediaTypeEx)
				{
					case SD_REPORT:
						[ScsiCmd GetMediaInfo:i Data:SD1_INTERFACE_READ MediaInfo:Info];
						[self HandleShowResult:SD1_INTERFACE_READ Data:Info CardPluged:&bCardPluged];
						break;
					case MS_REPORT:
						[ScsiCmd GetMediaInfo:i Data:MS1_INTERFACE_READ MediaInfo:Info];
						[self HandleShowResult:MS1_INTERFACE_READ Data:Info CardPluged:&bCardPluged];
						break;
					default:
						[ListResult setString:@"No media\n"];
						break;
						
				}
					break;
				default:
					break;
					
			}//END SWITCH
			break;
		}
		/*
		else
		{
			[btnGetInfo setEnabled:NO];
			[btnSend setEnabled:NO];
			[ListResult setString:@"Device not supported!\n"];
		}
		 */
		
	}
	
	for (i = 0; i < iLunCnt; i++)
	{
		IOObjectRelease([ScsiCmd parent:i]);
	}

	// BOOK Test
}

- (IBAction)PressSendButton:(id)sender { 
	
	[ListResult setString:@""];
	CURRENTSETTING	CurSetting = {0};
	SCSICMDBLK		CmdBlk ={0};
	int				nLunCnt = 0;
	UInt8			MediaType=0;
	int				i = 0;
	char			szClockRate[256]={0};		
	char			szCurrentLimitation[256]={0};
	char			szVoltage[256]={0};	
	char			szSSCControl[256] = {0};
	char			szMsg[256]={0};	
	memset(&CmdBlk, 0, sizeof(SCSICMDBLK));
	
	BOOL bFindSD = FALSE;
	
	[self InitCurrentSetting: &CurSetting];
	switch(CurSetting.nIndexOfClockRate)
	{
		case 0:
			CmdBlk.Cdb[1] = 0xFF;
			strcpy(szClockRate, "No limitation");
			break;
		case 1:
			CmdBlk.Cdb[1] = 0x80;
			strcpy(szClockRate, "PLL 25M");
			break;
		case 2:
			CmdBlk.Cdb[1] = 0x81;
			strcpy(szClockRate, "PLL 50M");
			break;
		case 3:
			CmdBlk.Cdb[1] = 0x82;
			strcpy(szClockRate, "PLL 75M");
			break;
		case 4:
			CmdBlk.Cdb[1] = 0x83;
			strcpy(szClockRate, "PLL 100M");
			break;
		case 5:
			CmdBlk.Cdb[1] = 0x84;
			strcpy(szClockRate, "PLL 120M");
			break;
		case 6:
			CmdBlk.Cdb[1] = 0x85;
			strcpy(szClockRate, "PLL 150M");
			break;
		default:
			break;
	}
	switch(CurSetting.nIndexOfCurrentLimination)
	{
		case 0:
			CmdBlk.Cdb[3] = 0x00;
			strcpy(szCurrentLimitation, "Not changed");
			break;
		case 1:
			CmdBlk.Cdb[3] = 0x01;
			strcpy(szCurrentLimitation, "200 mA");
			break;
		case 2:
			CmdBlk.Cdb[3] = 0x02;
			strcpy(szCurrentLimitation, "400 mA");
			break;
		case 3:
			CmdBlk.Cdb[3] = 0x03;
			strcpy(szCurrentLimitation, "600 mA");
			break;
		case 4:
			CmdBlk.Cdb[3] = 0x04;
			strcpy(szCurrentLimitation, "800 mA");
			break;
		default:
			break;
			
	}
	
	CmdBlk.Cdb[4] = (UInt8)CurSetting.nIndexOfDataDelay +
					(UInt8)(CurSetting.nIndexOfDataDelay << 2) +
					(UInt8)(CurSetting.nIndexOfDataDelay << 4) +
					(UInt8)(CurSetting.nIndexOfDataDelay << 6);
	
	//CmdBlk.Cdb[5] = (UInt8)((CurSetting.nIndexOfWriteCommandDelay << 2) + CurSetting.nIndexOfReadCommandDelay);
	CmdBlk.Cdb[5] = (UInt8)((CurSetting.nIndexOfWriteCommandDelay << 2));
	CmdBlk.Cdb[5] += (UInt8)(CurSetting.nIndexOfUHSControl << 4);
	
	
	
	CmdBlk.CdbLength = 10;
	CmdBlk.Direction = SCSI_NO_DATA;
	CmdBlk.TransferLength = 0;
	//CmdBlk.ReturnBytes = 0;
	
	CmdBlk.Cdb[0] = 0xF3;
	//memset(CmdBlk.DataBuffer, 0xcc, BUFFER_SIZE);
	
	nLunCnt = [ScsiCmd UstorCreateDeviceList:0 PID:0];
	
	if (nLunCnt == 0) 
	{
		[ListResult setString:@"Can't find device\n"];
		return;
	}
	
	for (i = 0; i < nLunCnt; i++)
	{
		//if(i > 0) break; //support one device only
		
		if([ScsiCmd m_DriveInfo:i].InquiryData.CardReaderChipID == INQ_ID_GL3220 || 
		   [ScsiCmd m_DriveInfo:i].InquiryData.CardReaderChipID == INQ_ID_GL3221)
		{
			switch(CurSetting.nIndexOfVoltage)
			{
				case VOLTAGE_V18:
					CmdBlk.Cdb[2] = 0x01;
					strcpy(szVoltage, "1.8V");
					break;
				case VOLTAGE_V33:
					CmdBlk.Cdb[2] = 0x00;
					strcpy(szVoltage, "3.3V");
					break;
			}
		
			switch (CurSetting.nIndexOfSSCControl) {
				case ENABLE_SSC:
					CmdBlk.Cdb[2] += 0xC0; //bit6 and bit7 is set to 1
					strcpy(szSSCControl, "Enable");
					break;
				case DISABLE_SSC:
					CmdBlk.Cdb[2] += 0x80; //bit6 =0, bit7 is 1
					strcpy(szSSCControl, "Disable");
				default:
					break;
			}
		
			//[ScsiCmd GetMediaType:(int)MEDIA_SUPPORT iLun:i Data:&MediaType];
			[ScsiCmd GetMediaType:(int)MEDIA_CURRENT iLun:i Data:&MediaType];
			
			if(MediaType == SD_REPORT)
			{
				NSLog(@"MediaType =  0x%X", MediaType);
				//MediaType = 0;
				//[ScsiCmd GetMediaType:(int)MEDIA_CURRENT iLun:i Data:&MediaType];
				//if(MediaType == SD_REPORT)
				if(1)
				{
					bFindSD = TRUE;
					if(![ScsiCmd UstorVendorScsiCmd:CmdBlk iLun:i])
						[ListResult insertText:@"Fail\n"];
					else
					{
						[ListResult insertText:@"*** Set Clock Rate & Current Limitation for SD ***\n"];
						
						sprintf(szMsg, "          -> Max SD card clock rate:    %s\n", szClockRate);
                        [ListResult insertText:[NSString stringWithUTF8String:szMsg]];
						//[ListResult insertText:[[NSString alloc] initWithCString:szMsg]];
						
						memset(szMsg, 0, sizeof(szMsg));
						sprintf(szMsg, "          -> SD card Current Limitation:    %s\n", szCurrentLimitation);
                        [ListResult insertText:[NSString stringWithUTF8String:szMsg]];
						//[ListResult insertText:[[NSString alloc] initWithCString:szMsg]];
						
						[ListResult insertText:@"*** Set SD UHS-I card voltage signal level ***\n"];
							
						memset(szMsg, 0, sizeof(szMsg));
						sprintf(szMsg, "          -> Switch to %s\n", szVoltage);
                        [ListResult insertText:[NSString stringWithUTF8String:szMsg]];
						//[ListResult insertText:[[NSString alloc] initWithCString:szMsg]];
						
						[ListResult insertText:@"*** SSC Control ***\n"];

						memset(szMsg, 0, sizeof(szMsg));
						sprintf(szMsg, "          -> %s\n", szSSCControl);
                        [ListResult insertText:[NSString stringWithUTF8String:szMsg]];
						//[ListResult insertText:[[NSString alloc] initWithCString:szMsg]];
						
												
						[ListResult insertText:@"*** SD command delay ***\n"];
						//sprintf(szMsg, "          -> OUT = %d, IN = %d\n", CurSetting.nIndexOfWriteCommandDelay, CurSetting.nIndexOfReadCommandDelay);
						sprintf(szMsg, "          -> %d\n", CurSetting.nIndexOfWriteCommandDelay);
                        [ListResult insertText:[NSString stringWithUTF8String:szMsg]];
						//[ListResult insertText:[[NSString alloc] initWithCString:szMsg]];
						
						[ListResult insertText:@"*** SD Data out delay ***\n"];
						sprintf(szMsg, "          -> %d\n", CurSetting.nIndexOfDataDelay);
                        [ListResult insertText:[NSString stringWithUTF8String:szMsg]];
						//[ListResult insertText:[[NSString alloc] initWithCString:szMsg]];
						
						[ListResult insertText:@"*** UHS Control ***\n"];
						sprintf(szMsg, "          -> %d\n", CurSetting.nIndexOfUHSControl);
                        [ListResult insertText:[NSString stringWithUTF8String:szMsg]];
						//[ListResult insertText:[[NSString alloc] initWithCString:szMsg]];
						
						[ListResult insertText:@"\n\n"];
						[ListResult insertText:@"Success!!\n"];
					}
					
				}
				//else
				//	[ListResult insertText:@"Can't find SD card\n"];
					
				break;
				//continue;
			}
			else
			{
			//	[ListResult insertText:@"Can't find SD card\n"];
				continue;
			}
			
			
		}
		else if([ScsiCmd m_DriveInfo:i].InquiryData.CardReaderChipID == INQ_ID_GL822)
		{
			[ScsiCmd GetMediaType:(int)MEDIA_CURRENT iLun:i Data:&MediaType];
			
			if(MediaType == SD_REPORT)
			{
				bFindSD = TRUE;
				NSLog(@"MediaType =  0x%X", MediaType);
				if(1)
				{
					if(![ScsiCmd UstorVendorScsiCmd:CmdBlk iLun:i])
						[ListResult insertText:@"Fail\n"];
					else
					{
						[ListResult insertText:@"*** Set Clock Rate & Current Limitation for SD ***\n"];
						
						sprintf(szMsg, "          -> Max SD card clock rate:    %s\n", szClockRate);
                        [ListResult insertText:[NSString stringWithUTF8String:szMsg]];
						//[ListResult insertText:[[NSString alloc] initWithCString:szMsg]];
						
						memset(szMsg, 0, sizeof(szMsg));
						sprintf(szMsg, "          -> SD card Current Limitation:    %s\n", szCurrentLimitation);
                        [ListResult insertText:[NSString stringWithUTF8String:szMsg]];
						//[ListResult insertText:[[NSString alloc] initWithCString:szMsg]];
						
						[ListResult insertText:@"\n\n"];
						[ListResult insertText:@"Success!!\n"];
					}
					
				}
				break;
				
			}
			else
			{
				//[ListResult insertText:@"Can't find SD card\n"];
				continue;
			}
		}
		/*
		else
		{
			[btnGetInfo setEnabled:NO];
			[btnSend setEnabled:NO];
			[ListResult setString:@"Device not supported!\n"];
		}
		*/
	}
	
	if (!bFindSD) {
		[ListResult insertText:@"Can't find SD card\n"];
	}
	
	for (i = 0; i < nLunCnt; i++)
	{
		IOObjectRelease([ScsiCmd parent:i]);
	}
	
	//int i = [ radioVoltage selectedCells];
	//NSLog(@"test, %d", [radioVoltageOne state]);
	//NSLog(@"test, %d", [radioVoltageTwo state]);
	
	//char szMsg[] = "1111111";
	//NSString *test = [[NSString alloc] initWithCString:szMsg];
	//[ListResult insertText:test];
	//[ListResult insertText:@"1111"];
}


-(void)InitCurrentSetting:(PCURRENTSETTING)pCurSetting
{
	pCurSetting->nIndexOfClockRate = [combleSelClockRate indexOfSelectedItem];
	pCurSetting->nIndexOfCurrentLimination = [combleSelCurLimination indexOfSelectedItem];
	
	//pCurSetting->nIndexOfReadCommandDelay = [comboSelReadCommandDelay indexOfSelectedItem];
	pCurSetting->nIndexOfWriteCommandDelay = [comboSelWriteCommandDelay indexOfSelectedItem];
	pCurSetting->nIndexOfDataDelay = [comboSelSDDataOutDelay indexOfSelectedItem];
	pCurSetting->nIndexOfUHSControl = [comboSelUHSControl indexOfSelectedItem]+1;


	if([radioVoltageOne state])
		pCurSetting->nIndexOfVoltage = VOLTAGE_V18;
	else
		pCurSetting->nIndexOfVoltage = VOLTAGE_V33;
	
	if ([radioEnableSSC state])
		pCurSetting->nIndexOfSSCControl = ENABLE_SSC;
	else
		pCurSetting->nIndexOfSSCControl = DISABLE_SSC;

}

- (IBAction)PressRefreshButton:(id)sender
{
	[self RefreshUI];
}

@end
