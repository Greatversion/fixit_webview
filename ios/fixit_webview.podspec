Pod::Spec.new do |s|
  s.name             = 'fixit_webview'
  s.version = '0.11.0-beta.3'
  s.summary          = 'Core WebView Engine for the Fixit Runtime SDK'
  s.description      = 'Production-grade iOS engine wrapping WKWebView.'
  s.homepage         = 'https://github.com/fixit/fixit_engine'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Fixit' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
