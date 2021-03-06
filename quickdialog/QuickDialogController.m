//                                
// Copyright 2011 ESCOZ Inc  - http://escoz.com
// 
// Licensed under the Apache License, Version 2.0 (the "License"); you may not use this 
// file except in compliance with the License. You may obtain a copy of the License at 
// 
// http://www.apache.org/licenses/LICENSE-2.0 
// 
// Unless required by applicable law or agreed to in writing, software distributed under
// the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF 
// ANY KIND, either express or implied. See the License for the specific language governing
// permissions and limitations under the License.
//

#import "QuickDialogController.h"
#import "QRootElement.h"
@interface QuickDialogController ()<UISearchBarDelegate>

@property(nonatomic, readwrite) UISearchBar* searchBar;

+ (Class)controllerClassForRoot:(QRootElement *)root;

@end


@implementation QuickDialogController {
    BOOL _keyboardVisible;
    BOOL _viewOnScreen;
    BOOL _resizeWhenKeyboardPresented;
    UIPopoverController *_popoverForChildRoot;
}

@synthesize root = _root;
@synthesize willDisappearCallback = _willDisappearCallback;
@synthesize quickDialogTableView = _quickDialogTableView;
@synthesize resizeWhenKeyboardPresented = _resizeWhenKeyboardPresented;
@synthesize popoverBeingPresented = _popoverBeingPresented;
@synthesize popoverForChildRoot = _popoverForChildRoot;


+ (QuickDialogController *)buildControllerWithClass:(Class)controllerClass root:(QRootElement *)root {
    controllerClass = controllerClass==nil? [QuickDialogController class] : controllerClass;
    return [((QuickDialogController *)[controllerClass alloc]) initWithRoot:root];
}

+ (QuickDialogController *)controllerForRoot:(QRootElement *)root {
    Class controllerClass = [self controllerClassForRoot:root];
    if (controllerClass==nil)
        NSLog(@"Couldn't find a class for name %@", root.controllerName);
    return [((QuickDialogController *)[controllerClass alloc]) initWithRoot:root];
}


+ (Class)controllerClassForRoot:(QRootElement *)root {
    Class controllerClass = nil;
    if (root.controllerName!=NULL){
        controllerClass = NSClassFromString(root.controllerName);
    } else {
        controllerClass = [QuickDialogController class];
    }
    return controllerClass;
}

+ (UINavigationController*)controllerWithNavigationForRoot:(QRootElement *)root {
    return [[UINavigationController alloc] initWithRootViewController:[QuickDialogController
                                                                       buildControllerWithClass:[self controllerClassForRoot:root]
                                                                       root:root]];
}

- (void)loadView {
    [super loadView];
    self.quickDialogTableView = [[QuickDialogTableView alloc] initWithController:self];
}

