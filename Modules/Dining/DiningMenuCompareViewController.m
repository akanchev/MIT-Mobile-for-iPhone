#import "DiningMenuCompareViewController.h"
#import "DiningHallMenuCompareView.h"
#import "CoreDataManager.h"
#import "Foundation+MITAdditions.h"

#import "HouseVenue.h"
#import "DiningDay.h"
#import "DiningMeal.h"
#import "DiningMealItem.h"

#define SECONDS_IN_DAY 86400
#define DAY_VIEW_PADDING 5      // padding on each side of day view. doubled when two views are adjacent
#define MEAL_ORDER @[@"breakfast", @"brunch", @"lunch", @"dinner"]



@interface NSFetchedResultsController (DiningComparisonAdditions)

- (void) fetchItemsForPredicate:(NSPredicate *)predicate;

@end

@implementation NSFetchedResultsController (DiningComparisonAdditions)

- (void) fetchItemsForPredicate:(NSPredicate *)predicate
{
    self.fetchRequest.predicate = predicate;
    
    NSError *error = nil;
    [self performFetch:&error];
    
    if (error) {
        NSLog(@"Error fetching DiningMealItems. \n %@", error);
    }
}
@end



@interface DiningMenuCompareViewController () <UIScrollViewDelegate, DiningCompareViewDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;

@property (nonatomic, strong) NSDate *datePointer;
@property (nonatomic, strong) NSString * mealPointer;

@property (nonatomic, strong) NSDateFormatter *sectionSubtitleFormatter;

@property (nonatomic, strong) DiningHallMenuCompareView * previous;     // on left
@property (nonatomic, strong) DiningHallMenuCompareView * current;      // center
@property (nonatomic, strong) DiningHallMenuCompareView * next;         // on right

@property (nonatomic, strong) NSArray * houseVenueSections; // array of houseVenueSection titles, needed because fetchedResultsController will not return empty sections

@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) NSFetchedResultsController *previousFRC;
@property (nonatomic, strong) NSFetchedResultsController *currentFRC;
@property (nonatomic, strong) NSFetchedResultsController *nextFRC;

@end

@implementation DiningMenuCompareViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    self.view.autoresizesSubviews = YES;
    
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"shortName" ascending:YES];
    NSArray *houseVenues = [CoreDataManager objectsForEntity:@"HouseVenue" matchingPredicate:nil sortDescriptors:@[sort]];
    self.houseVenueSections = [houseVenues valueForKey:@"shortName"];
    
    // The scrollview has a frame that is just larger than the viewcontrollers view bounds so that padding can be seen between scrollable pages.
    // Frames are also inverted (height => width, width => height) because when the view loads the rotation has not yet occurred.
    CGRect frame = CGRectMake(-DAY_VIEW_PADDING, 0, CGRectGetHeight(self.view.bounds) + (DAY_VIEW_PADDING * 2), CGRectGetWidth(self.view.bounds));
    
    self.sectionSubtitleFormatter = [[NSDateFormatter alloc] init];
    [self.sectionSubtitleFormatter setAMSymbol:@"am"];
    [self.sectionSubtitleFormatter setPMSymbol:@"pm"];
    
    self.scrollView = [[UIScrollView alloc] initWithFrame:frame];
    self.scrollView.delegate = self;
    self.scrollView.contentSize = CGSizeMake((DAY_VIEW_PADDING * 6) + (CGRectGetHeight(self.view.bounds) * 3), CGRectGetWidth(self.view.bounds));
    self.scrollView.pagingEnabled = YES;
    
    [self.view addSubview:self.scrollView];
    
    self.datePointer = [NSDate dateWithTimeIntervalSinceNow:0];
    
	self.previous = [[DiningHallMenuCompareView alloc] initWithFrame:CGRectMake(DAY_VIEW_PADDING, 0, CGRectGetHeight(self.view.bounds), CGRectGetWidth(self.view.bounds))];
    self.current = [[DiningHallMenuCompareView alloc] initWithFrame:CGRectMake(CGRectGetMaxX(self.previous.frame) + (DAY_VIEW_PADDING * 2), 0, CGRectGetHeight(self.view.bounds), CGRectGetWidth(self.view.bounds))];
    self.next = [[DiningHallMenuCompareView alloc] initWithFrame:CGRectMake(CGRectGetMaxX(self.current.frame) + (DAY_VIEW_PADDING * 2), 0, CGRectGetHeight(self.view.bounds), CGRectGetWidth(self.view.bounds))];
                                                                        // (viewPadding * 2) is used because each view has own padding, so there are 2 padded spaces to account for
    
    [self.scrollView setContentOffset:CGPointMake(self.current.frame.origin.x - DAY_VIEW_PADDING, 0) animated:NO];  // have to subtract DAY_VIEW_PADDING because scrollview sits offscreen at offset.
    
    self.previous.delegate = self;
    self.current.delegate = self;
    self.next.delegate = self;
    
    [self.scrollView addSubview:self.previous];
    [self.scrollView addSubview:self.current];
    [self.scrollView addSubview:self.next];
    
    [self loadData];
    [self reloadAllComparisonViews];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)orientation duration:(NSTimeInterval)duration
{
    if (UIInterfaceOrientationIsPortrait(orientation)) {
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        [self dismissModalViewControllerAnimated:YES];
    }
}

