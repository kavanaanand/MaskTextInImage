//
//  ViewController.swift
//  MaskTextInImage
//
//  Created by Kavana Anand on 3/16/23.
//

import UIKit
import CoreImage.CIFilterBuiltins

class ViewController: UIViewController {
    
    private let imageView = UIImageView()
    private let maskImageView = UIImageView()
    private let images = ["d1", "l1", "d2", "l2", "d3", "l3", "d4", "l4", "d5", "l5", "d6"];
}


extension ViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView.contentMode = .scaleAspectFit
        view.addSubview(imageView)
        
        maskImageView.contentMode = .scaleAspectFit
        view.addSubview(maskImageView)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        maskImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            maskImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            maskImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            imageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 50),
            imageView.bottomAnchor.constraint(equalTo: maskImageView.topAnchor),
            maskImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50),
            imageView.heightAnchor.constraint(equalTo: maskImageView.heightAnchor)
        ])
        
        var imageIndex: Int = 0
        
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [self] timer in
            guard imageIndex < images.count else {
                timer.invalidate()
                return
            }
            
            guard let image = UIImage(named:  images[imageIndex]) else {
                return
            }
            
            let cgImage = image.cgImage
            imageView.image = image
            
            // Find the colored mask
            guard cgImage != nil else {
                maskImageView.image = image
                return
            }

            let maskCgImage = colorizedMaskImage(cgImage!) ?? cgImage
            maskImageView.image = UIImage(cgImage: maskCgImage!)
            
            imageIndex = imageIndex + 1
        }
    }
}

extension ViewController {
    
    func colorizedMaskImage(_ image: CGImage) -> CGImage? {
        
        // BW mask
        let ciImage = CIImage(cgImage: image)
        
        let monoFilter = CIFilter.colorMonochrome()
        monoFilter.inputImage = ciImage
        monoFilter.color = CIColor(color: .white)
        monoFilter.intensity = 1.0
        
        let contrastFilter = CIFilter.colorControls()
        contrastFilter.inputImage = monoFilter.outputImage
        contrastFilter.contrast = 1.0
        contrastFilter.saturation = 1.0
        
        let posterize = CIFilter.colorPosterize()
        posterize.inputImage = contrastFilter.outputImage
        posterize.levels = 3
        
        guard let posterizedCIImage = posterize.outputImage,
              let posterizedImage = CIContext().createCGImage(posterizedCIImage, from: posterizedCIImage.extent) else {
            return nil
        }
        
        // Scan the first row pixels, retrive their white component, count the number of dark pixels
        var lightBackgroundCount = 0;
        for x in 0..<posterizedImage.width {
            let color = getPixelColor(posterizedImage, x, 0)
            var white: CGFloat = 0
            color.getWhite(&white, alpha: nil)
            if (white > 0.5) {
                lightBackgroundCount += 1
            }
        }
        var shouldInvert = false
        // Check if the number light pixels in the first row is more than half of the total pixels in the row
        // If that is true, the image has light background with dark text
        if (lightBackgroundCount > posterizedImage.width/2) {
            shouldInvert = true
        }
        
        var adjustedCIImage = posterize.outputImage
        if (shouldInvert) {
            // Invert the adjusted image so the dark text is highlighted
            let invert = CIFilter.colorInvert()
            invert.inputImage = posterize.outputImage
            adjustedCIImage = invert.outputImage
        }
        
        guard let ciImage = adjustedCIImage,
              let baseImage = CIContext().createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
//        return baseImage
        
        // Color
        let mainCIImage = CIImage(cgImage: image)
        let mask = CIImage(cgImage: baseImage)

        let maskToAlpha = CIFilter.maskToAlpha()
        maskToAlpha.inputImage = mask

        let blendFilter = CIFilter.blendWithAlphaMask()
        blendFilter.inputImage = mainCIImage
        blendFilter.maskImage = maskToAlpha.outputImage
        blendFilter.backgroundImage = CIImage()

        guard let blendedImage = blendFilter.outputImage else {
            return nil
        }

        guard let coloredTextOnTransparentBackgroundImage = CIContext().createCGImage(blendedImage, from: blendedImage.extent) else {
            return nil
        }
        return coloredTextOnTransparentBackgroundImage
    }
    
    func getPixelColor(_ cgImage: CGImage, _ x: Int, _ y: Int) -> UIColor {
        
        let pixelData = cgImage.dataProvider?.data
        let dataPtr = CFDataGetBytePtr(pixelData)
        
        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let pixelOffset = y * bytesPerRow + x * bytesPerPixel
        
        // Downsampling the image changed the format from RGBA to ARGB.
        // WHY?
        /* // RGBA
        let red = dataPtr![pixelOffset + 0]
        let green = dataPtr![pixelOffset + 1]
        let blue = dataPtr![pixelOffset + 2]
        let alpha = dataPtr![pixelOffset + 3]
         */
        
        // ARGB
        let alpha = dataPtr![pixelOffset + 0]
        let red = dataPtr![pixelOffset + 1]
        let green = dataPtr![pixelOffset + 2]
        let blue = dataPtr![pixelOffset + 3]
        
        let color = UIColor(red: CGFloat(red)/255.0, green: CGFloat(green)/255.0, blue: CGFloat(blue)/255.0, alpha: CGFloat(alpha)/255.0)
        return color
    }
    
}