- (void)setQuickDialogTableView:(QuickDialogTableView *)tableView
{
    _quickDialogTableView = tableView;
    self.view = tableView;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (QuickDialogController *)initWithRoot:(QRootElement *)rootElement {
    self = [super init];
    if (self) {
        self.root = rootElement;
        self.resizeWhenKeyboardPresented =YES;
    }
    return self;
}

-(void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    [self.quickDialogTableView setEditing:editing animated:animated];
}

- (void)setRoot:(QRootElement *)root {
    _root = root;
    self.quickDialogTableView.root = root;
    self.title = _root.title;
    self.navigationItem.title = _root.title;
}

- (void)viewWillAppear:(BOOL)animated {
    _viewOnScreen = YES;
    [self.quickDialogTableView deselectRows];
    [super viewWillAppear:animated];
    if (_root!=nil) {
        self.title = _root.title;
        self.navigationItem.title = _root.title;
        if (_root.preselectedElementIndex !=nil)
            [self.quickDialogTableView scrollToRowAtIndexPath:_root.preselectedElementIndex atScrollPosition:UITableViewScrollPositionTop animated:NO];

    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (_root.showKeyboardOnAppear) {
        QEntryElement *elementToFocus = [_root findElementToFocusOnAfter:nil];
        if (elementToFocus!=nil)  {
            UITableViewCell *cell = [self.quickDialogTableView cellForElement:elementToFocus];
            if (cell != nil) {
                [cell becomeFirstResponder];
            }
        }
    }
}


- (BOOL)disablesAutomaticKeyboardDismissal
{
    return NO;
}

- (void)viewWillDisappear:(BOOL)animated {
    _viewOnScreen = NO;
    [super viewWillDisappear:animated];
    if (_willDisappearCallback!=nil){
        _willDisappearCallback();
    }
}

- (QuickDialogController *)controllerForRoot:(QRootElement *)root {
    Class controllerClass = [[self class] controllerClassForRoot:root];
    return [QuickDialogController buildControllerWithClass:controllerClass root:root];
}


- (void) resizeForKeyboard:(NSNotification*)aNotification {
    if (!_viewOnScreen)
        return;

    BOOL up = aNotification.name == UIKeyboardWillShowNotification;

    if (_keyboardVisible == up)
        return;

    _keyboardVisible = up;
    NSDictionary* userInfo = [aNotification userInfo];
    NSTimeInterval animationDuration;
    UIViewAnimationOptions animationCurve;
    CGRect keyboardEndFrame;
    [[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] getValue:&animationCurve];
    [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&animationDuration];
    [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] getValue:&keyboardEndFrame];

    [UIView animateWithDuration:animationDuration delay:0 options:animationCurve
        animations:^{
            CGRect keyboardFrame = [self.view convertRect:keyboardEndFrame toView:nil];
            const UIEdgeInsets oldInset = self.quickDialogTableView.contentInset;
            self.quickDialogTableView.contentInset = UIEdgeInsetsMake(oldInset.top, oldInset.left,  up ? keyboardFrame.size.height : 0, oldInset.right);
            self.quickDialogTableView.scrollIndicatorInsets = self.quickDialogTableView.contentInset;
        }
        completion:NULL];
}

- (void)setResizeWhenKeyboardPresented:(BOOL)observesKeyboard {
  if (observesKeyboard != _resizeWhenKeyboardPresented) {
    _resizeWhenKeyboardPresented = observesKeyboard;

    if (_resizeWhenKeyboardPresented) {
      [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resizeForKeyboard:) name:UIKeyboardWillShowNotification object:nil];
      [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resizeForKeyboard:) name:UIKeyboardWillHideNotification object:nil];
    } else {
      [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
      [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    }
  }
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

#pragma mark - Searching

- (void)setSearchable:(BOOL)searchable {
    _searchable = searchable;
    
    if (searchable) {
        if (!self.searchBar) {
            self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 44)];
            self.searchBar.delegate = self;
        }
        self.quickDialogTableView.tableHeaderView = self.searchBar;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillShow:)
                                                     name:UIKeyboardWillShowNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillHide:)
                                                     name:UIKeyboardWillHideNotification
                                                   object:nil];
        
    } else {
        self.quickDialogTableView.tableHeaderView = nil;
        [self clearSearch];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:UIKeyboardWillShowNotification
                                                      object:nil];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:UIKeyboardWillHideNotification
                                                      object:nil];
        
    }
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        [self clearSearch];
    } else {
        [self search:searchText];
    }
}

- (void)clearSearch {
    for (QSection* section in self.root.sections) {
		section.hidden = NO;
       for (QElement* element in section.elements) {
           element.hidden = NO;
       }
    }
    [self.quickDialogTableView reloadData];
    //Reload sections
    [self.quickDialogTableView beginUpdates];
    [self.quickDialogTableView endUpdates];
    self.searchBar.text = nil;
}

- (void)search:(NSString*)searchText {
    NSPredicate* searchPredicate = [NSPredicate predicateWithFormat:@"SELF.title CONTAINS[cd] %@", searchText];
    for (QSection* section in self.root.sections) {
        if ([searchPredicate evaluateWithObject:section]) {
            section.hidden = NO;
        }
        else {
            section.hidden = YES;
            
            for (QElement* element in section.elements) {
                if ([searchPredicate evaluateWithObject:element]) {
                    element.hidden = NO;
                    section.hidden = NO;
                }
                else {
                    element.hidden = YES;
                }
            }
        }
    }
    [self.quickDialogTableView reloadData];
    //Reload sections
    [self.quickDialogTableView beginUpdates];
    [self.quickDialogTableView endUpdates];
}

-(void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary* userInfo = [notification userInfo];
    CGSize keyboardSize = [[userInfo objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    CGFloat keyboardHeight = (UIDeviceOrientationIsLandscape([[UIDevice currentDevice] orientation]))?keyboardSize.height:keyboardSize.width;
    CGFloat displayHeight = (UIDeviceOrientationIsLandscape([[UIDevice currentDevice] orientation]))?self.view.window.frame.size.height:self.view.window.frame.size.width;
    
    CGPoint convertedOrigin = [self.view.window convertPoint:self.view.frame.origin fromView:self.view];
    
    CGFloat bottomEdge = convertedOrigin.x + self.view.frame.size.height;
    CGFloat distanceFromBottom = MAX(displayHeight-bottomEdge, 0);
    CGFloat inset = keyboardHeight - distanceFromBottom;
    
    [UIView animateWithDuration:[self keyboardAnimationDurationForNotification:notification] animations:^{
        self.quickDialogTableView.contentInset = UIEdgeInsetsMake(0, 0, inset, 0);
    }];
}

-(void)keyboardWillHide:(NSNotification *)notification {    
    [UIView animateWithDuration:[self keyboardAnimationDurationForNotification:notification] animations:^{
        self.quickDialogTableView.contentInset = UIEdgeInsetsZero;
    }];
}

- (NSTimeInterval)keyboardAnimationDurationForNotification:(NSNotification*)notification
{
    NSDictionary* info = [notification userInfo];
    NSValue* value = [info objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSTimeInterval duration = 0;
    [value getValue:&duration];
    return duration;
}

@end
