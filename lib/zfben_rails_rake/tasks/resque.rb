if File.exists?(ROOT + '/config/initializers/resque.rb')
  require ROOT + '/config/initializers/resque.rb'
  require 'resque/tasks'
  if defined?(Resque::Scheduler)
    require 'resque_scheduler/tasks'
  end
  namespace :resque do
    task :setup => :environment

    task :_work => ['resque:preload', 'resque:setup'] do
      work = Resque::Worker.new('*')
      Process.daemon(true)
      File.open(ROOT + '/tmp/resque.pid', 'w') { |f| f << work.pid }
      work.work(5)
    end

    if defined?(Resque::Scheduler)
      task :_scheduler => 'resque:setup' do
        Process.daemon(true)
        File.open(ROOT + '/tmp/scheduler.pid', 'w') { |f| f << Process.pid.to_s }
        Resque::Scheduler.run
      end
    end

    desc 'Start Resque daemon worker'
    task :start => 'resque:stop' do
      sys "bash -c 'RAILS_ENV=production rake resque:_work'"
      if defined?(Resque::Scheduler)
        sys "bash -c 'RAILS_ENV=production rake resque:_scheduler'"
      end
    end

    desc 'Stop Resque worker'
    task :stop do
      ['resque', 'scheduler'].each do |name|
        path = ROOT + '/tmp/' + name + '.pid'
        if File.exists?(path)
          sys "kill `cat #{path}`;rm #{path}"
        end
      end
    end

    desc 'Clear Resque data'
    task :clear do
      Resque.redis.keys('*').each{ |k| Resque.redis.del k }
    end

    desc 'Start Resque web interface'
    task :web do
      sys "RAILS_ENV=production resque-web #{ROOT}/config/initializers/resque.rb"
    end
  end
end
