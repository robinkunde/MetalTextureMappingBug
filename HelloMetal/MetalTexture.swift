//
//  MetalTexture.swift
//  MetalKernelsPG
//
//  Created by Andrew K. on 10/20/14.
//  Copyright (c) 2014 Andrew K. All rights reserved.
//

import UIKit
import Metal

class MetalTexture: NSObject {
    var texture: MTLTexture!
    var target: MTLTextureType!
    var width: Int!
    var height: Int!
    var depth: Int!
    var format: MTLPixelFormat!
    var hasAlpha: Bool!
    var path: String!
    var isMipmaped: Bool!
    let bytesPerPixel:Int! = 4
    let bitsPerComponent:Int! = 8

    //MARK: - Creation
    init(resourceName: String,ext: String, mipmaped:Bool) {
        path = NSBundle.mainBundle().pathForResource(resourceName, ofType: ext)
        width    = 0
        height   = 0
        depth    = 1
        format   = MTLPixelFormat.RGBA8Unorm
        target   = MTLTextureType.Type2D
        texture  = nil
        isMipmaped = mipmaped

        super.init()
    }

    func loadTexture(device device: MTLDevice, commandQ: MTLCommandQueue, flip: Bool) {
        let image = UIImage(contentsOfFile: path)?.CGImage
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        width = CGImageGetWidth(image)
        height = CGImageGetHeight(image)

        let rowBytes = width * bytesPerPixel

        let context = CGBitmapContextCreate(nil, width, height, bitsPerComponent, rowBytes, colorSpace, CGImageAlphaInfo.PremultipliedLast.rawValue)
        let bounds = CGRect(x: 0, y: 0, width: Int(width), height: Int(height))
        CGContextClearRect(context, bounds)

        if flip == false {
            CGContextTranslateCTM(context, 0, CGFloat(height))
            CGContextScaleCTM(context, 1.0, -1.0)
        }

        CGContextDrawImage(context, bounds, image)

        let texDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(MTLPixelFormat.RGBA8Unorm, width: Int(width), height: Int(height), mipmapped: isMipmaped)
        target = texDescriptor.textureType
        texture = device.newTextureWithDescriptor(texDescriptor)

        let pixelsData = CGBitmapContextGetData(context)
        let region = MTLRegionMake2D(0, 0, Int(width), Int(height))
        texture.replaceRegion(region, mipmapLevel: 0, withBytes: pixelsData, bytesPerRow: Int(rowBytes))

        if (isMipmaped == true) {
            generateMipMapLayersUsingSystemFunc(texture, device: device, commandQ: commandQ, block: { (buffer) -> Void in
                print("mips generated")
            })
        }

        print("mipCount:\(texture.mipmapLevelCount)")
    }

    class func textureCopy(source source:MTLTexture,device: MTLDevice, mipmaped: Bool) -> MTLTexture {
        let texDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(MTLPixelFormat.BGRA8Unorm, width: Int(source.width), height: Int(source.height), mipmapped: mipmaped)
        let copyTexture = device.newTextureWithDescriptor(texDescriptor)


        let region = MTLRegionMake2D(0, 0, Int(source.width), Int(source.height))
        let pixelsData = malloc(source.width * source.height * 4)
        source.getBytes(pixelsData, bytesPerRow: Int(source.width) * 4, fromRegion: region, mipmapLevel: 0)
        copyTexture.replaceRegion(region, mipmapLevel: 0, withBytes: pixelsData, bytesPerRow: Int(source.width) * 4)
        return copyTexture
    }

    class func copyMipLayer(source source:MTLTexture, destination:MTLTexture, mipLvl: Int) {
        let q = Int(powf(2, Float(mipLvl)))
        let mipmapedWidth = max(Int(source.width)/q,1)
        let mipmapedHeight = max(Int(source.height)/q,1)

        let region = MTLRegionMake2D(0, 0, mipmapedWidth, mipmapedHeight)
        let pixelsData = malloc(mipmapedHeight * mipmapedWidth * 4)
        source.getBytes(pixelsData, bytesPerRow: mipmapedWidth * 4, fromRegion: region, mipmapLevel: mipLvl)
        destination.replaceRegion(region, mipmapLevel: mipLvl, withBytes: pixelsData, bytesPerRow: mipmapedWidth * 4)
        free(pixelsData)
    }

    //MARK: - Generating UIImage from texture mip layers
    func image(mipLevel mipLevel: Int) -> UIImage {
        let p = bytesForMipLevel(mipLevel: mipLevel)
        let q = Int(powf(2, Float(mipLevel)))
        let mipmapedWidth = max(width / q,1)
        let mipmapedHeight = max(height / q,1)
        let rowBytes = mipmapedWidth * 4

        let colorSpace = CGColorSpaceCreateDeviceRGB()

        let context = CGBitmapContextCreate(p, mipmapedWidth, mipmapedHeight, 8, rowBytes, colorSpace, CGImageAlphaInfo.PremultipliedLast.rawValue)
        let imgRef = CGBitmapContextCreateImage(context)!
        let image = UIImage(CGImage: imgRef)
        return image
    }

    func image() -> UIImage {
        return image(mipLevel: 0)
    }

    //MARK: - Getting raw bytes from texture mip layers
    func bytesForMipLevel(mipLevel mipLevel: Int) -> UnsafeMutablePointer<Void> {
        let q = Int(powf(2, Float(mipLevel)))
        let mipmapedWidth = max(Int(width) / q,1)
        let mipmapedHeight = max(Int(height) / q,1)

        let rowBytes = Int(mipmapedWidth * 4)

        let region = MTLRegionMake2D(0, 0, mipmapedWidth, mipmapedHeight)
        let pointer = malloc(rowBytes * mipmapedHeight)
        texture.getBytes(pointer, bytesPerRow: rowBytes, fromRegion: region, mipmapLevel: mipLevel)
        return pointer
    }

    func bytes() -> UnsafeMutablePointer<Void> {
        return bytesForMipLevel(mipLevel: 0)
    }

    func generateMipMapLayersUsingSystemFunc(texture: MTLTexture, device: MTLDevice, commandQ: MTLCommandQueue,block: MTLCommandBufferHandler) {

        let commandBuffer = commandQ.commandBuffer()

        commandBuffer.addCompletedHandler(block)

        let blitCommandEncoder = commandBuffer.blitCommandEncoder()

        blitCommandEncoder.generateMipmapsForTexture(texture)
        blitCommandEncoder.endEncoding()

        commandBuffer.commit()
    }
}
