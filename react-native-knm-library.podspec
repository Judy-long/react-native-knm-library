
Pod::Spec.new do |s|
  s.name         = "react-native-knm-library"
  s.version      = "1.0.0"
  s.summary      = "GWKnmLibrary"
  s.description  = <<-DESC
                  GWKnmLibrary
                   DESC
  s.homepage     = "https://github.com/Judy-long/react-native-knm-library"
  s.license      = "MIT"
  # s.license      = { :type => "MIT", :file => "FILE_LICENSE" }
  s.author             = { "judy" => "judy__long@163.com" }
  s.platform     = :ios, "7.0"
  s.source = { :git => 'https://github.com/Judy-long/react-native-knm-library.git', :tag => '1.0.0' }
  s.source_files  = "ios/**/*.{h,m,mm,swift}"
  s.requires_arc = true


  s.dependency "React-Core", "~> 0.68.5"
  s.dependency "CocoaAsyncSocket"

end

  
