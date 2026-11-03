#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint LinklanEuiccIOS.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'linklan_euicc'
  s.version          = '1.1.0'
  s.summary          = 'Linklan eUICC iOS SDK'
  s.description      = <<-DESC
Linklan eUICC iOS SDK, including necessary frameworks for eSIM management.
                       DESC
  s.homepage         = 'https://github.com/huangzhangliang/LinklanEuiccIOS'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'huangzhangliang' => '82770536@qq.com' }

  s.source           = { :path => '.' }

  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'LinklanEuiccIOS', '~> 1.3.6'

  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-ObjC -all_load',
  }
end