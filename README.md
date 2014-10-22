ZXOptionBar-Swift
=================

An optionbar view implement by Swift  and  reuse it's cells like UITableVIew
Inspired by [TWUI](https://github.com/twitter/twui)

---

这篇文章源于对一个可横向滚动并选择的类目控件的重构。最近在学`Swift`，所以把这个控件的核心逻辑（Cell重用）用`Swift`重写出来分享给大家。当然这不是Apple官方的Cell重用机制，因为Apple不开源.这篇文章应该会对正在学习`Swift`并且想了解Cell重用实现的同学有一定帮助。文章中涉及到的代码都放在了Github([ZXOptionBar-Swift](https://github.com/zixun/ZXOptionBar-Swift)),欢迎大家提issues，求血求虐求羞辱~

第一个版本中这个控件承载了数据、视图、动画等所有的逻辑，使得这个控件在后期变得很难维护。所以我必须重构这个控件，而想到`UITableView`也是一个可滚动可选择的控件，我为什么不把它做成一个类似`UITableView`一样的横向滚动的控件呢。通过`delegate`和`dataSource`把数据和动画从控件中分离出来，通过cell重用减小cell初始化的开支。

可是，Apple的`UIKit`不开源啊，怎么办呢？twitter为我们提供了很好的参考，那就是[TWUI](https://github.com/twitter/twui),这是twitter当年在MacOS上实现的类似`UIKit`的一个库，虽然已经2年没有更新了，但是里面还是有不少可以挖掘的好东西，比如Twitter版的`UITabelView`的Cell重用机制。

`UITableView`是分很多`section`的，但是横向滚动的控件一般只会有一种Cell，不会像`UITableView`一样需要分很多不同种类的Cell，所以我们可以改造[TWUI](https://github.com/twitter/twui)的Cell重用机制，使它更适合横向滚动的视图控件。

<!-- more -->

# 设计分析
* 需要通过`delegate`设计模式将数据和视图分离
* 需要用继承自`UIScrollView`的类来处理类似`UITableView`的逻辑(`ZXOptionBar`)
* 需要用继承自`UIView`的类来处理类似`UITableViewCell`的逻辑(`ZXOptionBarCell`)
* `ZXOptionBar`中需要一个容器来存放可以重用的Cell
* `ZXOptionBarCell`中需要一个容器来存放当前显示的Cell
* 使用`layoutSubviews()`方法来处理Cell重用逻辑
* 需要的工具方法:
	* 计算可见区域Rect `visibleRect()`
	* 计算可见的Cell的下标index `indexsForVisibleColumns()`
	* 计算指定区域Rect下的Cell的下标index `indexsForColumnInRect()`
	* 计算指定下标的Cell的Rect大小 `rectForColumnAtIndex()`


# 核心实现
## 通过delegate设计模式分离数据与视图
使用过`UITableView`的同学肯定知道，我们在使用`UITableView`的时候都是通过它的delegate和dataSource的代理方法将数据告诉我们的`UITableView`。`ZXOptionBar`也可以通过这样的方式将我们的数据和视图分离：

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

然后在ZXOptionBar中声明两个变量：
```swift
// Mark: Var
weak var barDataSource: ZXOptionBarDataSource?
weak var barDelegate: ZXOptionBarDelegate?
```
并且在初始化方法中对其赋值
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
心细的同学可能已经发现了，delegate和dataSource为什么在初始化方法里赋值啊，我记得 `UITableView`不是这样子的，一定是我打开的方式不对！限于这已经超出本文的范畴，想深入了解的可以看看Matt大神的[API Design](http://mattgemmell.com/api-design/),可以看看文中的**Rule 3: Required settings should be initializer parameters**,不过我建议大家花点时间全文阅读一遍，肯定受益匪浅！

## Cell重用逻辑实现
### 定义容器类
通过上面的办法我们可以把数据从我们的控件中分离出去，接下去就是最激动人心的时候了，我们需要实现我们的Cell重用的逻辑。
首先，我们申明两个Dictionary的容器类，一个用来存放可重用的Cell，一个用来存放当前屏幕显示的Cell
```swift
// MARK: Private Var
private var reusableOptionCells: Dictionary<String, NSMutableArray>!
private var visibleItems: Dictionary<String, ZXOptionBarCell>!
```
当然别忘了在我们的`convenience ` `init` 方法中对其赋值，这里我就不一一贴代码了，大家可以在我的Github上的[ZXOptionBar-Swift](https://github.com/zixun/ZXOptionBar-Swift)库自行下载代码对应这边博客阅读，这里只贴一些核心的关键代码。
### 重写layoutSubviews()
`layoutSubviews()`填塞所有Cell重用的逻辑，所以我们可以将一些独立模块的逻辑先抽离出来成一个个独立方法，读者可以先看看源码中以下几个方法先熟悉以下：
```swift
private func visibleRect() -> CGRect {
	...计算可见区域Rect
}
private func indexsForVisibleColumns() -> Array<String> {
	...计算可见的Cell的下标index
}
private func indexsForColumnInRect(rect: CGRect) -> Array<String> {
	...计算指定区域Rect下的Cell的下标index
}
private func rectForColumnAtIndex(index: Int) -> CGRect {
	...计算指定下标的Cell的Rect大小
}
```
好了，咱先来分析分析我们的逻辑
```swift
左滑前可见Cell的index:            0 1 2 3 4 5 6 7
左滑后可见Cell的index:                2 3 4 5 6 7 8 9
需要删除的Cell的index:            0 1
需要添加的Cell的index:                            8 9
```
这样我们就可以发现我们需要计算的信息了:

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

然后我们要做的就是将滚动出屏幕的Cell删除掉：
```swift
//delete the cells which frame out
for i in indexsToRemove {
	let cell: ZXOptionBarCell = self.cellForColumnAtIndex(self.indexFromIdentifyKey(i as String))!
	self.enqueueReusableCell(cell)
	cell.removeFromSuperview()
	self.visibleItems.removeValueForKey(i as String)
}
```   
`enqueueReusableCell()`方法就是将滚出屏幕的Cell放到我们的重用Cell容器中(`reusableOptionCells`),具体实现可以看工程源码。

最后就是将进入屏幕的Cell添加进来：
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

这里我们通过dataSource的 `cellForColumnAtIndex`和delegate的`willDisplayCell`来实现cell的构建和delegate的通知。

### 对外接口使用
这样我们就可以像使用UITableView一样使用我们的ZXOptionBar：

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

`cellForColumnAtIndex`其实和`UITableView`的`cellForColumnAtIndex`类似，都会调用一个叫`dequeueReusableCellWithIdentifier`的接口，这个接口会问存放重用Cell的容器`reusableOptionCells`有没有可以重用的Cell，有就给我，没有就返回nil，我让`cellForColumnAtIndex`自己新建一个，这样我们整个重用链就构建出来了：

1. 一开始重用Cell的容器`reusableOptionCells`是空的，所以所有的Cell都是新建的。
2. 当有cell滑出屏幕的时候这个cell被放入`reusableOptionCells`中。
3. 当有cell要滑入屏幕的时候就像`reusableOptionCells`要可重用的Cell，有就重用，没有就再新建一个。


## 写在最后

**Note1:**本篇文章只是抽离总结分享了一个OptionBar的核心功能（Cell重用和数据视图分离），读者可以根据自己应有的需要继承或者改写该类，添加新功能（比如：下标指示器indicator，indicator的样式，indicator的动画，类目选中动画之类的）。

**Note2:**文章中只是罗列了核心代码，具体代码已放在Github上：[ZXOptionBar-Swift](https://github.com/zixun/ZXOptionBar-Swift)，感兴趣的同学可以下载下来。
**Note3:**之前在团队内部做过一个这个控件的Cell重用的分享，用Keynote演示，不过是用Objective-C描述的，对于理解上会有帮助。Keynote文件也在Github上。


---
---

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

