// Credits to https://github.com/guoxuzan/IOKit for documentation of IOKit headers
// https://iphonedev.wiki/index.php/IOKit.framework and https://github.com/julioverne/BattRate/blob/main/battratehooks/Tweak.xm
// for usage examples

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <IOKit/IOKitLib.h>


@interface SBFTouchPassThroughView : UIView
@end

@interface CSCoverSheetViewBase : SBFTouchPassThroughView
@end
@interface CSBatteryChargingView : CSCoverSheetViewBase
@end

@interface _CSSingleBatteryChargingView : CSBatteryChargingView

-(void)setBatteryVisible:(BOOL)arg1 ;
-(id)initWithFrame:(CGRect)arg1 ;
-(void) viewDidDisappear;
- (void)removeFromSuperview;
- (void)layoutSubviews;
@end



@interface _UIStatusBarDataEntry : NSObject
@end

@interface _UIStatusBarDataBatteryEntry : _UIStatusBarDataEntry {

	BOOL _saverModeActive;
	BOOL _prominentlyShowsDetailString;
	long long _capacity;
	long long _state;
	NSString* _detailString;
}
@property (assign,nonatomic) long long capacity;                             //@synthesize capacity=_capacity - In the implementation block
@property (assign,nonatomic) long long state;                                //@synthesize state=_state - In the implementation block
@property (assign,nonatomic) BOOL saverModeActive;                           //@synthesize saverModeActive=_saverModeActive - In the implementation block
@property (assign,nonatomic) BOOL prominentlyShowsDetailString;              //@synthesize prominentlyShowsDetailString=_prominentlyShowsDetailString - In the implementation block
@property (nonatomic,copy) NSString * detailString;                          //@synthesize detailString=_detailString - In the implementation block
+(BOOL)supportsSecureCoding;
-(long long)capacity;
-(void)setCapacity:(long long)arg1 ;
-(unsigned long long)hash;
-(id)initWithCoder:(id)arg1 ;
-(NSString *)detailString;
-(void)encodeWithCoder:(id)arg1 ;
-(void)setSaverModeActive:(BOOL)arg1 ;
-(void)setDetailString:(NSString *)arg1 ;
-(BOOL)prominentlyShowsDetailString;
-(void)setState:(long long)arg1 ;
-(long long)state;
-(BOOL)isEqual:(id)arg1 ;
-(id)_ui_descriptionBuilder;
-(BOOL)saverModeActive;
-(void)setProminentlyShowsDetailString:(BOOL)arg1 ;
-(id)copyWithZone:(NSZone*)arg1 ;
@end


@interface SBUILegibilityLabel : UIView
@property (assign,nonatomic) long long numberOfLines; 
-(void)setString:(NSString *)arg1 ;
@end


@interface BCBatteryDeviceController : NSObject 

@property (nonatomic,copy,readonly) NSArray * connectedDevices; 
@property (readonly) unsigned long long hash; 
@property (readonly) Class superclass; 
@property (copy,readonly) NSString * description; 
@property (copy,readonly) NSString * debugDescription; 
+(id)sharedInstance;
+(id)_sharedPowerSourceController;
-(id)init;
-(NSArray *)connectedDevices;
-(void)addBatteryDeviceObserver:(id)arg1 queue:(id)arg2 ;
-(void)removeBatteryDeviceObserver:(id)arg1 ;
//-(void)connectedDevicesWithResult:(/*^block*/id)arg1 ;
@end

@interface BCBatteryDevice : NSObject
@property (assign,nonatomic) long long percentCharge; 
@property (assign,nonatomic) long long powerSourceState;
@property (assign,nonatomic) long long transportType; 
@property (assign,nonatomic) unsigned long long parts;    
@property (nonatomic,copy) NSString * accessoryIdentifier;     
@property (nonatomic,copy) NSString * modelNumber;    
@end


// Use IOKit framework to get power source information
static NSDictionary* getBattDict()
{
	CFMutableDictionaryRef powerSource = IOServiceMatching("IOPMPowerSource");
	io_service_t service = IOServiceGetMatchingService(kIOMasterPortDefault, powerSource);

	CFMutableDictionaryRef prop = NULL;
	IORegistryEntryCreateCFProperties(service,&prop,0,0);

	return prop ? ((NSDictionary*) CFBridgingRelease(prop)) : nil;
}

%hook _CSSingleBatteryChargingView

- (void)layoutSubviews
{

	%orig;



	SBUILegibilityLabel* chargeLabel = MSHookIvar<SBUILegibilityLabel*>(self,"_chargePercentLabel");
	if (!chargeLabel) return;


	dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t) (0.75*NSEC_PER_SEC)), dispatch_get_main_queue(),
	^{
	// Use Battery Center Framework to obtain basic battery info
		BCBatteryDeviceController* battController = [BCBatteryDeviceController sharedInstance];
		if (!battController) return;

		BCBatteryDevice* dev = battController.connectedDevices[0];
		if (!dev) return;


		long long percentCharge = dev.percentCharge;


		NSLog(@"[senzuBeans] async execute");
		// Do IOKit magic here
		NSDictionary* battDict = getBattDict();
		if (!battDict) return;
		
		NSDictionary* adapterDict = battDict[@"AdapterDetails"];

		//float Current = [adapterDict[@"Current"] floatValue]/1000;
		//float Voltage = [adapterDict[@"Voltage"] floatValue]/1000;

		int Watts = [adapterDict[@"Watts"] intValue];
		NSMutableString* frmtString = [NSMutableString stringWithFormat: @"%lld%% Charged",percentCharge];
		NSString* secondFrmtString = [NSString stringWithFormat: @" (%dW)",Watts];
		if (Watts >= 20) 
		{
			[frmtString appendString: @"\nSuper Fast Charging"];
			[frmtString appendString: secondFrmtString];

			chargeLabel.numberOfLines++;
			[chargeLabel sizeToFit];
		
		}
		else if (Watts > 5)
		{
			[frmtString appendString: @"\nFast Charging"];
			[frmtString appendString: secondFrmtString];

			chargeLabel.numberOfLines++;
			[chargeLabel sizeToFit];

		}

		
		/*
		for (NSString* key in battDict)
		{
			NSString* newFrmt = [NSString stringWithFormat:@"\n%@: %@",key, battDict[key]];
			[frmtString appendString: newFrmt];
			chargeLabel.numberOfLines++;
		}
		*/
		[ UIView transitionWithView: chargeLabel
			duration:0.25f
			options:UIViewAnimationOptionTransitionCrossDissolve
			animations: ^{
			[chargeLabel setString: (NSString* )frmtString];
			}
			completion: nil
		];
		}
	);
}

%end 

%hook _UIStatusBarDataBatteryEntry
-(void)setDetailString:(NSString *)arg1
{
	NSDictionary* battDict = getBattDict();
	arg1 = [NSString stringWithFormat: @"%@W %@mA %lld%%",
										battDict[@"AdapterDetails"][@"Watts"],battDict[@"InstantAmperage"],self.capacity];
	%orig;
}
%end