
Pod::Spec.new do |s|
  s.name         = "RNEthereum"
  s.version      = "1.0.0"
  s.summary      = "React Native Ethereum Library"
  s.description  = "React Native Ethereum Library"
  s.homepage     = "https://getty.io"
  s.license      = "MIT"
  s.author       = { "Brandon Holland" => "bholland@brandon-holland.com" }
  s.platform     = :ios, "9.0"
  s.source       = { :git => "https://github.com/gettyio/react-native-ethereum.git" }
  s.source_files = "RNEthereum/**/*.{h,m,c}"
  s.requires_arc = true
  
  s.dependency "React"
  s.dependency "NSData+FastHex"
end
