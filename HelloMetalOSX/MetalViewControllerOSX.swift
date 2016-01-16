//
//  ViewController.swift
//  HelloMetal
//
//  Created by Main Account on 10/2/14.
//  Copyright (c) 2014 Razeware LLC. All rights reserved.
//

import Foundation
import Metal
import QuartzCore

protocol MetalViewControllerDelegateOSX : class {
    func updateLogic(timeSinceLastUpdate:CFTimeInterval)
    func renderObjects(drawable:CAMetalDrawable)
}

class MetalViewControllerOSX: NSViewController {
    var device: MTLDevice! = nil
    var metalLayer: CAMetalLayer! = nil
    var pipelineState: MTLRenderPipelineState! = nil
    var commandQueue: MTLCommandQueue! = nil
    var timer: CVDisplayLink?
    var projectionMatrix: Matrix4!
    var lastFrameTimestamp: CFTimeInterval = 0.0

    weak var metalViewControllerDelegate: MetalViewControllerDelegateOSX?

    override func loadView() {
        super.loadView()

        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        projectionMatrix = Matrix4.makePerspectiveViewAngle(Matrix4.degreesToRad(85.0), aspectRatio: Float(self.view.bounds.size.width / self.view.bounds.size.height), nearZ: 0.01, farZ: 100.0)

        device = MTLCreateSystemDefaultDevice()
        metalLayer = CAMetalLayer()
        metalLayer.device = device
        metalLayer.pixelFormat = .BGRA8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.frame = view.layer!.frame
        view.layer!.addSublayer(metalLayer)


        commandQueue = device.newCommandQueue()

        let defaultLibrary = device.newDefaultLibrary()
        let fragmentProgram = defaultLibrary!.newFunctionWithName("basic_fragment")
        let vertexProgram = defaultLibrary!.newFunctionWithName("basic_vertex")


        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm
        pipelineStateDescriptor.colorAttachments[0].blendingEnabled = true
        pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperation.Add;
        pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperation.Add;
        pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactor.One;
        pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactor.One;
        pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactor.OneMinusSourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactor.OneMinusSourceAlpha;

        do {
            pipelineState = try device.newRenderPipelineStateWithDescriptor(pipelineStateDescriptor)
        } catch let error as NSError {
            print("Failed to create pipeline state, error \(error.localizedDescription)")
        }

        func displayLinkOutputCallback(displayLink: CVDisplayLink, _ inNow: UnsafePointer<CVTimeStamp>, _ inOutputTime: UnsafePointer<CVTimeStamp>, _ flagsIn: CVOptionFlags, _ flagsOut: UnsafeMutablePointer<CVOptionFlags>, _ displayLinkContext: UnsafeMutablePointer<Void>) -> CVReturn {

            let time = Double(inNow.memory.videoTime) / 1000000000.0;
            unsafeBitCast(displayLinkContext, MetalViewControllerOSX.self).newFrame(time)

            return kCVReturnSuccess
        }

        CVDisplayLinkCreateWithActiveCGDisplays(&timer)
        CVDisplayLinkSetOutputCallback(timer!, displayLinkOutputCallback, UnsafeMutablePointer<Void>(unsafeAddressOf(self)))
        CVDisplayLinkStart(timer!)
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        if let window = view.window {
            let scale = window.screen!.backingScaleFactor
            let layerSize = view.bounds.size

            metalLayer.frame = CGRectMake(0, 0, layerSize.width, layerSize.height)
            metalLayer.drawableSize = CGSizeMake(layerSize.width * scale, layerSize.height * scale)
        }
        projectionMatrix = Matrix4.makePerspectiveViewAngle(Matrix4.degreesToRad(85.0), aspectRatio: Float(self.view.bounds.size.width / self.view.bounds.size.height), nearZ: 0.01, farZ: 100.0)
    }

    func render() {
        if let drawable = metalLayer.nextDrawable(){
            self.metalViewControllerDelegate?.renderObjects(drawable)
        }
    }

    func newFrame(time: Double) {
        if lastFrameTimestamp == 0.0 {
            lastFrameTimestamp = time
        }

        let elapsed: CFTimeInterval = time - lastFrameTimestamp
        gameloop(timeSinceLastUpdate: elapsed)

        lastFrameTimestamp = time
    }

    func gameloop(timeSinceLastUpdate timeSinceLastUpdate: CFTimeInterval) {
        self.metalViewControllerDelegate?.updateLogic(timeSinceLastUpdate)

        autoreleasepool {
            self.render()
        }
    }
}
