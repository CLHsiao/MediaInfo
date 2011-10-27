/*
 *  Define.h
 *  GL3310UpdateFWTool
 *
 *  Created by CHIEN NICK on 2011/3/8.
 *  Copyright 2011 __MyCompanyName__. All rights reserved.
 *
 */

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>

//The key of dictionary
#define kMyPropertyKey "MyProperty"

#define BUFFER_SIZE	512
#define CDB_SIZE	16


#define COMPARE_FAIL       0
#define COMPARE_SUCCESS    1
#define DO_NOTHING		   2

#define GL3310_FLASH_NUM		7
#define CHECK_FLASH_LOOP_CNT	10
#define ID_EON					0
#define ID_SST					1
#define ID_PMC					2
#define ID_ST					3
#define ID_WINBON				4
#define ID_MXIC					5
#define ID_OTHER				6

#define SEND_VENDOR_ERASE		0
#define SEND_WRITE_ENABLE		1

#define MAX_SN_SIZE				33

#define GL3310_EEP_LENGTH			0x0060
#define GL3310_FW_LENGTH			0xC000
#define GL3310_EEP_START_ADDRESS	0xBE10

#define GL3311_EEP_LENGTH			0x0100
#define GL3311_FW_LENGTH			0x2000
#define GL3311_EEP_START_ADDRESS	0x0000

#define GL3220_EEP_LENGTH			0x0040
#define GL3220_FW_LENGTH			0x10000
#define GL3220_EEP_START_ADDRESS	0xBF80

#define GL3221_EEP_LENGTH			0x0040
#define GL3221_FW_LENGTH			0x10000
#define GL3221_EEP_START_ADDRESS	0xBF80

#define INQ_VENDOR_LEN			4
#define INQ_PRODUCT_LEN			8

typedef struct
{
	UInt8 Direction;
#define	SCSI_NO_DATA	0
#define	SCSI_DATA_OUT	1
#define	SCSI_DATA_IN	2
	
	UInt8 CdbLength;
	UInt8 Cdb[CDB_SIZE];
	UInt32 TransferLength;
	UInt8  DataBuffer[BUFFER_SIZE];
	UInt8  ReturnBytes;
	UInt8  DeviceIOControl;
}SCSICMDBLK, *PSCSICMDBLK;


#define PASSWORD_SIZE		8
#define MAX_CARD_TYPE		8
#define CARD_STR_LEN		8
#define NEW_ADD_NUMBER		64
typedef struct _FROM_EEP
{
	// BYTE MaxPower;
	UInt16 Vid;
	UInt16 Pid;
	UInt8 MaxPower;
	UInt8 Config;
	
	char VendorStr[64];
	char ProductStr[64];
	char InterfaceStr[64];
	char SerialStr[64];	
	char Password[PASSWORD_SIZE];
	// 811
	UInt16 AtaPid;
	UInt16 AtapiPid;	
	UInt8 InitDelay;
	UInt8 Config2;
	// 813
	UInt8 PIODecrease;
	UInt8 CFDisconnect;
	// 816
	UInt8 MediaInDrv;
	UInt8 LunPerDev;
	UInt8 MediaInLun[6];
	char CardStr[MAX_CARD_TYPE][CARD_STR_LEN];
	// 820, 813
	char InqVendorStr[64];
	char InqProductStr[64];
	// 830
	UInt8 Amp15G;
	UInt8 Amp30G;
	UInt8 WatchDog;
	
	//GL830, G15
	UInt8 Config3;
	
	//GL3310
	UInt8 LedU3;
	UInt8 LedU2;
	UInt8 Config1;
	UInt8 MaxPowerU2;
	UInt8 MaxPowerU3;
	UInt8 Reserve;
	UInt8 Reserve2;
	UInt8 Reserve3;
	
	//extended
	UInt16 NewAdd[NEW_ADD_NUMBER]; 
	int	 nCheckSumIndex;
	
	//GL3220
	UInt16 wConfig;
	
}FROM_EEP, *PFROM_EEP;


typedef struct {
	UInt8 DevType;
	UInt8 DevTypeModifier;
#define	REMOVABLE	0x80
	
	UInt8 ScsiVersion;
	UInt8 DataFormat;
	UInt8 AdditionLen;
	UInt8 Reserved1;
	UInt8 Reserved2;
	UInt8 Option;
	char VendorId[8];
	char ProductId[16];
	char FwRev[4];
	
	// The VID/PID reported in INQUIRY Data.
	// This field may not be valid for non-standard GL device.
	// Program should access DRIVE_INFO_COMMON.Vid & DRIVE_INFO_COMMON.Pid to get the actual VID/PID.
	UInt8 USBVID[2];
	UInt8 USBPID[2];
	
	char GeneId[4];				// "GENE" for standard Genesys Logic USB storage device
	
	UInt8 UFDChipID;			// Chip ID for UFD, SATA
#define	INQ_ID_GL820		1
#define	INQ_ID_GL814		2
#define	INQ_ID_GL811S		3
#define	INQ_ID_GL820E		4
#define	INQ_ID_GL815		5
#define	INQ_ID_GL824		6
#define	INQ_ID_GL830		7
#define INQ_ID_GL815U		0x40
#define INQ_ID_GL815F		0x41
#define INQ_ID_GL3310		0x42
#define INQ_ID_GL815C		0x43
#define INQ_ID_GL815C8		0x44
#define INQ_ID_GL825C		0x45
#define INQ_ID_GL3100		0x46
#define INQ_ID_GL3311		0x47
#define INQ_ID_GL3320		0x4A
#define	MULTI_LUN			0x08
	
	UInt8 CardReaderChipID;		// Chip ID for card reader
#define	INQ_ID_GL816		0x01
#define	INQ_ID_GL816E		0x02
#define	INQ_ID_GL819		0x03
#define	INQ_ID_GL816S		0x04
#define	INQ_ID_GL821		0x05
#define	INQ_ID_GL827		0x06
#define	INQ_ID_GL819E		0x07
#define	INQ_ID_GL819S		0x08
#define	INQ_ID_GL826		0x09
#define	INQ_ID_GL837		0x0A
#define	INQ_ID_GL827L		0x0B
#define	INQ_ID_GL827S		0x0C
#define INQ_ID_GL824K		0x0D
#define INQ_ID_GL895		0x0E
#define INQ_ID_GL823		0x0F
#define INQ_ID_GL836		0x10
#define INQ_ID_GL827L_FLASH	0x11
#define INQ_ID_GL822		0x12
#define INQ_ID_GL838		0x13
#define INQ_ID_GL839		0x14
#define INQ_ID_GL3220		0x16
#define INQ_ID_GL823_UFD	0x17
#define INQ_ID_GL180		0x18
#define INQ_ID_GL823E		0x19
#define INQ_ID_GL3221		0x1A
	
} INQUIRY_DATA, *PINQUIRY_DATA;

