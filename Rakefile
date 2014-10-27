current_branch = ENV['WERCKER_GIT_BRANCH']

if current_branch.nil? || current_branch.empty?
  current_branch = `git symbolic-ref -q HEAD --short`.chomp
end

if current_branch == 'source'
  env = {}
else
  prefix = current_branch.gsub(/[^a-zA-Z0-9\-]/, '-')
  env = {
    'MIDDLEMAN_SYNC_PREFIX' => prefix,
    'MIDDLEMAN_HTTP_PREFIX' => prefix
  }
end

env_vars = env.map { |name,value| "#{name}=#{value}" }.join(' ')

desc "Build the blog from source"
task :build do
  parts = [env_vars, "bundle exec middleman build"]
  command = parts.select { |part| part.size > 0 }.join(' ')
  puts "Building the branch:\n  `#{current_branch}`"
  puts "Running the command:\n  `#{command}`"
  system(command) || exit(1)
end

desc "Build the blog to the target according to current branch"
task :deploy do
  if current_branch == 'source' || current_branch == 'HEAD'
    middleman_command = 'deploy'
  else
    middleman_command = 's3_sync'
  end

  parts = [env_vars, "bundle exec middleman #{middleman_command}"]
  command = parts.select { |part| part.size > 0 }.join(' ')
  puts "Deploying the branch:\n  `#{current_branch}`"
  puts "Running the command:\n  `#{command}`"
  system(command) || exit(1)
end
