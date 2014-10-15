//
//  ViewController.swift
//  ZXOptionBarDemo
//
//  Created by 子循 on 14-10-4.
//  Copyright (c) 2014年 zixun. All rights reserved.
//

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
    
    func optionBar(optionBar: ZXOptionBar, didSelectColumnAtIndex index: Int) {
        println(index)
    }
    
}

