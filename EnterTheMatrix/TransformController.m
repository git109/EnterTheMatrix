//
//  TransformController.m
//  EnterTheMatrix
//
//  Created by Mark Pospesel on 3/14/12.
//  Copyright (c) 2012 Mark Pospesel. All rights reserved.
//

#import "TransformController.h"
#import "TransformTable.h"
#import "MPAnimation.h"

#define TRANSFORM_POPOVER_ID	@"TransformPopover"
#define INFO_POPOVER_ID			@"InfoPopover"
#define ANCHOR_POPOVER_ID		@"AnchorPopover"
#define TRANSFORM3D_KEY_PATH	@"transform3D"
#define AFFINE_TRANSFORM_KEY_PATH	@"affineTransform"
#define ANCHOR_DOT_TAG			6000

@interface TransformController ()

@end

@implementation TransformController

@synthesize transform;
@synthesize contentView;
@synthesize toolbar;
@synthesize popover;
@synthesize anchorPoint;

- (id)initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder:aDecoder];
	if (self)
	{
		transform = [[MPTransform alloc] init];
		anchorPoint = AnchorPointCenter;
		if ([self is3D])
			[transform addSkewOperation];
	}
	return self;
}

- (void)dealloc
{
	[self removeObserverForTransform];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	[self addObserverForTransform];
	// Do any additional setup after loading the view.

	// use some image tricks
	UIImage *image = [MPAnimation renderImage:[UIImage imageNamed:[self imageName]] withMargin:10 color:[UIColor whiteColor]];
	UIImageView *imgView = [[UIImageView alloc] initWithImage:image];
	imgView.center = CGPointMake(roundf(CGRectGetMidX(self.view.frame)), roundf(CGRectGetMidY(self.view.frame)));
	[imgView setUserInteractionEnabled:YES];
	[self setContentView:imgView];
	[self.view insertSubview:imgView belowSubview:self.toolbar];

	self.contentView.layer.shadowOpacity = 0.5;
	self.contentView.layer.shadowOffset = CGSizeMake(0, 3);
	[[self.contentView layer] setShadowPath:[[UIBezierPath bezierPathWithRect:[self.contentView bounds]] CGPath]];

	UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
	[self.contentView addGestureRecognizer:panGesture];
	
	UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
	[self.view addGestureRecognizer:pinchGesture];
	
	UIRotationGestureRecognizer *rotateGesture = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(handleRotation:)];
	[self.view addGestureRecognizer:rotateGesture];
}

- (void)viewDidUnload
{
	[self removeObserverForTransform];
	[self setPopover:nil];
    [self setContentView:nil];
	[self setToolbar:nil];
	
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	self.contentView.center = CGPointMake(roundf(CGRectGetMidX(self.view.bounds)), roundf(CGRectGetMidY(self.view.bounds)));
	self.contentView.bounds = CGRectMake(0, 0, 502, 382);
	[self updateTransform];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	self.contentView.center = CGPointMake(roundf(CGRectGetMidX(self.view.bounds)), roundf(CGRectGetMidY(self.view.bounds)));
	self.contentView.bounds = CGRectMake(0, 0, 502, 382);
}

#pragma mark - Property

- (BOOL)is3D
{
	return NO;
}

- (NSString *)imageName
{
	return @"matrix_02";
}

- (NSString *)transformKeyPath
{
	return [self is3D]? TRANSFORM3D_KEY_PATH : AFFINE_TRANSFORM_KEY_PATH;
}

#pragma mark - KVO

- (void)addObserverForTransform
{
	if (!_observerAdded)
	{
		[self.transform addObserver:self forKeyPath:[self transformKeyPath] options:NSKeyValueObservingOptionNew context:nil];
		_observerAdded = YES;
	}
}

- (void)removeObserverForTransform
{
	if (_observerAdded)
	{
		[self.transform removeObserver:self forKeyPath:[self transformKeyPath]];
		_observerAdded = NO;
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:[self transformKeyPath]])
	{
		[self updateTransform];
	}
}

