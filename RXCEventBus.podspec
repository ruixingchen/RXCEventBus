Pod::Spec.new do |spec|

  spec.name         = "RXCEventBus"
  spec.version      = "1.1"
  spec.summary      = "a event bus that send events to multi targets."
  spec.description  = "a event bus that send events to multi targets"
  spec.homepage     = "https://github.com/ruixingchen/RXCEventBus"
  spec.license      = "MIT"

  spec.author       = { "ruixingchen" => "rxc@ruixingchen.com" }
  spec.platform     = :ios, "8.0"

  spec.source       = { :git => "https://github.com/ruixingchen/RXCEventBus.git", :tag => spec.version.to_s }
  spec.source_files  = "Source", "Source/**/*.{swift}"
  spec.framework = "Foundation"

  spec.requires_arc = true
  spec.swift_versions = "5.0"

end