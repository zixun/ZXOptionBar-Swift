//
//  ZXOptionBar.swift
//  ZXOptionBar-Swift
//
//  Created by 子循 on 14-9-30.
//  Copyright (c) 2014年 zixun. All rights reserved.
//

import UIKit

protocol ZXOptionBarDataSource: NSObjectProtocol {
    
    func numberOfColumnsInOptionBar(optionBar: ZXOptionBar) -> Int
    func optionBar(optionBar: ZXOptionBar, cellForColumnAtIndex index: Int) -> ZXOptionBarCell
}

@objc protocol ZXOptionBarDelegate: UIScrollViewDelegate {
    
    // Display customization
    optional func optionBar(optionBar: ZXOptionBar, willDisplayCell cell: ZXOptionBarCell, forColumnAtIndex index: Int)
    optional func optionBar(optionBar: ZXOptionBar, didEndDisplayingCell cell: ZXOptionBarCell, forColumnAtIndex index: Int)
    
    // Variable height support
    optional func optionBar(optionBar: ZXOptionBar, widthForColumnsAtIndex index: Int) -> Float
    
    //Select
    optional func optionBar(optionBar: ZXOptionBar, didSelectColumnAtIndexPath index: Int)
    optional func optionBar(optionBar: ZXOptionBar, didDeselectRowAtIndexPath index: Int)
    
    //Reload
    optional func optionBarWillReloadData(optionBar: ZXOptionBar)
    optional func optionBarDidReloadData(optionBar: ZXOptionBar)

}


class ZXOptionBar: UIScrollView {
    
    weak var barDataSource: ZXOptionBarDataSource?
    weak var barDelegate: ZXOptionBarDelegate?
    internal var selectedIndex: Int?
    
    private var reusableOptionCells: Dictionary<String, NSMutableArray>!
    
    private var visibleItems: Dictionary<String, ZXOptionBarCell>!
    
    //flags
    private var flag_layoutSubviewsReentrancyGuard: Bool = true
    
    convenience init(frame: CGRect, barDelegate: ZXOptionBarDelegate, barDataSource:ZXOptionBarDataSource ) {
        self.init(frame: frame)
        self.delegate = delegate
        self.barDataSource = barDataSource
        self.barDelegate = barDelegate

        self.showsHorizontalScrollIndicator = false
        self.showsVerticalScrollIndicator = false
        self.backgroundColor = UIColor.whiteColor()
        self.scrollsToTop = false
        
        var totleWidth: Float = 0.0;
        for i in 0...(self.columnCount()-1) {
            totleWidth += self.columnWidthAtIndex(i)
        }
        self.contentSize = CGSizeMake(CGFloat(totleWidth), self.bounds.size.height);
        
        reusableOptionCells = Dictionary<String, NSMutableArray>()
        visibleItems = Dictionary<String, ZXOptionBarCell>()
        
    }
    
    internal func dequeueReusableCellWithIdentifier(identifier: String) -> AnyObject? {
        let array: NSMutableArray? = self.reusableOptionCells[identifier]
        if array != nil {
            if var c: AnyObject = array!.lastObject {
                array!.removeLastObject()
                c.prepareForReuse()
                return c
            }
        }
        return nil
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if flag_layoutSubviewsReentrancyGuard {
            flag_layoutSubviewsReentrancyGuard = false
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.layoutCells()
            CATransaction.commit()
            
            flag_layoutSubviewsReentrancyGuard = true
        }
    }
    
    private func layoutCells() {
        var visible = self.visibleRect()
        // Example:
        // old:            0 1 2 3 4 5 6 7
        // new:                2 3 4 5 6 7 8 9
        // to remove:      0 1
        // to add:                         8 9
        
        let oldVisibleIndex: Array<String> = self.indexsForVisibleColumns()
        let newVisibleIndex: Array<String> = self.indexsForColumnInRect(visible)
        
        var indexsToRemove: NSMutableArray = NSMutableArray(array: oldVisibleIndex)
        indexsToRemove.removeObjectsInArray(newVisibleIndex)
        
        var indexsToAdd: NSMutableArray = NSMutableArray(array: newVisibleIndex)
        indexsToAdd.removeObjectsInArray(oldVisibleIndex)
        
        
        //delete the cells which frame out
        for i in indexsToRemove {
            let cell: ZXOptionBarCell = self.cellForColumnAtIndex(self.indexFromIdentifyKey(i as String))
            self.enqueueReusableCell(cell)
            cell.removeFromSuperview()
            self.visibleItems.removeValueForKey(i as String)
        }
        
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
            let isResponds: Bool = self.barDelegate!.respondsToSelector(Selector("optionBar:willDisplayCell:forColumnAtIndex:"))
            if isResponds {
                self.barDelegate!.optionBar!(self, willDisplayCell: cell, forColumnAtIndex: indexToAdd)
            }
            self.addSubview(cell)
            self.visibleItems.updateValue(cell, forKey: (i as String))
            
        }
    }

    private func enqueueReusableCell(cell: ZXOptionBarCell) {
        if let identifier: String = cell.reuseIdentifier {
            var array: NSMutableArray? = self.reusableOptionCells[identifier]
            if (array == nil) {
                array = NSMutableArray()
                self.reusableOptionCells.updateValue(array!, forKey: identifier)
            }
            array?.addObject(cell)
            
        }else{
            return
        }
    }
    
    private func visibleRect() -> CGRect {
        return CGRectMake(self.contentOffset.x, self.contentOffset.y, self.bounds.size.width, self.bounds.size.height)
    }
    
    private func indexsForVisibleColumns() -> Array<String> {
        var keyArr: [String] = []
        for (key, _) in self.visibleItems {
            keyArr.append(key)
        }
        return keyArr
    }
    
    private func indexsForColumnInRect(rect: CGRect) -> Array<String> {
        
        var indexs: [String] = []
        for column in 0...(self.columnCount()-1) {
            var cellRect: CGRect = self.rectForColumnAtIndex(column)
            if CGRectIntersectsRect(cellRect, rect) {
                indexs.append(self.identifyKeyFromIndex(column))
            }
        }
        return indexs
    }

    private func columnCount() -> Int {
        return self.barDataSource!.numberOfColumnsInOptionBar(self)
    }
    
    private func columnWidthAtIndex(index: Int) -> Float {
        if let result = self.barDelegate!.optionBar?(self, widthForColumnsAtIndex: index) {
            return result
        }else{
            return 0.0
        }
    }
    
    private func rectForColumnAtIndex(index: Int) -> CGRect {
        let width: Float = self.columnWidthAtIndex(index);
        return CGRectMake(CGFloat(width * Float(index)), 0, CGFloat(width), self.bounds.size.height)
    }
    
    private func cellForColumnAtIndex(index: Int) -> ZXOptionBarCell {
        return self.visibleItems[self.identifyKeyFromIndex(index)]!
    }
    
    
    private func identifyKeyFromIndex(index: Int) -> String {
        return "\(index)"
    }
    
    private func indexFromIdentifyKey(identifyKey: String) -> Int {
        if let index = identifyKey.toInt() {
            return index
        }else{
            return 0
        }
    }
    
}