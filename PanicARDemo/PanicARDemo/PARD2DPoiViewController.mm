//
//  MyARViewController.mm
//  PanicARDemo
//  A basic example of UIKit-driven rendering of Points of Interest
//  POIs are automatically layouted and stacked
//
//  Created by Andreas Zeitler on 16.10.11.
//  Copyright (c) 2011 doPanic. All rights reserved.
//

#import "PARD2DPoiViewController.h"

// Timer to regularly update GPS information
static NSTimer *infoTimer = nil;
bool _areOptionsVisible = false;


@implementation PARD2DPoiViewController {
    // stillImageOutput for Screenshot functionality
    AVCaptureStillImageOutput * _stillImageOutput;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // set view controller properties and create Options button
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Options" style:UIBarButtonItemStyleBordered target:self action:@selector(showOptions:)];
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView
{
    // IMPORTANT: set Api Key before calling super:loadView!
    [[PARController sharedARController] setApiKey:@""];
    [[PARController sharedARController] setDelegate:self];
    
    [super loadView];
    
    //set range of radar, all POIs farther away than 1500 meters will appear on the edge of the radar
    [self.arRadarView setRadarRange:1500];
    
    [self cameraCaptureSession];
}



// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationController.navigationBar.barStyle = UIBarStyleBlackTranslucent;

    // ensure infoLabels are sorted correctly (storyboard workaround)
    self.infoLabels = [self.infoLabels sortedArrayUsingComparator:^NSComparisonResult(UIView *label1, UIView *label2) {
        if ([label1 tag] < [label2 tag]) return NSOrderedAscending;
        else if ([label1 tag] > [label2 tag]) return NSOrderedDescending;
        else return NSOrderedSame;
    }];
    
    
    // setup AR manager properties
    [[[self sensorManager] locationManager] setDesiredAccuracy:kCLLocationAccuracyBestForNavigation];
    
    // create AR POIs
    [self createARPoiObjects];
}


- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewDidAppear:(BOOL)animated {
    // check, if device supports AR everytime the view appears
    // if the device currently does not support AR, show standard error alerts
    [PARController deviceSupportsAR:YES];
    
    [super viewDidAppear:animated];
    infoTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateInfoLabel) userInfo:nil repeats:YES];
    
    // setup radar
        CGRect rect = CGRectMake(0.0f, 0.0f, 0.0f, 45.0f);
    _radarThumbnailPosition = PARRadarPositionBottomRight;
    [self.arRadarView setRadarToThumbnail:_radarThumbnailPosition withAdditionalOffset:rect];
    [self.arRadarView showRadar];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
    [infoTimer invalidate];
    infoTimer = nil;
}


#pragma mark - AR Config

// Configure the ARView
- (BOOL)usesCameraPreview {
    return YES;
}
- (BOOL)fadesInCameraPreview {
    return NO;
}
- (BOOL)rotatesARView {
    return YES;
}

// Define, what happens if you hold the device horizontally, with the face upwards
- (void)switchFaceUp:(BOOL)inFaceUp {
    if (inFaceUp) {
        // Offset of 120.0f fits quite nice fore the ios7 nav bar and tool bar
        [self.arRadarView setRadarToFullscreen:CGPointMake(0.0f, 0.0f) withSizeOffset:120.0f];
    }
    else {
        CGRect rect = CGRectMake(0.0f, 0.0f, 0.0f, 45.0f);
        _radarThumbnailPosition = PARRadarPositionBottomRight;
        [self.arRadarView setRadarToThumbnail:_radarThumbnailPosition withAdditionalOffset:rect];

    }
}


#pragma mark - PARControllerDelegate

- (void)arDidTapObject:(id<PARObjectDelegate>)object {
    [PARController showAlert:@"Tap"
                 withMessage:[NSString stringWithFormat:@"Label tapped: %@", object.title]
            andDismissButton:@"Okay"];
}

#pragma mark - PSKSensorDelegate
- (void)didReceiveErrorCode:(int)code {
    [self updateInfoLabel];
    
}

