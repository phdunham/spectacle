#import "SpectacleTestSupport.h"

#import "SpectacleHistory.h"
#import "SpectacleHistoryItem.h"

@interface SpectacleHistoryTests : XCTestCase
@end

@implementation SpectacleHistoryTests

static SpectacleHistoryItem *item(CGFloat x)
{
  return [SpectacleHistoryItem historyItemFromAccessibilityElement:nil windowRect:CGRectMake(x, 0, 100, 100)];
}

- (void)testStartsEmpty
{
  SpectacleHistory *history = [SpectacleHistory new];
  XCTAssertTrue([history isEmpty]);
  XCTAssertNil([history previousHistoryItem]);
  XCTAssertNil([history nextHistoryItem]);
}

- (void)testWalksBackAndForward
{
  SpectacleHistory *history = [SpectacleHistory new];
  [history addHistoryItem:item(1)];
  [history addHistoryItem:item(2)];
  [history addHistoryItem:item(3)];
  XCTAssertFalse([history isEmpty]);
  XCTAssertEqual([history previousHistoryItem].windowRect.origin.x, 2);
  XCTAssertEqual([history previousHistoryItem].windowRect.origin.x, 1);
  XCTAssertNil([history previousHistoryItem]);
  XCTAssertEqual([history nextHistoryItem].windowRect.origin.x, 2);
  XCTAssertEqual([history nextHistoryItem].windowRect.origin.x, 3);
  XCTAssertNil([history nextHistoryItem]);
}

- (void)testAddingAfterUndoDiscardsTheRedoBranch
{
  SpectacleHistory *history = [SpectacleHistory new];
  [history addHistoryItem:item(1)];
  [history addHistoryItem:item(2)];
  [history addHistoryItem:item(3)];
  [history previousHistoryItem];
  [history addHistoryItem:item(4)];
  XCTAssertNil([history nextHistoryItem]);
  XCTAssertEqual([history previousHistoryItem].windowRect.origin.x, 2);
  XCTAssertEqual([history previousHistoryItem].windowRect.origin.x, 1);
}

- (void)testKeepsAtMostFiftyItems
{
  SpectacleHistory *history = [SpectacleHistory new];
  for (int i = 1; i <= 60; i++) {
    [history addHistoryItem:item(i)];
  }
  NSUInteger steps = 0;
  SpectacleHistoryItem *oldest = nil;
  SpectacleHistoryItem *current = nil;
  while ((current = [history previousHistoryItem])) {
    oldest = current;
    steps++;
  }
  XCTAssertEqual(steps, 49u);
  XCTAssertEqual(oldest.windowRect.origin.x, 11);
}

@end