#pragma mark - Model methods

- (void) loadData
{
    NSDate *date = [HouseVenue fakeDate];
    NSLog(@"Fake Date :: %@", date);
    
    NSString *mealName = [self bestMealForDate:date];
    self.currentFRC = [self fetchedResultsControllerForMealNamed:mealName onDate:date];
    [self.currentFRC performFetch:nil];
}

- (NSManagedObjectContext *)managedObjectContext {
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    _managedObjectContext = [[NSManagedObjectContext alloc] init];
    _managedObjectContext.persistentStoreCoordinator = [[CoreDataManager coreDataManager] persistentStoreCoordinator];
    _managedObjectContext.undoManager = nil;
    _managedObjectContext.stalenessInterval = 0;
    
    return _managedObjectContext;
}

- (NSFetchedResultsController *)fetchedResultsControllerForMealNamed:(NSString *)mealName onDate:(NSDate *)date
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"DiningMealItem"
                                              inManagedObjectContext:self.managedObjectContext];
    fetchRequest.entity = entity;
    fetchRequest.predicate = [self predicateForMealNamed:mealName onDate:date];
    NSString *sectionKeyPath = @"meal.day.houseVenue.shortName";
    NSSortDescriptor *sectionSort = [NSSortDescriptor sortDescriptorWithKey:sectionKeyPath ascending:YES selector:@selector(caseInsensitiveCompare:)];
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"ordinality" ascending:YES];
    fetchRequest.sortDescriptors = @[sectionSort, sort];
    
    NSFetchedResultsController *fetchedResultsController =
                    [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                        managedObjectContext:self.managedObjectContext
                                                          sectionNameKeyPath:sectionKeyPath
                                                                   cacheName:nil];
    return fetchedResultsController;
}

- (void) fetchItemsForMealNamed:(NSString *)mealName onDate:(NSDate *)date
{
    
    
    
}

- (NSPredicate *) predicateForMealNamed:(NSString *)mealName onDate:(NSDate *)date
{
    if (!self.filtersApplied) {
        return [NSPredicate predicateWithFormat:@"self.meal.name = %@ AND self.meal.day.date >= %@ AND self.meal.day.date <= %@", mealName, [date startOfDay], [date endOfDay]];
    } else {
        return [NSPredicate predicateWithFormat:@"self.meal.name = %@ AND ANY dietaryFlags IN %@ AND self.meal.day.date >= %@ AND self.meal.day.date <= %@", mealName, self.filtersApplied, [date startOfDay], [date endOfDay]];
    }
}