- (void)didUpdateLocation:(CLLocation *)newLocation {
    CLLocation* l = [[self deviceAttitude] location];
    CLLocationCoordinate2D c = [l coordinate];
    
    UILabel *_locationLabel = [_infoLabels objectAtIndex:1];
    _locationLabel.hidden = NO;
    UILabel *_locationDetailsLabel = [_infoLabels objectAtIndex:2];
    _locationDetailsLabel.hidden = NO;
    
    _locationLabel.text = [NSString stringWithFormat:@"%.4f° %.4f° %.2fm", c.latitude, c.longitude, l.altitude];
    _locationDetailsLabel.text = [NSString stringWithFormat:@"±%.2fm ±%.2fm", l.horizontalAccuracy, l.verticalAccuracy];
}

- (void)didUpdateHeading:(CLHeading *)newHeading {
    UILabel *_headingLabel = [_infoLabels objectAtIndex:3];
    _headingLabel.hidden = NO;
    UILabel *_headingDetailsLabel = [_infoLabels objectAtIndex:4];
    _headingDetailsLabel.hidden = NO;
    
    _headingLabel.text = [NSString stringWithFormat:@"%.2f°", [[self deviceAttitude] heading]];
    _headingDetailsLabel.text = [NSString stringWithFormat:@"±%.2f", [[self deviceAttitude] headingAccuracy]];
}

- (void)didChangeSignalQuality:(PSKSignalQuality)newSignalQuality {
    switch (newSignalQuality) {
        case PSKSignalQualityBest:
            _signalDisplay.image = [UIImage imageNamed:@"signal4.png"];
            break;
        case PSKSignalQualityOkay:
            _signalDisplay.image = [UIImage imageNamed:@"signal3.png"];
            break;
        case PSKSignalQualityMedium:
            _signalDisplay.image = [UIImage imageNamed:@"signal2.png"];
            break;
        case PSKSignalQualityBad:
            _signalDisplay.image = [UIImage imageNamed:@"signal1.png"];
            break;
            
        default:
            _signalDisplay.image = [UIImage imageNamed:@"signal0.png"];
            break;
    }
    
    // optionally: hide GPS meter if signal is fine
    _signalDisplay.hidden = NO;
    
    if (newSignalQuality < PSKSignalQualityBad) {
        if (!_signalDisplay.hidden) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                _signalDisplay.hidden = YES;
            });
        }
    }
}


#pragma mark - Instance Methods

- (void)updateInfoLabel {
    PSKDeviceAttitude *deviceAttitude = [[PSKSensorManager sharedSensorManager] deviceAttitude];
    
    UILabel *_infoLabel = [_infoLabels objectAtIndex:0];
    NSString *display = nil;
    if (![deviceAttitude hasLocation]) {
        _infoLabel.textColor = [UIColor redColor];
        display = @"could not retrieve location";
    }
    else {
        display = [NSString stringWithFormat:@"GPS signal quality: %.1d (~%.1f Meters)", [deviceAttitude signalQuality], [deviceAttitude locationAccuracy]];
        _infoLabel.textColor = [UIColor whiteColor];
    }
    
    _infoLabel.text = [display stringByAppendingFormat:@"\nTracking: Gyroscope (iOS 5): y:%+.4f, p:%+.4f, r:%+.4f", [deviceAttitude attitudeYaw], [deviceAttitude attitudePitch], [deviceAttitude attitudeRoll]];
}


#pragma mark - Actions

- (IBAction)radarButtonAction {
    CGRect rect = CGRectMake(0, 44, 0, 0);
    if (!self.arRadarView.isRadarVisible || self.arRadarView.radarMode == PARRadarOff) {
        _radarThumbnailPosition = PARRadarPositionTopLeft;
        [self.arRadarView setRadarToThumbnail:_radarThumbnailPosition withAdditionalOffset:rect];
        [self.arRadarView showRadar];
    }
    else if (self.arRadarView.radarMode == PARRadarThumbnail) {
        if (_radarThumbnailPosition == PARRadarPositionTopLeft) {
            _radarThumbnailPosition = PARRadarPositionTopRight;
            [self.arRadarView setRadarToThumbnail:_radarThumbnailPosition withAdditionalOffset:rect];
            [self.arRadarView showRadar];
        }
        else if (_radarThumbnailPosition == PARRadarPositionTopRight) {
            _radarThumbnailPosition = PARRadarPositionBottomLeft;
            [self.arRadarView setRadarToThumbnail:_radarThumbnailPosition withAdditionalOffset:rect];
            [self.arRadarView showRadar];
        }
        else if (_radarThumbnailPosition == PARRadarPositionBottomLeft) {
            _radarThumbnailPosition = PARRadarPositionBottomRight;
            [self.arRadarView setRadarToThumbnail:_radarThumbnailPosition withAdditionalOffset:rect];
            [self.arRadarView showRadar];
        }
        else {
            [self.arRadarView setRadarToFullscreen:CGPointMake(0, -32) withSizeOffset:0];
            [self.arRadarView showRadar];
        }
    }
    else {
        [self.arRadarView hideRadar];
    }
}

