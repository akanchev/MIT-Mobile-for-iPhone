//
//  DiningHallMenuCompareView.m
//  MIT Mobile
//
//  Created by Austin Emmons on 4/8/13.
//
//

#import "DiningHallMenuCompareView.h"
#import "PSTCollectionView.h"
#import "UIKit+MITAdditions.h"
#import "DiningHallMenuCompareLayout.h"

@interface DiningHallMenuCompareView () <PSTCollectionViewDataSource, CollectionViewDelegateMenuCompareLayout>

@property (nonatomic, strong) UILabel * headerView;
@property (nonatomic, strong) PSTCollectionView * collectionView;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;

@end

#define HEADER_VIEW_HEIGHT 24

@implementation DiningHallMenuCompareView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
        self.headerView = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, HEADER_VIEW_HEIGHT)];
        self.headerView.textAlignment = UITextAlignmentCenter;
        self.headerView.font = [UIFont fontWithName:@"Helvetica-Bold" size:12];
        
        self.dateFormatter = [[NSDateFormatter alloc] init];
        [self.dateFormatter setDateFormat:@"MMMM dd"];
        
        DiningHallMenuCompareLayout *layout = [[DiningHallMenuCompareLayout alloc] init];
        layout.columnWidth = ceil(CGRectGetWidth(self.bounds) / 5);
        
        CGFloat headerHeight = CGRectGetHeight(self.headerView.frame);
        self.collectionView = [[PSTCollectionView alloc] initWithFrame:CGRectMake(0, headerHeight, CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds) - headerHeight) collectionViewLayout:layout];
        self.collectionView.dataSource = self;
        self.collectionView.delegate = self;
        [self.collectionView registerClass:[PSTCollectionViewCell class] forCellWithReuseIdentifier:@"DiningMenuCell"];
        
        [self addSubview:self.headerView];
        [self addSubview:self.collectionView];
    }
    return self;
}

- (NSArray *) debugHouseDiningData
{
    return [NSArray arrayWithObjects:@"Baker", @"The Howard Dining Hall", @"McCormick", @"Next", @"Simmons", nil];
}

#pragma mark Setter Override

- (void) setDate:(NSDate *)date
{
    _date = date;
    self.headerView.text = [self.dateFormatter stringFromDate:self.date];
    // TODO :: should reload data for date
    
}


#pragma mark - PSTCollectionViewDatasource

- (NSInteger)numberOfSectionsInCollectionView:(PSTCollectionView *)collectionView
{
    return [[self debugHouseDiningData] count];
}

- (NSInteger)collectionView:(PSTCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return 3 + (section % 4);
}

//- (PSTCollectionReusableView *)collectionView:(PSTCollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
//{
//    if ([kind isEqualToString:@"sectionHeader"]) {
//        PSTCollectionReusableView *reusableView = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"sectionHeader" forIndexPath:indexPath];
//        
//        
//        return reusableView;
//    }
//}

// The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
- (PSTCollectionViewCell *)collectionView:(PSTCollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    PSTCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"DiningMenuCell" forIndexPath:indexPath];
    if (!cell) {
        cell = [[PSTCollectionViewCell alloc] init];
    }
    
    cell.backgroundColor = [UIColor whiteColor];
    cell.layer.borderWidth = 1;
    cell.layer.borderColor = [UIColor blackColor].CGColor;
    
    return cell;
}

#pragma mark - CollectionViewDelegateMenuCompareLayout
- (CGFloat)collectionView:(PSTCollectionView *)collectionView layout:(PSTCollectionViewLayout*)collectionViewLayout heightForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
}


@end
