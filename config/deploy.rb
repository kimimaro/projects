# config valid only for Capistrano 3.1
lock '3.1.0'

set :application, 'projects'
set :deploy_user, 'deploy'

# setup repo details
set :scm, :git
set :repo_url, 'git@github.com:kimimaro/projects.git'

# setup rvm.
set :rbenv_type, :user
set :rbenv_ruby, '2.0.0-p645'
set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
set :rbenv_map_bins, %w{rake gem bundle ruby rails}

# how many old releases do we want to keep
set :keep_releases, 5

# files we want symlinking to specific entries in shared.
set :linked_files, %w{config/database.yml}

# dirs we want symlinking to shared
set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

# what specs should be run before deployment is allowed to
# continue, see lib/capistrano/tasks/run_tests.cap
# set :tests, []

# stdin
# set :pty, true

# this:
# http://www.capistranorb.com/documentation/getting-started/flow/
# is worth reading for a quick overview of what tasks are called
# and when for `cap stage deploy`

namespace :deploy do
  after :updated, "assets:precompile"
  after :finishing, 'deploy:cleanup'
  
  # # make sure we're deploying what we think we're deploying
  # before :deploy, "deploy:check_revision"
  # # only allow a deploy with passing tests to deployed
  # before :deploy, "deploy:run_tests"
  # # compile assets locally then rsync
  # after 'deploy:symlink:shared', 'deploy:compile_assets_locally'
  # after :finishing, 'deploy:cleanup'

  # # remove the default nginx configuration as it will tend
  # # to conflict with our configs.
  # before 'deploy:setup_config', 'nginx:remove_default_vhost'

  # # reload nginx to it will pick up any modified vhosts from
  # # setup_config
  # after 'deploy:setup_config', 'nginx:reload'

  # # Restart monit so it will pick up any monit configurations
  # # we've added
  # after 'deploy:setup_config', 'monit:restart'

  # # As of Capistrano 3.1, the `deploy:restart` task is not called
  # # automatically.
  # after 'deploy:publishing', 'deploy:restart'
end

# Updated to work with Capistrano 3 and Rails 4; compiles assets in given stage in order
# to use settings for that stage ... rm assets when we're done
namespace :assets do
  desc "Precompile assets locally and then rsync to web servers"
  task :precompile do
    on roles(:web) do
      rsync_host = host.to_s # this needs to be done outside run_locally in order for host to exist
      run_locally do
        with rails_env: fetch(:stage) do
          execute :bundle, "exec rake assets:precompile"
        end
        execute "rsync -av --delete ./public/assets/ #{fetch(:user)}@#{rsync_host}:#{shared_path}/public/assets/"
        execute "rm -rf public/assets"
        # execute "rm -rf tmp/cache/assets" # in case you are not seeing changes
      end
    end
  end
end