#pragma mark - UIScrollview Delegate
- (void) scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    // Handle infinite scroll between 3 views. Returns to center view so there is always a view on the left and right
    if (scrollView.contentOffset.x > scrollView.frame.size.width) {
        // have scrolled to the right
        [self didPageRight];
        
    } else if (scrollView.contentOffset.x < scrollView.frame.size.width) {
        // have scrolled to the left
        [self didPageLeft];         
    }
    
    // TODO :: should only reset to center if we can page left and we can page right
    // Also should not update data when we reach edge
    [scrollView setContentOffset:CGPointMake(self.current.frame.origin.x - DAY_VIEW_PADDING, 0) animated:NO]; // always return to center view
}

- (void) didPageRight
{
    self.datePointer = [self.datePointer dayAfter];
    
    self.previousFRC = self.currentFRC;
    self.currentFRC = self.nextFRC;
    // Need to set nextFRC with new predicate
    
    [self.current resetScrollOffset]; // need to reset scroll offset so user always starts at (0,0) in collectionView
    // TODO fetch all data  
    [self reloadAllComparisonViews];
}

- (void) didPageLeft
{
    self.datePointer = [self.datePointer dayBefore];
    
    self.nextFRC = self.currentFRC;
    self.currentFRC = self.previousFRC;
    // Need to set previousFRC with new predicate for previousMeal
        
    [self.current resetScrollOffset];
    // TODO fetch all data
    [self reloadAllComparisonViews];
}

- (NSString *) bestMealForDate:(NSDate *) date
{
    NSString *mealEntity = @"DiningMeal";
    DiningMeal *meal = nil;
    NSSortDescriptor *startTimeAscending = [NSSortDescriptor sortDescriptorWithKey:@"startTime" ascending:YES];
    
    NSPredicate *inProgress = [NSPredicate predicateWithFormat:@"startTime <= %@ AND endTime >= %@", date, date];               // date is between a startTime and endTime
    NSArray *results = [CoreDataManager objectsForEntity:mealEntity matchingPredicate:inProgress sortDescriptors:@[startTimeAscending]];
    if ([results count]) {
        meal = results[0];
        return meal.name;
    }
    
    NSPredicate *isUpcoming = [NSPredicate predicateWithFormat:@"startTime > %@ AND startTime < %@", date, [date endOfDay]];    // meal starts after date but starts before the end of the date's day
    results = [CoreDataManager objectsForEntity:mealEntity matchingPredicate:isUpcoming sortDescriptors:@[startTimeAscending]];
    if ([results count]) {
        meal = results[0];
        return meal.name;
    }
    
    NSPredicate *lastOfDay = [NSPredicate predicateWithFormat:@"startTime >= %@ AND endTime <= %@", [date startOfDay], [date endOfDay]];
    results = [CoreDataManager objectsForEntity:mealEntity matchingPredicate:lastOfDay sortDescriptors:@[startTimeAscending]];
    meal = [results lastObject];
    return meal.name;
}



#pragma mark - DiningCompareView Helper Methods
- (void) reloadAllComparisonViews
{
    [self.previous reloadData];
    [self.current reloadData];
    [self.next reloadData];
}

- (NSFetchedResultsController *) resultsControllerForCompareView:(DiningHallMenuCompareView *)compareView
{
    if (compareView == self.previous) {
        return self.previousFRC;
    } else if (compareView == self.current) {
        return self.currentFRC;
    } else if (compareView == self.next) {
        return self.nextFRC;
    }
    return nil;
}


#pragma mark - DiningCompareViewDelegate
- (NSString *) titleForCompareView:(DiningHallMenuCompareView *)compareView
{
    return @"Hello There";
}

- (NSInteger) numberOfSectionsInCompareView:(DiningHallMenuCompareView *)compareView
{
    return 5;
}

