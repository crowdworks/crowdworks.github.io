current_branch = ENV['WERCKER_GIT_BRANCH']

if current_branch.nil? || current_branch.empty?
  current_branch = `git symbolic-ref -q HEAD --short`.chomp
end

if current_branch == 'source'
  env = {}
else
  env = {
    'MIDDLEMAN_SYNC_PREFIX' => current_branch,
    'MIDDLEMAN_HTTP_PREFIX' => current_branch
  }
end

env_vars = env.map { |name,value| "#{name}=#{value}" }.join(' ')

desc "Build the blog from source"
task :build do
  parts = [env_vars, "bundle exec middleman build"]
  command = parts.select { |part| part.size > 0 }.join(' ')
  puts "Building the branch:\n  `#{current_branch}`"
  puts "Running the command:\n  `#{command}`"
  system command
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
  system command
end