- (void)setAnchorPoint:(AnchorPointLocation)value
{
	if (anchorPoint != value)
	{
		anchorPoint = value;
		CGPoint point;
		
		switch (anchorPoint) {
			case AnchorPointTopLeft:
				point = CGPointMake(0, 0);
				break;
				
			case AnchorPointTopCenter:
				point = CGPointMake(0.5, 0);
				break;
				
			case AnchorPointTopRight:
				point = CGPointMake(1, 0);
				break;
				
			case AnchorPointMiddleLeft:
				point = CGPointMake(0, 0.5);
				break;
				
			case AnchorPointCenter:
				point = CGPointMake(0.5, 0.5);
				break;
				
			case AnchorPointMiddleRight:
				point = CGPointMake(1, 0.5);
				break;
				
			case AnchorPointBottomLeft:
				point = CGPointMake(0, 1);
				break;
				
			case AnchorPointBottomCenter:
				point = CGPointMake(0.5, 1);
				break;
				
			case AnchorPointBottomRight:
				point = CGPointMake(1, 1);
				break;
				
			default:
				break;
		}
		
		// Animate anchor point change
		
		// Begin transaction
		[CATransaction begin];
		NSTimeInterval duration = 0.5;
		[CATransaction setValue:[NSNumber numberWithFloat:duration] forKey:kCATransactionAnimationDuration];
		[CATransaction setValue:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut] forKey:kCATransactionAnimationTimingFunction];
		[CATransaction setCompletionBlock:^{
			// clean up anchor point animation
			[self.contentView.layer setAnchorPoint:point];
			[self.contentView.layer removeAnimationForKey:@"anchorPoint"];
		}];
		
		CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"anchorPoint"];
		animation.removedOnCompletion = NO;
		animation.fillMode = kCAFillModeForwards; // leave in place (to prevent flicker)
		animation.toValue = [NSValue valueWithCGPoint:point];
			
		// add the animation to the layer
		[self.contentView.layer addAnimation:animation forKey:@"anchorPoint"];
		
		// commit the transaction
		[CATransaction commit];

		// position anchor dot
		UIView *anchorDotView = [self.contentView viewWithTag:ANCHOR_DOT_TAG];
		if (anchorDotView == nil)
		{
			anchorDotView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Dot"]];
			anchorDotView.tag = ANCHOR_DOT_TAG;
			[self.contentView addSubview:anchorDotView];
		}
		[anchorDotView.layer setPosition:CGPointMake(1 + point.x * (self.contentView.bounds.size.width - 2), 1 + point.y * (self.contentView.bounds.size.height - 2))];		
	}
}

#pragma mark - Transform

- (void)updateTransform
{
	if ([self is3D])
		[self.contentView.layer setTransform:[self.transform transform3D]];
	else
		[self.contentView setTransform:[self.transform affineTransform]];
}

#pragma mark - Button handlers

- (IBAction)transformPressed:(id)sender {
    if ([popover isPopoverVisible])
    {
        [popover dismissPopoverAnimated:YES];
        self.popover = nil;
        return;
    }
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard_iPad" bundle:nil];
    UIViewController *contentController = [storyboard instantiateViewControllerWithIdentifier:TRANSFORM_POPOVER_ID];
	TransformTable *transformTable = (TransformTable *)contentController;
	[transformTable setThreeD:[self is3D]];
	[transformTable setTransform:self.transform];
    popover = [[UIPopoverController alloc] initWithContentViewController:contentController];
    [popover presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];	
}

- (IBAction)resetPressed:(id)sender {
    if ([popover isPopoverVisible])
    {
        [popover dismissPopoverAnimated:YES];
        self.popover = nil;
    }
	
	UIView *anchorDotView = [self.contentView viewWithTag:ANCHOR_DOT_TAG];

	NSTimeInterval duration = 0.5;
	[UIView animateWithDuration:duration delay:0 options:UIViewAnimationCurveEaseInOut animations:^{
		[self.transform reset];
		[anchorDotView setAlpha:0];
		
		// animate anchor point change
		CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"anchorPoint"];
		animation.duration = duration;
		animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
		animation.removedOnCompletion = NO;
		animation.fillMode = kCAFillModeForwards; // leave in place (to prevent flicker)
		animation.toValue = [NSValue valueWithCGPoint:CGPointMake(0.5, 0.5)];
		
		[self.contentView.layer addAnimation:animation forKey:@"anchorPoint"];
	} completion:^(BOOL finished) {
		anchorPoint = AnchorPointCenter;
		[anchorDotView removeFromSuperview];
		
		// clean up anchor point animation
		[self.contentView.layer setAnchorPoint:CGPointMake(0.5, 0.5)];
		[self.contentView.layer removeAnimationForKey:@"anchorPoint"];
	}];
}

