# config valid only for Capistrano 3.1
lock '3.1.0'

set :application, 'projects'
set :repo_url, 'git@github.com:kimimaro/projects.git'

set :deploy_user, 'deploy'

# rbenv
set :rbenv_type, :user
set :rbenv_ruby, '2.0.0-p645'
set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
set :rbenv_map_bins, %w{rake gem bundle ruby rails}

# bundler
set :bundle_roles, :all                                         # this is default
set :bundle_servers, -> { release_roles(fetch(:bundle_roles)) } # this is default
set :bundle_binstubs, -> { shared_path.join('bin') }            # default: nil
set :bundle_gemfile, -> { release_path.join('Gemfile') }        # default: nil
set :bundle_path, -> { shared_path.join('bundle') }             # this is default
set :bundle_without, %w{development test}.join(' ')             # this is default
set :bundle_flags, '--deployment --quiet'                       # this is default
set :bundle_env_variables, {}                                   # this is default

# Default branch is :master
# ask :branch, proc { `git re``v-parse --abbrev-ref HEAD`.chomp }

# Default deploy_to directory is /var/www/my_app
# set :deploy_to, '/var/www/my_app'

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# will upload in tasks
# Default value for :linked_files is []
# set :linked_files, %w{config/database.yml}

# Default value for linked_dirs is []
set :linked_dirs, %w{bin log bundle tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

# namespace :unicorn do
#   task :start, :roles => :app, :except => { :no_release => true } do 
#     run "cd #{current_path} && #{try_sudo} #{unicorn_binary} -c #{unicorn_config} -E #{rails_env} -D"
#   end
#   task :stop, :roles => :app, :except => { :no_release => true } do 
#     run "#{try_sudo} kill `cat #{unicorn_pid}`"
#   end
#   task :graceful_stop, :roles => :app, :except => { :no_release => true } do
#     run "#{try_sudo} kill -s QUIT `cat #{unicorn_pid}`"
#   end
#   task :reload, :roles => :app, :except => { :no_release => true } do
#     run "#{try_sudo} kill -s USR2 `cat #{unicorn_pid}`"
#   end
#   task :restart, :roles => :app, :except => { :no_release => true } do
#     stop
#     start
#   end
# end

namespace :deploy do

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      # Your restart mechanism here, for example:
      # execute :touch, release_path.join('tmp/restart.txt')
    end
  end

  desc "Makes sure local git is in sync with remote."
  task :check_revision do
    unless `git rev-parse HEAD` == `git rev-parse origin/master`
      puts "WARNING: HEAD is not the same as origin/master"
      puts "Run `git push` to sync changes."
      exit
    end
  end

  # still need to start nginx first
  # still need to upload unicorn_projects to /etc/init.d path first!
  %w[start stop restart].each do |command|
    desc "#{command} unicorn server."
    task command do
      on roles(:app) do
        execute "/etc/init.d/unicorn_#{fetch(:application)} #{command}"
        # execute "service nginx restart"
      end
    end
  end

  task :link_db do
    on roles(:app) do
      execute "ln -s #{shared_path}/config/database.yml #{release_path}/config/database.yml"
    end
  end

  task :setup do
    # need no-passwd ssh to deploy user first!
    on roles(:app) do
      execute "mkdir -p #{shared_path}/config"
    end
    sh "scp config/database.yml deploy@oneboxapp.com:#{shared_path}/config/database.yml"
  end

  before :deploy, "deploy:check_revision"

  before "deploy:link_db", "deploy:setup"
  before "deploy:assets:precompile", "deploy:link_db"

  after :publishing, :restart

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end
end
