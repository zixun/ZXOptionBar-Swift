//
//  CustomOptionBarCell.swift
//  ZXOptionBar-Swift
//
//  Created by 子循 on 14-10-4.
//  Copyright (c) 2014年 zixun. All rights reserved.
//

import UIKit

class CustomOptionBarCell: ZXOptionBarCell {

    let textLabel: UILabel = {
        let label = UILabel(frame: CGRectZero)
        label.textAlignment = NSTextAlignment.Center
        label.font = UIFont.systemFontOfSize(12)
        return label
    }()
    
    let icon: UIImageView = {
        return UIImageView(frame: CGRectZero)
    }()
    
    override internal var index: Int? {
        didSet {
            if index != nil{
                textLabel.text = "bra-\(index!)"
            }

        }
    }
    
    override internal var selected: Bool {
        didSet {
            if selected {
                icon.image = UIImage(named: "bra_focus")
            }else{
                icon.image = UIImage(named: "bra")
            }
        }
    }
    
    override init(style: ZXOptionBarCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.addSubview(icon)
        self.addSubview(textLabel)
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    
    override func layoutSubviews() {
        icon.frame = CGRectMake(5, 20, 50, 50)
        textLabel.frame = CGRectMake(5, 80, 50, 10)
    }

}
