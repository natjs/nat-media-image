Pod::Spec.new do |s|

  # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.name         = "NatImage"
  s.version      = "0.0.8"
  s.summary      = "Nat.js Module: Image."
  s.description  = <<-DESC
                    Nat.js Module: Image (info or preview or pick or exif)
                   DESC
  s.homepage     = "http://natjs.com"
  s.license      = "MIT"
  s.author       = { "nat" => "hi@natjs.com" }

  s.platform     = :ios, "7.0"
  s.source       = { :git => "https://github.com/natjs/nat-media-image.git", :tag => s.version }

  s.source_files  = "ios/Classes/*.{h,m}", "ios/Classes/MWPhotoBrowser/Pod/*/*.{h,m}"
  s.resources =  "ios/Classes/MWPhotoBrowser/Pod/Assets/*.png"

  s.frameworks = 'ImageIO', 'QuartzCore', 'AssetsLibrary', 'MediaPlayer'
  s.weak_frameworks = 'Photos'

  s.requires_arc = true

  s.dependency "TZImagePickerController", "~> 2.1.6"
  s.dependency 'MBProgressHUD', '~> 1.0.0'
  s.dependency 'DACircularProgress', '~> 2.3'
  s.dependency 'SDWebImage', '~> 3.7.5'

end
