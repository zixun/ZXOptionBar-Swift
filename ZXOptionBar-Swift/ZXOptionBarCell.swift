//
//  ZXOptionBarCell.swift
//  ZXOptionBar-Swift
//
//  Created by 子循 on 14-10-3.
//  Copyright (c) 2014年 zixun. All rights reserved.
//

import UIKit

enum ZXOptionBarCellStyle{
    case ZXOptionBarCellStyleDefault
}

// MARK: - ZXOptionBarCell
class ZXOptionBarCell: UIView {
    
    // MARK: Internal Var
    internal var index: Int?
    
    internal var indicatorColor: UIColor?
    
    internal var optionBar: ZXOptionBar? { return self.superview as? ZXOptionBar }
    
    internal var selected: Bool {
        get { return optionBarCellDidSelectedFlag }
        set { optionBarCellDidSelectedFlag = newValue }
    }
    
    // MARK: ReadOnly Var
    private(set) var reuseIdentifier: String?
    
    // MARK: Private Var
    private var optionBarCellDidMovedFlag: Bool = false
    
    private var optionBarCellDidSelectedFlag: Bool = false
    
    
    internal init(style: ZXOptionBarCellStyle, reuseIdentifier: String?) {
        super.init(frame: CGRectZero)
        self.reuseIdentifier = reuseIdentifier
        
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    internal func prepareForReuse() {
        self.index = nil
        self.indicatorColor = nil
        self.removeAllAnimations()
        self.setNeedsDisplay()
    }
    
    internal func prepareForDisplay() {
        self.removeAllAnimations()
    }
}

extension ZXOptionBarCell {
    override func touchesBegan(touches: NSSet, withEvent event: UIEvent) {
        super.touchesBegan(touches, withEvent: event)
        optionBarCellDidMovedFlag = false
    }
    
    override func touchesMoved(touches: NSSet, withEvent event: UIEvent) {
        super.touchesMoved(touches, withEvent: event)
        optionBarCellDidMovedFlag = true
    }
    
    override func touchesEnded(touches: NSSet, withEvent event: UIEvent) {
        super.touchesEnded(touches, withEvent: event)
        if optionBarCellDidMovedFlag == false {
            
            self.optionBar?.selectColumnAtIndex(self.index!, origin: ZXOptionBarOrigin.ZXOptionBarOriginTap)
        }
    }
    
    override func touchesCancelled(touches: NSSet!, withEvent event: UIEvent!) {
        super.touchesCancelled(touches, withEvent: event)
        optionBarCellDidMovedFlag = false
    }
}

// MARK: - ZXOptionBarCell - Private Extension
extension ZXOptionBarCell {
    private func removeAllAnimations() {
        self.layer.removeAllAnimations()
        for view in self.subviews {
            view.layer.removeAllAnimations()
        }
    }
}
