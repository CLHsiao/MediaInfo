#import <Cocoa/Cocoa.h>
#import "SCSICmd.h"

#define	VOLTAGE_V18		0
#define	VOLTAGE_V33		1

#define ENABLE_SSC		1
#define DISABLE_SSC		0
@interface MediaInfo : NSObject {
    IBOutlet id ListResult;
    IBOutlet id combleSelClockRate;
    IBOutlet id combleSelCurLimination;
	//IBOutlet id comboSelReadCommandDelay;
	IBOutlet id comboSelWriteCommandDelay;
	IBOutlet id comboSelSDDataOutDelay;
	IBOutlet id comboSelUHSControl;
    IBOutlet id radioVoltageOne;
	IBOutlet id radioVoltageTwo;
	IBOutlet id radioVoltage;
	IBOutlet id radioEnableSSC;
	IBOutlet id radioDisableeSSC;
	IBOutlet id btnGetInfo;
	IBOutlet id btnSend;
	SCSICmd *ScsiCmd;
}
- (IBAction)PressExitButton:(id)sender;
- (IBAction)PressGetMediaInfoButton:(id)sender;
- (IBAction)PressSendButton:(id)sender;
- (IBAction)PressRefreshButton:(id)sender;
- (void) HandleShowResult:(UInt8)CardType Data:(UInt8 *)Info CardPluged:(BOOL *)pCardPluged;
- (BOOL) RefreshUI;

typedef struct
{
	int nIndexOfClockRate;
	int nIndexOfCurrentLimination;
	int nIndexOfVoltage;
	int nIndexOfSSCControl;
	
	//int nIndexOfReadCommandDelay;
	int nIndexOfWriteCommandDelay;
	int nIndexOfDataDelay;
	int nIndexOfUHSControl;
}CURRENTSETTING, *PCURRENTSETTING;
-(void)InitCurrentSetting:(PCURRENTSETTING)pCurSetting;
@end