- (IBAction)showOptions:(id)sender {
    if (!_areOptionsVisible) {
        _areOptionsVisible = true;
        UIActionSheet* options = [[UIActionSheet alloc] initWithTitle:@"Options"
                                                             delegate:self
                                                    cancelButtonTitle:@"Cancel"
                                               destructiveButtonTitle:@"Remove all POIs"
                                                    otherButtonTitles:@"Re-create sample POIs", @"Create Random POIs",@"Show Big Cities around me",@"Take Screenshot",@"Fake Location", @"Do not fake Location", nil];
        options.tag = 1;
        [options showFromBarButtonItem:self.navigationItem.rightBarButtonItem animated:YES];
    }
}


- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    switch (buttonIndex) {
        case 0:
            // remove the Objects in the Controller
            [[PARController sharedARController] clearObjects];
            _hasARPoiObjects = NO;
            break;
        case 1:
            // Create the standard POIs in the Controller
            [self createARPoiObjects];
            break;
        case 2:
            // Create random POIs
            [PARPoiFactory createAroundUser:50];
            break;
        case 3:
            // Create POIs for 6 big cities around the user
            [PARPoiFactory createCitiesAroundUser:6];
            break;
        case 4:
            // take image of cameraView
            [self captureNow];
            break;
        case 5:
            // Fake Location to Rome
            [[PSKSensorManager sharedSensorManager] setFakeLocation:[[CLLocation alloc] initWithLatitude:51.5033630f longitude:-0.1276250f]];
            [[PSKSensorManager sharedSensorManager] setUseFakeLocation:YES];
            break;
        case 6:
            // Disable Location faking
            [[PSKSensorManager sharedSensorManager] setUseFakeLocation:NO];
            break;
        default:
            break;
    }
    _areOptionsVisible = false;
}

#pragma mark - PAR Stuff

// create a few test poi objects
- (void)createARPoiObjects {
    // first clear old objects
    [[PARController sharedARController] clearObjects];
    
    // now create new ones
    id newPoiLabel = nil;
    Class poiLabelClass = [PARPoiLabel class];
    
    // Use this to enable stacking
    //Class poiLabelClass = [PARPoiAdvancedLabel class];
    
    // setup factory to use same class – this is used to create a lot of test labels
    [PARPoiFactory setPoiClass:poiLabelClass];
    
    // ZIPCODE MARK : Populate marker
    
    [self getLocations];
    
    /*
     // now add a poi (a graphic only - no text)
     PARPoi* newPoi = nil;
     newPoi = [[PARPoi alloc] initWithImage:@"DefaultImage"
     atLocation:[[CLLocation alloc] initWithLatitude:51.500141 longitude:-0.126257]
     ];
     newPoi.offset = CGPointMake(0, 0); // use this to move the poi relative to his final position on screen
     [[PARController sharedARController] addObject:newPoi];
     
     // Add another POI, near our Headquarters – display an image on it using a custom PoiLabelTemplate
     newPoiLabel = [[poiLabelClass alloc] initWithTitle:@"Dom"
     theDescription:@"Regensburger Dom"
     theImage:[UIImage imageNamed:@"Icon@2x~ipad"]
     fromTemplateXib:@"PoiLabelWithImage"
     atLocation:[[CLLocation alloc] initWithLatitude:49.019512 longitude:12.097709]
     ];
     [[PARController sharedARController] addObject:newPoiLabel];
     */
    NSLog(@"Number of PAR Objects in SharedController: %d", [[PARController sharedARController] numberOfObjects]);
    
    _hasARPoiObjects = YES;
}

