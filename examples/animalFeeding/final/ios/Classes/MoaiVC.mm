//----------------------------------------------------------------//
// Copyright (c) 2010-2011 Zipline Games, Inc. 
// All Rights Reserved. 
// http://getmoai.com
//----------------------------------------------------------------//

#import <aku/AKU.h>
#import "MoaiVC.h"
#import "MoaiView.h"

//================================================================//
// MoaiVC ()
//================================================================//
@interface MoaiVC ()

	//----------------------------------------------------------------//	
	-( void ) updateOrientation :( UIInterfaceOrientation )orientation;

@end

//================================================================//
// MoaiVC
//================================================================//
@implementation MoaiVC

	//----------------------------------------------------------------//
	-( void ) willRotateToInterfaceOrientation :( UIInterfaceOrientation )toInterfaceOrientation duration:( NSTimeInterval )duration {
		
		[ self updateOrientation:toInterfaceOrientation ];
	}

	//----------------------------------------------------------------//
	- ( id ) init {
	
		self = [ super init ];
		if ( self ) {
		
		}
		return self;
	}

	//----------------------------------------------------------------//
- ( BOOL ) shouldAutorotateToInterfaceOrientation :
( UIInterfaceOrientation )interfaceOrientation {
    
    if ( interfaceOrientation == UIInterfaceOrientationLandscapeRight ) {
        return true;
    } else {
        return false;
    }
}

	//----------------------------------------------------------------//
	-( void ) updateOrientation :( UIInterfaceOrientation )orientation {
		
		MoaiView* view = ( MoaiView* )self.view;        
		
		if (( orientation == UIInterfaceOrientationPortrait ) || ( orientation == UIInterfaceOrientationPortraitUpsideDown )) {
            
            if ([ view akuInitialized ] != 0 ) {
                AKUSetOrientation ( AKU_ORIENTATION_PORTRAIT );
                AKUSetViewSize (( int )view.width, ( int )view.height );
            }
		}
		else if (( orientation == UIInterfaceOrientationLandscapeLeft ) || ( orientation == UIInterfaceOrientationLandscapeRight )) {
            if ([ view akuInitialized ] != 0 ) {
                AKUSetOrientation ( AKU_ORIENTATION_LANDSCAPE );
                AKUSetViewSize (( int )view.height, ( int )view.width);
                NSLog(@"view.h = %d view.w = %d", ( int )view.height, ( int )view.width);
            }
		}
	}
	
@end