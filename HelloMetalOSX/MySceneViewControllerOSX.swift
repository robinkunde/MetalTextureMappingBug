//
//  MySceneViewController.swift
//  HelloMetal
//
//  Created by Andrew K. on 11/5/14.
//  Copyright (c) 2014 Razeware LLC. All rights reserved.
//

import Foundation

class MySceneViewControllerOSX: MetalViewControllerOSX, MetalViewControllerDelegateOSX {
    var worldModelMatrix:Matrix4!
    var objectToDraw: Cube!

    let panSensivity:Float = 5.0
    var lastPanLocation: CGPoint!

    override func viewDidLoad() {
        super.viewDidLoad()

        worldModelMatrix = Matrix4()
        worldModelMatrix.translate(0.0, y: 0.0, z: -4)
        worldModelMatrix.rotateAroundX(Matrix4.degreesToRad(25), y: 0.0, z: 0.0)

        objectToDraw = Cube(device: device, commandQ:commandQueue)
        self.metalViewControllerDelegate = self

        setupGestures()
    }

    //MARK: - MetalViewControllerDelegate
    func renderObjects(drawable:CAMetalDrawable) {
        objectToDraw.render(commandQueue, pipelineState: pipelineState, drawable: drawable, parentModelViewMatrix: worldModelMatrix, projectionMatrix: projectionMatrix, clearColor: nil)
    }

    func updateLogic(timeSinceLastUpdate: CFTimeInterval) {
        objectToDraw.updateWithDelta(timeSinceLastUpdate)
    }

    //MARK: - Gesture related
    func setupGestures() {
        let pan = NSPanGestureRecognizer(target: self, action: Selector("pan:"))
        self.view.addGestureRecognizer(pan)
    }

    func pan(panGesture: NSPanGestureRecognizer) {
        if panGesture.state == NSGestureRecognizerState.Changed {
            let pointInView = panGesture.locationInView(self.view)
            let xDelta = Float((lastPanLocation.x - pointInView.x)/self.view.bounds.width) * panSensivity
            let yDelta = Float((lastPanLocation.y - pointInView.y)/self.view.bounds.height) * panSensivity
            objectToDraw.rotationY -= xDelta
            objectToDraw.rotationX -= yDelta
            lastPanLocation = pointInView
        } else if panGesture.state == NSGestureRecognizerState.Began {
            lastPanLocation = panGesture.locationInView(self.view)
        }
    }
}
