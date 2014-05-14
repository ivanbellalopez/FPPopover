//
//  FPPopoverController.m
//
//  Created by Alvise Susmel on 1/5/12.
//  Copyright (c) 2012 Fifty Pixels Ltd. All rights reserved.
//
//  https://github.com/50pixels/FPPopover


#import "FPPopoverController.h"

//ivars
@interface FPPopoverController()
{
    FPTouchView *_touchView;
    FPPopoverView *_contentView;
    UIViewController *_viewController;
    UIWindow *_window;
    UIView *_parentView;
    UIView *_fromView;
    UIInterfaceOrientation _deviceOrientation;
    
    BOOL _shadowsHidden;
    CGColorRef _shadowColor;

    BOOL shouldAnimateOnKeyboardShown;
}
@end


//private methods
@interface FPPopoverController(Private)
-(CGPoint)originFromView:(UIView*)fromView;


-(CGFloat)parentWidth;
-(CGFloat)parentHeight;

#pragma mark Space management
/* This methods help the controller to found a proper way to display the view.
 * If the "from point" will be on the left, the arrow will be on the left and the 
 * view will be move on the right of the from point.
 */

-(CGRect)bestArrowDirectionAndFrameFromView:(UIView*)v;

@end

@implementation FPPopoverController
@synthesize delegate = _delegate;
@synthesize contentView = _contentView;
@synthesize touchView = _touchView;
@synthesize contentSize = _contentSize;
@synthesize origin = _origin;
@synthesize arrowDirection = _arrowDirection;
@synthesize tint = _tint;
@synthesize customTint = _customTint;
@synthesize border = _border;
@synthesize alpha = _alpha;
@synthesize usesGradient = _usesGradient;
@synthesize lineBorder = _lineBorder;
@synthesize customLineBorderColor = _customLineBorderColor;
@synthesize isModal = _isModal;
@synthesize shouldPresentWithBounce = _shouldPresentWithBounce;
@synthesize shouldHideOnRotation = _shouldHideOnRotation;
@synthesize visible = _visible;

