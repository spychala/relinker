require 'mina/multistage'
require 'mina/git'

set :keep_releases, 5
set :shared_paths, ['config/database.yml', 'config/puma.rb', 'tmp']
set :stages, %w(staging production)
set :forward_agent, true # SSH forward_agent.

task :setup => :environment do
  queue! %[mkdir -p "#{deploy_to}/#{shared_path}/tmp/puma"]
  queue! %[mkdir -p "#{deploy_to}/#{shared_path}/logs"]
  queue! %[chmod g+rwx,u+rwx "#{deploy_to}/#{shared_path}/logs"]

  queue! %[touch "#{deploy_to}/#{shared_path}/config/database.yml"]
  queue  %[echo "-----> Be sure to edit '#{deploy_to}/#{shared_path}/config/database.yml'."]

 if repository
   repo_host = repository.split(%r{@|://}).last.split(%r{:|\/}).first
   repo_port = /:([0-9]+)/.match(repository) && /:([0-9]+)/.match(repository)[1] || '22'

   queue %[
     if ! ssh-keygen -H  -F #{repo_host} &>/dev/null; then
       ssh-keyscan -t rsa -p #{repo_port} -H #{repo_host} >> ~/.ssh/known_hosts
     fi
   ]
 end
end

desc "Deploys the current version to the server."
task :deploy => :environment do
  to :before_hook do
    # Put things to run locally before ssh
  end
  deploy do
    # Put things that will set up an empty directory into a fully set-up
    # instance of your project.
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    queue! %[source ~/.profile && rvm default do bundle install]
    invoke :'deploy:cleanup'
    queue! %[~/bin/#{stage}.sh restart]
  end
end