- (IBAction)infoPressed:(id)sender {
    if ([popover isPopoverVisible])
    {
        [popover dismissPopoverAnimated:YES];
        self.popover = nil;
        return;
    }
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard_iPad" bundle:nil];
    UIViewController *contentController = [storyboard instantiateViewControllerWithIdentifier:INFO_POPOVER_ID];
    popover = [[UIPopoverController alloc] initWithContentViewController:contentController];
    [popover presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];	
}

- (IBAction)anchorPressed:(id)sender {
    if ([popover isPopoverVisible])
    {
        [popover dismissPopoverAnimated:YES];
        self.popover = nil;
        return;
    }
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard_iPad" bundle:nil];
    UIViewController *contentController = [storyboard instantiateViewControllerWithIdentifier:ANCHOR_POPOVER_ID];
	AnchorPointTable *anchorTable = (AnchorPointTable *)contentController;
	[anchorTable setAnchorPoint:self.anchorPoint];
	[anchorTable setAnchorPointDelegate:self];
    popover = [[UIPopoverController alloc] initWithContentViewController:contentController];
    [popover presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];	
}

#pragma mark - Labels

- (UIView *)makeContainer
{
	[[self.view viewWithTag:TRANSFORM_CONTAINER_TAG] removeFromSuperview];
	
	UIView *view = [[UIView alloc] init];
	view.backgroundColor = [UIColor whiteColor];
	view.tag = TRANSFORM_CONTAINER_TAG;
	view.layer.cornerRadius = 5;
	view.layer.shadowOffset = CGSizeMake(0, 3);
	view.layer.shadowOpacity = 0.5;
	view.layer.zPosition = 1024; // make sure it stays well above our contentView
	
	return view;
}

- (UILabel *)makeLabel
{
	UILabel *label = [[UILabel alloc] init];
	label.backgroundColor = [UIColor clearColor];
	label.textAlignment = UITextAlignmentCenter;
	label.textColor = [UIColor blackColor];
	label.font = [UIFont fontWithName:@"Menlo" size:18];
	label.tag = TRANSFORM_LABEL_TAG;
	return label;
}

- (void)setText:(NSString *)text forLabel:(UILabel *)label
{
	[label setText:text];
	[label sizeToFit];
	label.frame = CGRectMake(8, 5, label.bounds.size.width, label.bounds.size.height);
	[label superview].bounds = CGRectMake(0, 0, label.bounds.size.width + 16, label.bounds.size.height + 10);	
}

- (void)positionLabel:(UILabel *)label aboveGesture:(UIGestureRecognizer *)gestureRecognizer
{
	CGPoint position = [gestureRecognizer locationInView:self.view];
	for (NSUInteger i = 0; i < [gestureRecognizer numberOfTouches];i++)
	{
		CGPoint location = [gestureRecognizer locationOfTouch:i inView:self.view];
		if (location.y < position.y)
			position.y = location.y;
	}
	
	position.y = position.y - 50;
	UIView *container = [label superview];
	container.center = position;
	[[container layer] setShadowPath:[[UIBezierPath bezierPathWithRoundedRect:[container bounds] cornerRadius:5] CGPath]];	
}

- (void)setGesture:(UIGestureRecognizer *)gestureRecognizer translationforLabel:(UILabel *)label
{
	NSString *labelText = [self is3D]? [NSString stringWithFormat:@"Translation {%d, %d, %d}", (int)roundf(self.transform.translateX), (int)roundf(self.transform.translateY), (int)roundf(self.transform.translateZ)] : [NSString stringWithFormat:@"Translation {%d, %d}", (int)roundf(self.transform.translateX), (int)roundf(self.transform.translateY)];
	[self setText:labelText forLabel:label];
	[self positionLabel:label aboveGesture:gestureRecognizer];
}

- (void)setGesture:(UIGestureRecognizer *)gestureRecognizer scaleforLabel:(UILabel *)label
{
	NSString *labelText = [self is3D]? [NSString stringWithFormat:@"Scale {%.03f, %.03f, %.03f}", self.transform.scaleX, self.transform.scaleY, self.transform.scaleZ] : [NSString stringWithFormat:@"Scale {%.03f, %.03f}", self.transform.scaleX, self.transform.scaleY];
	[self setText:labelText forLabel:label];
	[self positionLabel:label aboveGesture:gestureRecognizer];
}

- (void)setGesture:(UIGestureRecognizer *)gestureRecognizer rotationforLabel:(UILabel *)label
{
	NSString *labelText = [self is3D]? [NSString stringWithFormat:@"Rotation %d° about vector {%.03f, %.03f, %.03f}",(int)roundf(self.transform.rotationAngle), self.transform.rotationX, self.transform.rotationY, self.transform.rotationZ] : [NSString stringWithFormat:@"Rotation %d°", (int)roundf(self.transform.rotationAngle)];
	[self setText:labelText forLabel:label];
	[self positionLabel:label aboveGesture:gestureRecognizer];
}