-(void) getLocations {
    CLLocation* l = [[self deviceAttitude] location];
    CLLocationCoordinate2D c = [l coordinate];
    
    //create the url to call
    NSString *APIstring = [NSString stringWithFormat:@"https://zipcode-rece.c9users.io:8080/api/listings?lat=%f&lon=%f", c.latitude, c.longitude];
    NSLog(APIstring);
    NSURL *infoURL = [[NSURL alloc] initWithString:APIstring];
    NSURLRequest *infoRequest = [[NSURLRequest alloc] initWithURL:infoURL];
    [NSURLConnection sendAsynchronousRequest:infoRequest queue:[[NSOperationQueue alloc]init] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        
        //handle sercer response
        NSError *error= [[NSError alloc] init];
        if (connectionError!=nil) {
            NSLog(@"connection error");
        } else {
            id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            NSDictionary *results = object;
            
            [self parseLocationReturn:results];
        }
    }];
}

-(void) parseLocationReturn:(NSDictionary *)data {
    
    Class poiLabelClass = [PARPoiLabel class];
    
    NSArray* locations = [data objectForKey:@"bundle"];
    
    //replace all objects with our new set of objects
    [[PARController sharedARController] clearObjects];
    NSLog(@"LOCATIONS COUNT: %lu",(unsigned long)[locations count]);
    for(NSInteger i = 0; i < [locations count]; i ++) {
        NSDictionary* thisLocation = [locations objectAtIndex:i];
        NSString* title = [thisLocation objectForKey:@"baths"];
        NSString* subtitle = [thisLocation objectForKey:@"address"];
        NSArray* coordinates = [thisLocation objectForKey:@"coordinates"];
        double lat = [[coordinates objectAtIndex:0] doubleValue];
        double lng = [[coordinates objectAtIndex:1] doubleValue];
        
        [[PARController sharedARController] addObject:[[poiLabelClass alloc] initWithTitle:title
                                                                            theDescription:subtitle
                                                                                atLocation:[[CLLocation alloc] initWithLatitude:lat longitude:lng]
                                                       ]];
        
        NSLog(@"added a thing to the thing");
    }
}



- (void)requestDataFromServer {
    //create request for data
    NSURL *infoURL = [[NSURL alloc] initWithString:@"http://uwl.probitystaging.com/APIs/pages.php"];
    NSURLRequest *infoRequest = [[NSURLRequest alloc] initWithURL:infoURL];
    [NSURLConnection sendAsynchronousRequest:infoRequest queue:[[NSOperationQueue alloc]init] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        
        //handle sercer response
        NSError *error= [[NSError alloc] init];
        if (connectionError!=nil) {
            NSLog(@"connection error");
        } else {
            NSArray *content = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            [self parseData:content];
        }
    }];
}

-(void) parseData:(NSArray *)data {
    NSDictionary *eachRow;
    // Parse each row of data from API
    for (eachRow in data) {
        NSLog(@"as");
    }
}


-(void) captureNow
{
    // only works correctly in portrait mode at the moment
    if(!_stillImageOutput){
     _stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
     NSDictionary *stillImageOutputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:
                                                  AVVideoCodecJPEG, AVVideoCodecKey, nil];
     [_stillImageOutput setOutputSettings:stillImageOutputSettings];
     [self.cameraCaptureSession addOutput:_stillImageOutput];
    }

    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in _stillImageOutput.connections)
    {
        for (AVCaptureInputPort *port in [connection inputPorts])
        {
            if ([[port mediaType] isEqual:AVMediaTypeVideo] )
            {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection) { break; }
    }
    
    [_stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection
                                                  completionHandler: ^(CMSampleBufferRef imageSampleBuffer, NSError *error)
     {
    NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];

    CGSize newSize = self.arView.frame.size;
    UIGraphicsBeginImageContext(newSize);
    UIImage *image = [[UIImage alloc] initWithData:imageData];
     
    [self.arView.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *ARimage = UIGraphicsGetImageFromCurrentImageContext();

    [image drawInRect:CGRectMake(0,0,newSize.width,newSize.height)];
    [ARimage drawInRect:CGRectMake(0,0,newSize.width,newSize.height) blendMode:kCGBlendModeNormal alpha:1.0];
     
     UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
        
     UIImageWriteToSavedPhotosAlbum(newImage, nil, nil, nil);
     UIGraphicsEndImageContext();
     }];
}


@end
