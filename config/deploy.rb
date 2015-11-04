# config valid only for Capistrano 3.1
lock '3.1.0'

# to get 'sh' method work
include Rake::DSL

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
set :deploy_to, "/var/www/#{fetch(:application)}"

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

namespace :unicorn do

  # -> { shared_path.join('bin') }
  set :unicorn_binary, "/home/deploy/.rbenv/shims/bundle exec unicorn"
  set :unicorn_config, -> { current_path.join('config/unicorn.rb') } # /home/deploy/apps/projects

  # lambda表达式会影响 shared_path 的值，保证 shared_path 是预期的值
  set :unicorn_pid, -> { shared_path.join("tmp/pids/unicorn.#{fetch(:application)}.pid") } # /home/deploy/apps/projects

  desc 'Debug Unicorn variables'
  task :show_vars do # rake
    on roles(:app), in: :sequence, wait: 5 do
      puts <<-EOF.gsub(/^ +/, '')

        rails_env "#{fetch(:rails_env)}"
        unicorn_binary "#{fetch(:unicorn_binary)}"
        unicorn_config "#{fetch(:unicorn_config)}"
        unicorn_pid "#{fetch(:unicorn_pid)}"
      EOF
    end
  end

  desc 'start unicorn'
  task :start do
    on roles(:app), in: :sequence, wait: 5 do
      execute "cd #{current_path} && #{fetch(:unicorn_binary)} -c #{fetch(:unicorn_config)} -E #{fetch(:rails_env)} -D"
    end
  end

  task :stop do
    on roles(:app), in: :sequence, wait: 5 do
      execute "kill `cat #{fetch(:unicorn_pid)}`"
    end
  end

  task :graceful_stop do
    on roles(:app), in: :sequence, wait: 5 do
      run "kill -s QUIT `cat #{fetch(:unicorn_pid)}`"
    end
  end

  task :reload do
    on roles(:app), in: :sequence, wait: 5 do
      run "kill -s USR2 `cat #{fetch(:unicorn_pid)}`"
    end
  end

  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      # invoke "unicorn:show_vars"
      invoke "unicorn:stop"
      invoke "unicorn:start" 
    end
  end
end

namespace :deploy do

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      # Your restart mechanism here, for example:
      # execute :touch, release_path.join('tmp/restart.txt')

      invoke "unicorn:restart"
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
  # %w[start stop restart].each do |command|
  #   desc "#{command} unicorn server."
  #   task command do
  #     on roles(:app) do
  #       execute "/etc/init.d/unicorn_#{fetch(:application)} #{command}"
  #       # execute "service nginx restart"
  #     end
  #   end
  # end

  task :link_db do
    on roles(:app) do
      execute "ln -s #{shared_path}/config/database.yml #{release_path}/config/database.yml"
    end
  end

  task :setup do
    # need no-passwd ssh to deploy user first!
    on roles(:app) do
      execute "mkdir -p #{shared_path}/config"

      # run_locally do
        sh "scp config/database.yml deploy@oneboxapp.com:#{shared_path}/config/database.yml"
      # end
    end
  end

  before :deploy, "deploy:check_revision"

  before "deploy:link_db", "deploy:setup"
  before "deploy:assets:precompile", "deploy:link_db"

  after :publishing, :restart
  # after :restart, "unicorn:show_vars"

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end
end