#pragma mark - Gesture Recognizers

- (void)handlePan:(UIPanGestureRecognizer *)gestureRecognizer
{
	CGPoint currentPoint = [gestureRecognizer locationInView:self.view];
	UIGestureRecognizerState state = [gestureRecognizer state];
	
	if (state == UIGestureRecognizerStateBegan)
	{
		UILabel *label = [self makeLabel];
		UIView *container = [self makeContainer];
		[container addSubview:label];
		[self setGesture:gestureRecognizer translationforLabel:label];
		[self.view addSubview:container];
	}
	else if (state == UIGestureRecognizerStateChanged)
	{
		CGPoint diff = CGPointMake(currentPoint.x - lastPoint.x, currentPoint.y - lastPoint.y);
		if ([self is3D])
			[self.transform offset3D:diff];
		else
			[self.transform offset:diff];
		[self updateTransform];
		
		UILabel *label = (UILabel *)[self.view viewWithTag:TRANSFORM_LABEL_TAG];
		[self setGesture:gestureRecognizer translationforLabel:label];
	}
	else if (state == UIGestureRecognizerStateEnded || state == UIGestureRecognizerStateCancelled)
	{
		[[self.view viewWithTag:TRANSFORM_CONTAINER_TAG] removeFromSuperview];
	}
	
	lastPoint = currentPoint;
}

- (void)handlePinch:(UIPinchGestureRecognizer *)gestureRecognizer
{
	CGFloat currentScale = [gestureRecognizer scale];
	CGPoint currentPoint = [gestureRecognizer locationInView:self.view];
	UIGestureRecognizerState state = [gestureRecognizer state];
	
	if (state == UIGestureRecognizerStateBegan)
	{
		UILabel *label = [self makeLabel];
		UIView *container = [self makeContainer];
		[container addSubview:label];
		[self setGesture:gestureRecognizer scaleforLabel:label];
		[self.view addSubview:container];
	}
	else if (state == UIGestureRecognizerStateChanged)
	{
		CGFloat scaleDiff = currentScale / lastScale;
		[self.transform scaleOffset:scaleDiff];
		[self updateTransform];
		
		UILabel *label = (UILabel *)[self.view viewWithTag:TRANSFORM_LABEL_TAG];
		[self setGesture:gestureRecognizer scaleforLabel:label];
	}
	else if (state == UIGestureRecognizerStateEnded || state == UIGestureRecognizerStateCancelled)
	{
		[[self.view viewWithTag:TRANSFORM_CONTAINER_TAG] removeFromSuperview];
	}
	
	lastPoint = currentPoint;
	lastScale = currentScale;
}

- (void)handleRotation:(UIRotationGestureRecognizer *)gestureRecognizer
{
	CGFloat currentRotation = [gestureRecognizer rotation];
	CGPoint currentPoint = [gestureRecognizer locationInView:self.view];
	UIGestureRecognizerState state = [gestureRecognizer state];
	
	if (state == UIGestureRecognizerStateBegan)
	{
		UILabel *label = [self makeLabel];
		UIView *container = [self makeContainer];
		[container addSubview:label];
		[self setGesture:gestureRecognizer rotationforLabel:label];
		[self.view addSubview:container];
	}
	else if (state == UIGestureRecognizerStateChanged)
	{
		CGFloat rotationDiff = degrees(currentRotation - lastRotation);
		[self.transform rotationOffset:rotationDiff];
		[self updateTransform];
		
		UILabel *label = (UILabel *)[self.view viewWithTag:TRANSFORM_LABEL_TAG];
		[self setGesture:gestureRecognizer rotationforLabel:label];
	}
	else if (state == UIGestureRecognizerStateEnded || state == UIGestureRecognizerStateCancelled)
	{
		[[self.view viewWithTag:TRANSFORM_CONTAINER_TAG] removeFromSuperview];
	}
	
	lastPoint = currentPoint;
	lastRotation = currentRotation;
}

#pragma mark - AnchorPointDelegate

- (void)anchorPointDidChange:(AnchorPointLocation)newAnchorPoint
{
    if ([popover isPopoverVisible])
    {
        [popover dismissPopoverAnimated:YES];
        self.popover = nil;
    }
	
	[self setAnchorPoint:newAnchorPoint];
}

@end