- (NSString *) compareView:(DiningHallMenuCompareView *)compareView titleForSection:(NSInteger)section
{
    return self.houseVenueSections[section];
    
}

- (NSString *) compareView:(DiningHallMenuCompareView *)compareView subtitleForSection:(NSInteger)section
{
    NSFetchedResultsController *controller = [self resultsControllerForCompareView:compareView];
    NSArray *sections = [controller sections];
    if (section >= [sections count]) {
        return @"";
    }
    id<NSFetchedResultsSectionInfo> sectionInfo = sections[section];
    DiningMealItem *sampleItem = [[sectionInfo objects] lastObject];
    
    if (!sampleItem) {
        return @"";
    }
    
    [self.sectionSubtitleFormatter setDateFormat:@"h:mm"];
    NSString *start = [self.sectionSubtitleFormatter stringFromDate:sampleItem.meal.startTime];
    
    [self.sectionSubtitleFormatter setDateFormat:@"h:mm a"];
    NSString *end = [self.sectionSubtitleFormatter stringFromDate:sampleItem.meal.endTime];
    
    return [NSString stringWithFormat:@"%@ - %@", start, end];
}

- (NSInteger) compareView:(DiningHallMenuCompareView *)compareView numberOfItemsInSection:(NSInteger) section
{
    NSFetchedResultsController *controller = [self resultsControllerForCompareView:compareView];
    NSArray *sections = [controller sections];
    if (section >= [sections count]) {
        return 1;       // necessary to show section header
    }
    id<NSFetchedResultsSectionInfo> sectionInfo = [controller sections][section];
    if ([sectionInfo numberOfObjects]) {
        return [sectionInfo numberOfObjects];
    } else {
        return 1;       // necessary for 'No Meals' cell
    }
}

- (DiningHallMenuComparisonCell *) compareView:(DiningHallMenuCompareView *)compareView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSFetchedResultsController *controller = [self resultsControllerForCompareView:compareView];
    NSArray *sections = [controller sections];
    DiningMealItem *item = nil;
    if (indexPath.section >= [sections count]) {
        item = nil;
    } else {
        id<NSFetchedResultsSectionInfo> sectionInfo = [controller sections][indexPath.section];
        item = [sectionInfo objects][indexPath.row];
    }
    
    
    if (item) {
        DiningHallMenuComparisonCell *cell = [compareView dequeueReusableCellWithReuseIdentifier:@"DiningMenuCell" forIndexPath:indexPath];
        cell.primaryLabel.text = item.name;
        cell.secondaryLabel.text = item.subtitle;
        
        cell.dietaryTypes = [item.dietaryFlags allObjects];
        if (indexPath.row == 0) {
            NSLog(@"dietaryTypes :: %@", cell.dietaryTypes);
            NSLog(@"item :: %@", item);
        }
        
        
        return cell;
    } else {
        // TODO :: need to create a 'No Meals' cell
         DiningHallMenuComparisonCell *cell = [compareView dequeueReusableCellWithReuseIdentifier:@"DiningMenuCell" forIndexPath:indexPath];
        cell.primaryLabel.text = @"No meals";
        return cell;
    }
}

- (CGFloat) compareView:(DiningHallMenuCompareView *)compareView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSFetchedResultsController *controller = [self resultsControllerForCompareView:compareView];
    NSArray *sections = [controller sections];
    if (indexPath.section >= [sections count]) {
        return 30;       // necessary to show section header
    }
    id<NSFetchedResultsSectionInfo> sectionInfo = [controller sections][indexPath.section];
    DiningMealItem *item = [sectionInfo objects][indexPath.row];
    
    if (item) {
        return [DiningHallMenuComparisonCell heightForComparisonCellOfWidth:compareView.columnWidth withPrimaryText:item.name secondaryText:item.subtitle numDietaryTypes:[item.dietaryFlags count]];
    } else {
        // TODO :: need to distinguish height of no meals cell
        return 30;
    }
}



@end