typedef struct _SENSE_INFO
{
	UInt8	ResponseCode;
	UInt8	SegmentNumber;
	UInt8	SenseKey;
	UInt8	Information[4];
	UInt8	AdditionalLength;
	UInt8	CommandSpecific[4];
	UInt8	AdditionalSenseCode;
	UInt8	AdditionalSenseCodeQualifier;
	UInt8	UnitCode;
	UInt8	SenseKeySpecific[3];
	UInt8	AdditionalSense[0];
} SENSE_INFO, *PSENSE_INFO;


//-----------------------------------------------------------------------------
// EEPROM information
//-----------------------------------------------------------------------------
typedef union {
	BOOL EepValid;
	
	// Following field is valid only if EepValid == TRUE.
	// For Card reader, please use GL816 
	struct {
		BOOL EepValid;
		UInt16 Vid;
		UInt16 AtaPid;
		UInt16 AtapiPid;
		UInt8 MaxPower;
		UInt8 InitDelay;
		UInt8 Config;
		UInt8 Config2;
		UInt8 Config3;
		UInt8 Amp15G;
		UInt8 Amp30G;
		UInt8 WatchDog;
		char VendorStr[64];
		char ProductStr[64];
		char InterfaceStr[64];
		char SerialStr[64];
		char InqVendorStr[64];
		char InqProductStr[64];
	} GL830;
	
	struct {
		BOOL EepValid;
		UInt16 Vid;
		UInt16 AtaPid;
		UInt16 AtapiPid;
		UInt8 MaxPowerU2;
		UInt8 MaxPowerU3;
		UInt8 InitDelay;
		UInt8 Config1;
		UInt8 Config2;
		UInt8 Config3;
		UInt8 Amp15G;
		UInt8 Amp30G;
		UInt8 WatchDog;
		UInt8 LedU3;
		UInt8 LedU2;
		UInt8 Reserved;
		UInt8 Reserved2;
		UInt8 Reserved3;
		UInt16 NewAdd[NEW_ADD_NUMBER];
		int  nCheckSumIndex;
		char VendorStr[64];
		char ProductStr[64];
		char InterfaceStr[64];
		char SerialStr[64];
		char InqVendorStr[64];
		char InqProductStr[64];
	} GL3320;
	
	struct {
		BOOL EepValid;
		UInt16 Vid;
		UInt16 AtaPid;
		UInt16 AtapiPid;
		UInt8 MaxPowerU2;
		UInt8 MaxPowerU3;
		UInt8 InitDelay;
		UInt8 Config1;
		UInt8 Config2;
		UInt8 Config3;
		UInt8 Amp15G;
		UInt8 Amp30G;
		UInt8 WatchDog;
		UInt8 LedU3;
		UInt8 LedU2;
		UInt8 Reserved;
		UInt8 Reserved2;
		UInt8 Reserved3;
		UInt16 NewAdd[NEW_ADD_NUMBER];
		int  nCheckSumIndex;
		char VendorStr[64];
		char ProductStr[64];
		char InterfaceStr[64];
		char SerialStr[64];
		char InqVendorStr[64];
		char InqProductStr[64];
	} GL3310;
	
	struct {
		BOOL EepValid;
		UInt16 Vid;
		UInt16 Pid;
		UInt8 MaxPower;
		UInt8 MediaInDrv;
		UInt8 LunPerDev;
		UInt8 Config;
		UInt8 MediaInLun[6];
		char VendorStr[64];
		char ProductStr[64];
		char InterfaceStr[64];
		char SerialStr[64];
		char CardStr[MAX_CARD_TYPE][CARD_STR_LEN];
	} GL816;
	
	struct {
		BOOL EepValid;
		UInt16 Vid;
		UInt16 Pid;
		UInt8 MaxPower;
		UInt8 MediaInDrv;
		UInt8 LunPerDev;
		UInt8 Config;
		UInt8 MediaInLun[6];
		char VendorStr[64];
		char ProductStr[64];
		char InterfaceStr[64];
		char SerialStr[64];
		UInt16 wConfig;
		UInt8 bReserved;
		char CardStr[MAX_CARD_TYPE][CARD_STR_LEN];
	} GL3220;
	
} EEP_DATA, *PEEP_DATA;

typedef struct _DRIVE_INFO_COMMON
{
	INQUIRY_DATA InquiryData;
	EEP_DATA	 EEPData;
}DRIVE_INFO_COMMON, *PDRIVE_INFO_COMMON;




