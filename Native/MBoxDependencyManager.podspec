
require 'yaml'
yaml = YAML.load_file('../manifest.yml')
name = yaml["NAME"]
name2 = name.sub('MBox', 'mbox').underscore
version = ENV["VERSION"] || yaml["VERSION"]

Pod::Spec.new do |spec|
  spec.name         = "#{name}"
  spec.version      = "#{version}"
  spec.summary      = "MBox Plugin MBoxDependencyManager."
  spec.description  = <<-DESC
    A MBox Plugin MBoxDependencyManager.
                   DESC

  spec.homepage     = "https://github.com/MBoxSpace/#{name2}.git"
  spec.license      = "MIT"
  spec.author       = { `git config user.name`.strip => `git config user.email`.strip }

  spec.source       = { :git => "git@github.com:MBoxSpace/#{name2}.git", :tag => "#{spec.version}" }
  spec.platform     = :osx, '10.15'

  spec.subspec 'Core' do |ss|
    ss.source_files = "#{name}/*.{h,m,mm,swift,c,cpp}", "#{name}/**/*.{h,m,mm,swift,c,cpp}"

    yaml['DEPENDENCIES'].each do |name|
      ss.dependency name
    end

  end
end
