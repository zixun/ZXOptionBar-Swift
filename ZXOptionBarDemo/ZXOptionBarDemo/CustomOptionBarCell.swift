//
//  CustomOptionBarCell.swift
//  ZXOptionBar-Swift
//
//  Created by 子循 on 14-10-4.
//  Copyright (c) 2014年 zixun. All rights reserved.
//

import UIKit

class CustomOptionBarCell: ZXOptionBarCell {

    var textLabel: UILabel?
    
    override internal var index: Int? {
        didSet {
            if index != nil{
                textLabel?.text = "\(index!)"
            }

        }
    }
    
    override init(style: ZXOptionBarCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        
        textLabel = UILabel(frame: CGRectZero)
        textLabel!.backgroundColor = UIColor.blueColor()
        textLabel!.textAlignment = .Center
        textLabel?.font = UIFont.systemFontOfSize(12)
        self.addSubview(textLabel!)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func layoutSubviews() {
        textLabel?.frame = CGRectMake(self.bounds.size.width*0.1, 0, self.bounds.size.width*0.8, 60)
        textLabel?.text = "\(index!)"
    }

}
