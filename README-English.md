
ZXOptionBar-Swift
=================

An optionbar view implement by Swift  and  reuse it's cells like UITableVIew
Inspired by [TWUI](https://github.com/twitter/twui)

---

This article stems from a horizontal scroll and select the category controls remodeling. Recent study `Swift`, so the core logic of this control (Cell reuse) to rewrite it with a` Swift` to others. Of course, this is not Apple's official Cell reuse mechanism, because Apple does not open source. This article should be `Swift` are learning and want to learn Cell reuse some help students achieve. Code article involved are on the Github ([ZXOptionBar-Swift] (https://github.com/zixun/ZXOptionBar-Swift)), welcome to mention issues, seeking blood seeking child seeking to humiliate ~

The first version of this control carries all of the logical data, views, animation, making this control in the late become very difficult to maintain. So I had to reconstruct this control, and think `UITableView` also a scrollable selectable controls, why not put it into a similar` UITableView` same horizontal scrolling control it. And animation data is separated from control by `delegate` and` dataSource`, reducing the cell by cell reuse initialization expenses.

However, Apple's `UIKit` not open source ah, how to do it? twitter provides us with a good reference, that is, [TWUI] (https://github.com/twitter/twui), which is similar to a library `UIKit` of twitter on MacOS then realized, although already 2 years not been updated, but there is still a lot of good things that can be tapped, such as Twitter version of `UITabelView` of Cell reuse mechanism.

`UITableView` is divided into many` section`, but horizontal scrolling controls usually only had a Cell, the same need not be like `UITableView` divided into many different kinds of Cell, so we can transform [TWUI] (https: // github.com/twitter/twui) of Cell reuse mechanism, making it more suitable for horizontal scrolling view control。

<!-- more -->

# Design and Analysis 
* `Delegate` design patterns through the data and view separation 
* Need to inherit from the `UIScrollView` class to deal with similar` UITableView` logic (`ZXOptionBar`) 
* Need to inherit from the `UIView` class to deal with similar` UITableViewCell` logic (`ZXOptionBarCell`) 
* `ZXOptionBar` need a container to store reusable Cell 
* `ZXOptionBarCell` need a container to store the currently displayed Cell 
* Use `layoutSubviews ()` method to deal with Cell reuse logic 
* Required tools methods: 
	* Calculate the visible area Rect `visibleRect ()` 
	* Calculate visible Cell subscript index `indexsForVisibleColumns ()` 
	* Calculate the area designated Cell Rect under subscript index `indexsForColumnInRect ()` 
	* Calculate the Rect specified index Cell size `rectForColumnAtIndex ()`


# Core implementation 
## Data with the view through the delegate design pattern separation 
Used `UITableView` students know for sure that we use all the time` UITableView` by proxy method of its delegate and dataSource the data tell us `UITableView`. `ZXOptionBar` this way can also be separated from our data and views:

```swift
// MARK: - ZXOptionBarDataSource
protocol ZXOptionBarDataSource: NSObjectProtocol {
    
    func numberOfColumnsInOptionBar(optionBar: ZXOptionBar) -> Int
    func optionBar(optionBar: ZXOptionBar, cellForColumnAtIndex index: Int) -> ZXOptionBarCell
}

// MARK: - ZXOptionBarDelegate
@objc protocol ZXOptionBarDelegate: UIScrollViewDelegate {
    
    // Display customization
    optional func optionBar(optionBar: ZXOptionBar, willDisplayCell cell: ZXOptionBarCell, forColumnAtIndex index: Int)
    optional func optionBar(optionBar: ZXOptionBar, didEndDisplayingCell cell: ZXOptionBarCell, forColumnAtIndex index: Int)
    
    // Variable height support
    optional func optionBar(optionBar: ZXOptionBar, widthForColumnsAtIndex index: Int) -> Float
    
    //Select
    optional func optionBar(optionBar: ZXOptionBar, didSelectColumnAtIndex index: Int)
    optional func optionBar(optionBar: ZXOptionBar, didDeselectColumnAtIndex index: Int)
    
    //Reload
    optional func optionBarWillReloadData(optionBar: ZXOptionBar)
    optional func optionBarDidReloadData(optionBar: ZXOptionBar)

}
```

Then declare two variables in ZXOptionBar in:
```swift
// Mark: Var
weak var barDataSource: ZXOptionBarDataSource?
weak var barDelegate: ZXOptionBarDelegate?
```
And its assignment in the initialization method
```swift
// MARK: Method
convenience init(frame: CGRect, barDelegate: ZXOptionBarDelegate, barDataSource:ZXOptionBarDataSource ) {
	self.init(frame: frame)
	self.delegate = delegate
	self.barDataSource = barDataSource
	self.barDelegate = barDelegate
	.....
}
```
Observant students may have been found, delegate and dataSource Why initialization method in the assignment ah, I remember `UITableView` not like this, I must have opened the wrong way! This is beyond the limited scope of this article, want to understand the power of God can look at Matt [API Design] (http://mattgemmell.com/api-design/), you can take a look at the text of the ** Rule 3: Required settings should be initializer parameters **, but I suggest that you take the time to read the full text again, definitely benefit! 

## Cell reuse logic implementation 
### Container class definition 
We can separate out the data from our control through the above measures, the next is the most exciting time, we need to achieve our Cell reuse logic. 
First, we declare two Dictionary of container classes, one for storing reusable Cell, a Cell used to store the current screen
```swift
// MARK: Private Var
private var reusableOptionCells: Dictionary<String, NSMutableArray>!
private var visibleItems: Dictionary<String, ZXOptionBarCell>!
```
Of course, do not forget their assignments in our `convenience` `init` method, I am not here eleven code, everyone can be on my Github's [ZXOptionBar-Swift] (https://github.com / zixun / ZXOptionBar-Swift) library to download the code corresponding to the side of the blog to read, just to stick the key to some of the core code. 
### Rewrite layoutSubviews () 
`layoutSubviews ()` filling all Cell reuse logic, so we can logically independent modules first pulled out into a separate method, readers can take a look at the source code of the following methods to be familiar with the following:
```swift
private func visibleRect() -> CGRect {
	...Calculate the visible area Rect
}
private func indexsForVisibleColumns() -> Array<String> {
	...Calculated visible Cell subscript index
}
private func indexsForColumnInRect(rect: CGRect) -> Array<String> {
	...Rect designated area calculation under Cell subscript index
}
private func rectForColumnAtIndex(index: Int) -> CGRect {
	...Cell specified index calculated the size of Rect
}
```
好了，咱先来分析分析我们的逻辑
```swift
Front left slip visibleCell的index:            0 1 2 3 4 5 6 7
Left slip after the index visible Cell:                2 3 4 5 6 7 8 9
Need to remove the Cell's index:            0 1
Need to add the Cell's index:                           8 9
```
So we can find the information we need to calculate the:

* 滑动前老的可见的Cell的index(`oldVisibleIndex`);
* 滑动后新的可见的Cell的index(`newVisibleIndex`);
* 需要删除的Cell的index(`indexsToRemove`);
* 需要添加的Cell的index(`indexsToAdd`).

```swift
let oldVisibleIndex: Array<String> = self.indexsForVisibleColumns()
let newVisibleIndex: Array<String> = self.indexsForColumnInRect(visible)
        
var indexsToRemove: NSMutableArray = NSMutableArray(array: oldVisibleIndex)
indexsToRemove.removeObjectsInArray(newVisibleIndex)
        
var indexsToAdd: NSMutableArray = NSMutableArray(array: newVisibleIndex)
indexsToAdd.removeObjectsInArray(oldVisibleIndex)
```

Then we have to do is to scroll off the screen of Cell deleted：
```swift
//delete the cells which frame out
for i in indexsToRemove {
	let cell: ZXOptionBarCell = self.cellForColumnAtIndex(self.indexFromIdentifyKey(i as String))!
	self.enqueueReusableCell(cell)
	cell.removeFromSuperview()
	self.visibleItems.removeValueForKey(i as String)
}
```   
`enqueueReusableCell () `method is to get out of the screen into our Cell reuse Cell container (` reusableOptionCells`), you can see the project implementation source code. 

The final step is to add it into the screen of the Cell:
```swift
//add the new cell which frame in
for i in indexsToAdd {
            
	let indexToAdd: Int = self.indexFromIdentifyKey(i as String)
            
	var cell: ZXOptionBarCell = self.barDataSource!.optionBar(self, cellForColumnAtIndex: indexToAdd)
    cell.frame = self.rectForColumnAtIndex(indexToAdd)
    cell.layer.zPosition = 0
    cell.setNeedsDisplay()
    cell.prepareForDisplay()
    cell.index = indexToAdd
    cell.selected = (indexToAdd == self.selectedIndex)
            
	if self.barDelegate!.respondsToSelector(Selector("optionBar:willDisplayCell:forColumnAtIndex:")) {
		self.barDelegate!.optionBar!(self, willDisplayCell: cell, forColumnAtIndex: indexToAdd)
	}
            
	self.addSubview(cell)
	self.visibleItems.updateValue(cell, forKey: (i as String))
            
}
```

Here we come to realize notify build and delegate of the cell through the `cellForColumnAtIndex` dataSource and delegate of` willDisplayCell`. 

### External interface 
So that we can use as UITableView like to use our ZXOptionBar:

```swift
import UIKit

class ViewController: UIViewController,ZXOptionBarDelegate,ZXOptionBarDataSource {
    
    internal var optionBar: ZXOptionBar?
    override func viewDidLoad() {
        super.viewDidLoad()
        optionBar = ZXOptionBar(frame: CGRectMake(0, 100, UIScreen.mainScreen().bounds.size.width, 100), barDelegate: self, barDataSource: self)
        self.view.addSubview(optionBar!)
    }
    
    
    
    
    // MARK: - ZXOptionBarDataSource
    func numberOfColumnsInOptionBar(optionBar: ZXOptionBar) -> Int {
        return 20
    }
    func optionBar(optionBar: ZXOptionBar, cellForColumnAtIndex index: Int) -> ZXOptionBarCell {
        
        var cell: CustomOptionBarCell? = optionBar.dequeueReusableCellWithIdentifier("ZXOptionBarDemo") as? CustomOptionBarCell
        if cell == nil {
            cell = CustomOptionBarCell(style: .ZXOptionBarCellStyleDefault, reuseIdentifier: "ZXOptionBarDemo")
        }
        cell!.textLabel.text = "Bra-\(index)"
        return cell!
        
    }
    
    // MARK: - ZXOptionBarDelegate
    func optionBar(optionBar: ZXOptionBar, widthForColumnsAtIndex index: Int) -> Float {
        return 60
    }
    
    func optionBar(optionBar: ZXOptionBar, willDisplayCell cell: ZXOptionBarCell, forColumnAtIndex index: Int) {
        println(cell)
        println(index)
    }
    
    
}
```

`cellForColumnAtIndex` fact and` UITableView` of `cellForColumnAtIndex` similar, will call a called` dequeueReusableCellWithIdentifier` interface, this interface will ask to store reusable containers `reusableOptionCells` Cell there can be reused Cell, there is give me, did not return nil, I let `cellForColumnAtIndex` their new one, so that we can build the entire reuse chain out: 

1 a start reusing Cell `reusableOptionCells` container is empty, so all Cell are new. 
2 When a cell slide the screen when the cell is placed in `reusableOptionCells`. 
3 When a cell to slide the screen when you want to just `reusableOptionCells` reusable Cell, there will be reused, did not then create a. 


Written in the last ## 

** Note1: ** This article summarizes just pulled a OptionBar share core functionality (Cell reuse and data view separation), the reader can be inherited or due to rewrite the class according to their needs, add new features (for example: under standard indicator indicator, indicator of style, indicator of animation, animation category select category). 

** Note2: ** article only lists the core code, the specific code has been placed on Github: [ZXOptionBar-Swift] (https://github.com/zixun/ZXOptionBar-Swift), interested students can download . 
** Note3: ** within the team has done before this control Cell reuse a share, with a Keynote presentation, but with Objective-C described would be helpful for understanding. Keynote files are on Github.