-(void)addObservers
{
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

  [nc addObserver:self selector:@selector(willPresentNewPopover:) name:@"FPNewPopoverPresented" object:nil];
  [nc addObserver:self selector:@selector(deviceOrientationDidChange:) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
  [nc addObserver:self selector:@selector(deviceOrientationWillChange:) name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
  [nc addObserver:self selector:@selector(keyboardWillShow:) name: UIKeyboardWillShowNotification object:nil];
  [nc addObserver:self selector:@selector(keyboardWillHide:) name: UIKeyboardWillHideNotification object:nil];
    
  _deviceOrientation = [UIApplication sharedApplication].statusBarOrientation;
}

-(void)removeObservers
{
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

  [nc removeObserver:self name:@"FPNewPopoverPresented" object:nil];
  [nc removeObserver:self name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
  [nc removeObserver:self name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
  [nc removeObserver:self name:UIKeyboardWillShowNotification object:nil];
  [nc removeObserver:self name:UIKeyboardWillHideNotification object:nil];

  [_viewController removeObserver:self forKeyPath:@"title"];
}


-(void)dealloc
{
    [self removeObservers];
    if(_shadowColor) CGColorRelease(_shadowColor);

#ifdef FP_DEBUG
    NSLog(@"FPPopoverController dealloc");
#endif

    SAFE_ARC_RELEASE(_contentView);
    SAFE_ARC_RELEASE(_touchView);
    self.delegate = nil;
    _viewController = nil;
    
    SAFE_ARC_SUPER_DEALLOC();
}

-(id)initWithContentViewController:(UIViewController*)viewController{
  return [self initWithViewController:viewController];
}

-(id)initWithViewController:(UIViewController*)viewController {
	return [self initWithViewController:viewController delegate:nil];
}

-(id)initWithViewController:(UIViewController*)viewController
				   delegate:(id<FPPopoverControllerDelegate>)delegate
{
    self = [super init];
    if(self)
    {
		self.delegate = delegate;
		
		_visible = NO;
		self.shouldPresentWithBounce = NO;
		self.shouldHideOnRotation = YES;
        
        self.alpha = 1.0;
        self.arrowDirection = FPPopoverArrowDirectionAny;
        self.view.userInteractionEnabled = YES;
        _border = YES;
        
        _touchView = [[FPTouchView alloc] initWithFrame:self.view.bounds];
        _touchView.backgroundColor = [UIColor clearColor];
        _touchView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _touchView.clipsToBounds = NO;
        [self.view addSubview:_touchView];
        
        
        __weak typeof (self) bself = self;
        [_touchView setTouchedOutsideBlock:^{
            [bself dismissPopoverAnimated:YES];
        }];

        isNavigationController = [viewController isKindOfClass:[UINavigationController class]];

        if (!isNavigationController)
          self.contentSize = viewController.contentSizeForViewInPopover;
        else
          self.contentSize = [(UIViewController *)[(UINavigationController *)viewController  viewControllers][0] contentSizeForViewInPopover];
      
        self.contentSize = CGSizeMake (self.contentSize.width+20, self.contentSize.height+20+(isNavigationController?40:0));

        _contentView = [[FPPopoverView alloc] initWithFrame:CGRectMake(0, 0, 
                                              self.contentSize.width, self.contentSize.height)];
        
        _viewController = viewController;
        _viewController.view.clipsToBounds = YES;
        
        [_touchView addSubview:_contentView];
        
        [_contentView addContentView:_viewController.view];
        _viewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.view.clipsToBounds = NO;

        _touchView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _touchView.clipsToBounds = NO;
        
        //setting contentview
        _contentView.title = _viewController.title;
        _contentView.clipsToBounds = NO;
        
        [_viewController addObserver:self forKeyPath:@"title" options:NSKeyValueObservingOptionNew context:nil];
    }
    return self;
}


-(void)setTint:(FPPopoverTint)tint
{
    _contentView.tint = tint;
    [_contentView setNeedsDisplay];
}

-(FPPopoverTint)tint
{
    return _contentView.tint;
}

-(void)setCustomTint:(UIColor *)customTint
{
  _contentView.tint = FPPopoverCustomTint;
  _contentView.customTint = customTint;
  [_contentView setNeedsDisplay];
}

#pragma mark - View lifecycle

-(void)setupView
{
    self.view.frame = CGRectMake(0, 0, [self parentWidth], [self parentHeight]);
    _touchView.frame = self.view.bounds;
    
    //view position, size and best arrow direction
    [self bestArrowDirectionAndFrameFromView:_fromView];

    [_contentView setNeedsDisplay];
    [_touchView setNeedsDisplay];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //initialize and load the content view
    [_contentView setArrowDirection:FPPopoverArrowDirectionUp];
    [_contentView addContentView:_viewController.view];

    [self setupView];
    [self addObservers];
}

- (void) viewWillLayoutSubviews
{
  [super viewWillLayoutSubviews];
	
  if (isNavigationController)
    [(UINavigationController *)_viewController navigationBar].frame = CGRectMake(0.0, 0.0, [(UINavigationController *)_viewController navigationBar].frame.size.width, [(UINavigationController *)_viewController navigationBar].frame.size.height);

  [self setupView];
}

#pragma mark Orientation

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
	if ([_viewController respondsToSelector:@selector(shouldAutorotateToInterfaceOrientation:)])
		return [_viewController shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
	return YES;
}


#pragma mark presenting

-(CGFloat)parentWidth
{
    return _parentView.bounds.size.width;
    //return UIDeviceOrientationIsPortrait(_deviceOrientation) ? _parentView.frame.size.width : _parentView.frame.size.height;
}
-(CGFloat)parentHeight
{
    return _parentView.bounds.size.height - keyboardHeight;;
    //return UIDeviceOrientationIsPortrait(_deviceOrientation) ? _parentView.frame.size.height : _parentView.frame.size.width;
}

-(void)presentPopoverFromPoint:(CGPoint)fromPoint
{
    self.origin = fromPoint;
    
    //NO BORDER
    if(self.border == NO)
    {
        _viewController.title = nil;
        _viewController.view.clipsToBounds = YES;
    }
    
    _contentView.relativeOrigin = [_parentView convertPoint:fromPoint toView:_contentView];

    [self.view removeFromSuperview];
    NSArray *windows = [UIApplication sharedApplication].windows;
    if(windows.count > 0)
    {
          _parentView=nil;
        _window = windows[0];
        //keep the first subview
        if(_window.subviews.count > 0)
        {
            _parentView = (_window.subviews)[0];
            [_parentView addSubview:self.view];
            [_viewController viewDidAppear:YES];
        }
        
   }
    else
    {
        [self dismissPopoverAnimated:NO];
    }
    
    
    
    [self setupView];
    self.view.alpha = 0.0;
    [UIView animateWithDuration:0.2 animations:^{
        
        self.view.alpha = self.alpha;

    } completion:^(BOOL finished) {
	
		_visible = YES;
		
		if (self.shouldPresentWithBounce)
		{
          CGFloat time = 0.0;
          CGFloat currentScale = 1.0;
          int steps = 15;
          CGFloat timeStep = 0.2;
          NSMutableArray *animationArray = [[NSMutableArray alloc] initWithCapacity:steps];
          for (int t = 0; t < steps ; t++)
          {
            CGFloat newScale = pow(M_E, -t) * cos(4.0*t+M_PI/2.0) + 1.0;
            CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform"];
            animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            animation.fromValue = [NSValue valueWithCATransform3D:CATransform3DMakeScale(currentScale,currentScale,1.0)];
            animation.toValue =   [NSValue valueWithCATransform3D:CATransform3DMakeScale(newScale, newScale, 1.0)];
            animation.removedOnCompletion=YES;
            animation.beginTime = time;
            animation.duration = timeStep;
            
            [animationArray addObject:animation];
            
            currentScale = newScale;
            time+=timeStep;
            timeStep-=0.015;
          }
          
          CAAnimationGroup *group = [CAAnimationGroup animation];
          [group setDuration:time];
          [group setAnimations:animationArray];          
          [self.view.layer addAnimation:group forKey:@"zoom"];
		}
		
    }];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FPNewPopoverPresented" object:self];
}


-(CGPoint)originFromView:(UIView*)fromView
{
    CGPoint p = CGPointZero;
    if([_contentView arrowDirection] == FPPopoverArrowDirectionUp ||
       [_contentView arrowDirection] == FPPopoverNoArrow)
    {
        p.x = fromView.frame.origin.x + fromView.frame.size.width/2.0;
        p.y = fromView.frame.origin.y + fromView.frame.size.height;
    }
    else if([_contentView arrowDirection] == FPPopoverArrowDirectionDown)
    {
        p.x = fromView.frame.origin.x + fromView.frame.size.width/2.0;
        p.y = fromView.frame.origin.y;        
    }
    else if([_contentView arrowDirection] == FPPopoverArrowDirectionLeft)
    {
        p.x = fromView.frame.origin.x + fromView.frame.size.width;
        p.y = fromView.frame.origin.y + fromView.frame.size.height/2.0;
    }
    else if([_contentView arrowDirection] == FPPopoverArrowDirectionRight)
    {
        p.x = fromView.frame.origin.x;
        p.y = fromView.frame.origin.y + fromView.frame.size.height/2.0;
    }

    return p;
}

-(void)presentPopoverFromView:(UIView*)fromView
{
     _fromView = fromView;
    [self presentPopoverFromPoint:[self originFromView:_fromView]];
}

-(void)presentPopoverFromRect:(CGRect)fromRect inView:(UIView *)view permittedArrowDirections:(FPPopoverArrowDirection)arrowDirections animated:(BOOL)animated
{
  self.arrowDirection = arrowDirections;
  
  for (UIView *subview in [view subviews])
  {
    if (CGRectEqualToRect(fromRect, subview.frame))
    {
      [self presentPopoverFromView:subview];
      return;
    }
  }
}

-(void)dismissPopover
{
    [self.view removeFromSuperview];
    if([self.delegate respondsToSelector:@selector(popoverControllerDidDismissPopover:)])
    {
        [self.delegate popoverControllerDidDismissPopover:self];
    }
     _window=nil;
     _parentView=nil;
}

-(void)dismissPopoverAnimated:(BOOL)animated {
	[self dismissPopoverAnimated:animated completion:nil];
}

-(void)dismissPopoverAnimated:(BOOL)animated completion:(FPPopoverCompletion)completionBlock
{
    if(animated)
    {
        [UIView animateWithDuration:0.2 animations:^{
            self.view.alpha = 0.0;
        } completion:^(BOOL finished) {
            [self dismissPopover];
			if (completionBlock)
				completionBlock();
        }];
    }
    else
    {
        [self dismissPopover];
		if (completionBlock)
			completionBlock();
    }
         
}

-(void)setOrigin:(CGPoint)origin
{
    _origin = origin;
}


#pragma mark observing

-(void)deviceOrientationWillChange:(NSNotification*)notification
{
  if (self.shouldHideOnRotation)
    self.view.alpha = 0.0;
}

-(void)deviceOrientationDidChange:(NSNotification*)notification
{
  _deviceOrientation = [UIApplication sharedApplication].statusBarOrientation;
  shouldAnimateOnKeyboardShown = NO;

  [UIView animateWithDuration:0.2 animations:^{
    [self setupView];
  } completion:^(BOOL finished) {
    if (self.shouldHideOnRotation)
      [UIView animateWithDuration:0.0 delay:0.5 options:nil animations:^{
      self.view.alpha = 1.0;
      } completion:nil];
  }];
}

- (void) keyboardWillShow:(NSNotification*)notification
{
  NSDictionary *userInfo = [notification userInfo];
  CGSize kbSize = [userInfo[UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
  CGFloat animationDuration = shouldAnimateOnKeyboardShown ? [userInfo[UIKeyboardAnimationDurationUserInfoKey] floatValue] : 0.0;
  NSUInteger animationType = [userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue];
  keyboardHeight = UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation]) ? kbSize.height : kbSize.width;
//  keyboardHeight += 20; // Adds some space between the keyboard and the popover
  [UIView animateWithDuration:animationDuration
                        delay:0.0
                      options:animationType
                   animations:^{
                     [self setupView];
                   }
                   completion:^(BOOL finished){
                     shouldAnimateOnKeyboardShown = NO;
                   }];
}

- (void) keyboardWillHide:(NSNotification*)notification
{
  keyboardHeight = 0;
  shouldAnimateOnKeyboardShown = YES;
  NSDictionary *userInfo = [notification userInfo];
  CGFloat animationDuration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] floatValue];
  NSUInteger animationType = [userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue];
  [UIView animateWithDuration:animationDuration
                        delay:0.0
                      options:animationType
                   animations:^{
                     [self setupView];
                   }
                   completion:nil];
}

-(void)willPresentNewPopover:(NSNotification*)notification
{
    if(notification.object != self)
    {
        if([self.delegate respondsToSelector:@selector(presentedNewPopoverController:shouldDismissVisiblePopover:)])
        {
            [self.delegate presentedNewPopoverController:notification.object
                             shouldDismissVisiblePopover:self];
        }
    }
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if(object == _viewController && [keyPath isEqualToString:@"title"])
    {
        _contentView.title = _viewController.title;
        [_contentView setNeedsDisplay];
    }
}


#pragma mark Space management

-(CGRect)bestArrowDirectionAndFrameFromView:(UIView*)v
{
    // thanks @Niculcea
    // If we presentFromPoint with _fromView nil will calculate based on self.orgin with 2x2 size.
    // Fix for presentFromPoint from avolovoy's FPPopover fork
//    float width = 2.0f;
//    float height = 2.0f;
    CGPoint p = CGPointMake(self.origin.x, self.origin.y);
    
    if (v != nil) {
        p = [v.superview convertPoint:v.frame.origin toView:self.view];
//        width = v.frame.size.width;
//        height = v.frame.size.height;
    }
    
    
    CGFloat ht = p.y; //available vertical space on top of the view
    CGFloat hb = [self parentHeight] -  (p.y + v.frame.size.height); //on the bottom
    CGFloat wl = p.x; //on the left
    CGFloat wr = [self parentWidth] - (p.x + v.frame.size.width); //on the right
        
    CGFloat best_h = MAX(ht, hb); //much space down or up ?
    CGFloat best_w = MAX(wl, wr);
    
    CGRect r;
    r.size = self.contentSize;

    FPPopoverArrowDirection bestDirection;
    
    //if the user wants vertical arrow, check if the content will fit vertically 
    if(FPPopoverArrowDirectionIsVertical(self.arrowDirection) || 
       (self.arrowDirection == FPPopoverArrowDirectionAny && best_h >= best_w))
    {

        //ok, will be vertical
        if(ht == best_h || self.arrowDirection == FPPopoverArrowDirectionDown)
        {
            //on the top and arrow down
            bestDirection = FPPopoverArrowDirectionDown;
            
            r.origin.x = p.x + v.frame.size.width/2.0 - r.size.width/2.0;
            r.origin.y = p.y - r.size.height;
        }
        else
        {
            //on the bottom and arrow up
            bestDirection = FPPopoverArrowDirectionUp;

            r.origin.x = p.x + v.frame.size.width/2.0 - r.size.width/2.0;
            r.origin.y = p.y + v.frame.size.height;
        }
        

    }
    
    
    else 
    {
        //ok, will be horizontal
        //the arrow must NOT be forced to left
        if((wl == best_w || self.arrowDirection == FPPopoverArrowDirectionRight) && self.arrowDirection != FPPopoverArrowDirectionLeft)
        {
            //on the left and arrow right
            bestDirection = FPPopoverArrowDirectionRight;

            r.origin.x = p.x - r.size.width;
            r.origin.y = p.y + v.frame.size.height/2.0 - r.size.height/2.0;

        }
        else
        {
            //on the right then arrow left
            bestDirection = FPPopoverArrowDirectionLeft;

            r.origin.x = p.x + v.frame.size.width;
            r.origin.y = p.y + v.frame.size.height/2.0 - r.size.height/2.0;
        }
        

    }
    
    
    
    //need to moved left ? 
    if(r.origin.x + r.size.width > [self parentWidth])
    {
        r.origin.x = [self parentWidth] - r.size.width;
    }
    
    //need to moved right ?
    else if(r.origin.x < 0)
    {
        r.origin.x = 0;
    }
    
    
    //need to move up?
    if(r.origin.y < 0)
    {
        CGFloat old_y = r.origin.y;
        r.origin.y = 0;
        r.size.height += old_y;
    }

    //need to move up because of keyboard
    if (keyboardHeight>0)
    {
      if (CGRectGetMaxY(r)>[self parentHeight])
      {
        CGFloat newY = r.origin.y - (CGRectGetMaxY(r)-[self parentHeight]);

//        if ([self parentHeight] - r.size.height > 0)
//        {
//          newY = [self parentHeight] - r.size.height;
//        }
//        else
//        {
//          newY = r.origin.y - (CGRectGetMaxY(r)-[self parentHeight]);
//        }

        r.origin.y = newY;
      }
    }
    
    //need to be resized horizontally ?
    if(r.origin.x + r.size.width > [self parentWidth])
    {
        r.size.width = [self parentWidth] - r.origin.x;
    }
    
    //need to be resized vertically ?
    if(r.origin.y + r.size.height > [self parentHeight])
    {
        r.size.height = [self parentHeight] - r.origin.y;
    }
    
    
    if([[UIApplication sharedApplication] isStatusBarHidden] == NO)
    {
        if(r.origin.y <= 20) r.origin.y += 20;
    }

	// Status Bar also exists in the UINavigationController used.
    if (isNavigationController)
    {
      //r.origin.y -= 20;
      r.size.height += 20;
    }

    //check if the developer wants and arrow
    //and use the frame calculated
    if(self.arrowDirection != FPPopoverNoArrow)
    {
      _contentView.arrowDirection = bestDirection;
      _contentView.frame = r;
    }
    else
    {
      //no arrow
      _contentView.arrowDirection = FPPopoverNoArrow;
      // And center the frame in the screen
      CGRect aframe = _contentView.frame;
      aframe.size = r.size;
      _contentView.frame = aframe;
      _contentView.center = self.view.center;
    }

    self.origin = CGPointMake(p.x + v.frame.size.width/2.0, p.y + v.frame.size.height/2.0);
    _contentView.relativeOrigin = [_parentView convertPoint:self.origin toView:_contentView];

    return r;
}


-(void)setShadowsHidden:(BOOL)hidden
{
    _shadowsHidden = hidden;
    if(hidden)
    {
        _contentView.layer.shadowOpacity = 0;
        _contentView.layer.shadowRadius = 0;
        _contentView.layer.shadowOffset = CGSizeMake(0, 0);
        _shadowColor = CGColorRetain(_contentView.layer.shadowColor);
        _contentView.layer.shadowColor = nil;
    }
    else
    {
        _contentView.layer.shadowOpacity = 0.7;
        _contentView.layer.shadowRadius = 5;
        _contentView.layer.shadowOffset = CGSizeMake(-3, 3);
        _contentView.layer.shadowColor = _shadowColor;
        if(_shadowColor)
        {
            CGColorRelease(_shadowColor);
            _shadowColor=nil;
        }
    }
}

#pragma mark 3D Border

-(void)setBorder:(BOOL)border
{
    _border = border;
    _contentView.border = border;
    [_contentView setNeedsDisplay];
}

#pragma mark Transparency
-(void)setAlpha:(CGFloat)alpha
{
    _alpha = alpha;
    self.view.alpha = alpha;
}

#pragma mark Use of gradients
-(void)setUsesGradient:(BOOL)usesGradient
{
  _usesGradient = usesGradient;
  _contentView.usesGradient = usesGradient;
  [_contentView setNeedsDisplay];
}

#pragma mark Border lines
-(void)setLineBorder:(BOOL)lineBorder
{
  _lineBorder = lineBorder;
  _contentView.lineBorder = lineBorder;
  [_contentView setNeedsDisplay];
}

-(void)setCustomLineBorderColor:(UIColor *)customLineBorderColor
{
  _customLineBorderColor = customLineBorderColor;
  _contentView.customLineBorderColor = customLineBorderColor;
  [_contentView setNeedsDisplay];
}

#pragma mark Modal
-(void)setIsModal:(BOOL)isModal
{
  _isModal = isModal;
  self.touchView.isModal = isModal;
}


@end
