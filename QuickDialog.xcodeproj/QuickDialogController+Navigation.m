#import "QuickDialogController+Navigation.h"


@implementation QuickDialogController(Navigation)



- (void)displayViewController:(UIViewController *)newController {
    if (self.navigationController != nil ){
        [self.navigationController pushViewController:newController animated:YES];
    } else {
        [self presentModalViewController:newController animated:YES];
    }
}

- (void)displayViewControllerForRoot:(QRootElement *)root {
    QuickDialogController *newController = [self controllerForRoot: root];

    if (root.presentationMode==QPresentationModeNormal) {
        [self displayViewController:newController];
    } else if (root.presentationMode == QPresentationModePopover || root.presentationMode == QPresentationModeNavigationInPopover) {
        [self displayViewControllerInPopover:newController withNavigation:root.presentationMode==QPresentationModeNavigationInPopover];
    } else if (root.presentationMode == QPresentationModeModalForm) {
        UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController :newController];
        navigation.modalPresentationStyle = UIModalPresentationFormSheet;
        [self presentModalViewController:navigation animated:YES];
    }  else if (root.presentationMode == QPresentationModeModalFullScreen) {
        UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController :newController];
        navigation.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentModalViewController:navigation animated:YES];
    }  else if (root.presentationMode == QPresentationModeModalPage) {
        UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController :newController];
        navigation.modalPresentationStyle = UIModalPresentationPageSheet;
        [self presentModalViewController:navigation animated:YES];
    }
}

- (void)displayViewControllerInPopover:(UIViewController *)newController withNavigation:(BOOL)navigation {

    if ([UIDevice currentDevice].userInterfaceIdiom!=UIUserInterfaceIdiomPad){
        [self displayViewController:newController];
        return;
    }

    UIPopoverController *popoverController = [[UIPopoverController alloc] initWithContentViewController:
        navigation ? [[UINavigationController alloc] initWithRootViewController :newController] : newController
    ];
    popoverController.popoverContentSize = CGSizeMake(320, 360);
    if ([newController respondsToSelector:@selector(setPopoverBeingPresented:)]) {
        [newController performSelector:@selector(setPopoverBeingPresented:) withObject:popoverController];
    } else {
        self.popoverForChildRoot = popoverController;
    }
    popoverController.delegate = self;

    CGRect position = [self.quickDialogTableView rectForRowAtIndexPath:self.quickDialogTableView.indexPathForSelectedRow];
    [popoverController presentPopoverFromRect:position inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    [self.quickDialogTableView reloadData];
    self.popoverForChildRoot = nil;

}


- (void)popToPreviousRootElementOnMainThread {

    if ([self popoverBeingPresented]!=nil){
        [self.popoverBeingPresented dismissPopoverAnimated:YES];
        if (self.popoverBeingPresented.delegate!=nil){
            [self.popoverBeingPresented.delegate popoverControllerDidDismissPopover:self.popoverBeingPresented];
        }
    }
    else if (self.navigationController!=nil){
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissModalViewControllerAnimated:YES];
    }
}

- (void)popToPreviousRootElement {
    [self performSelectorOnMainThread:@selector(popToPreviousRootElementOnMainThread) withObject:nil waitUntilDone:YES];
}

@end