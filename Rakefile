# bundle exec rake build_image DIR="." REPO="runner" TAG="v1"
task :build_image do
  image = Docker::Image.build_from_dir(ENV['DIR'] || '.')
  image.tag repo: ENV['REPO'], tag: ENV['TAG']
end
