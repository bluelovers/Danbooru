desc "Recreate ALL databases"
task :nuke => :environment do
	abcs = ActiveRecord::Base.configurations
	`rm -f #{RAILS_ROOT}/temp/upload_locks/*`
	`rm -f #{RAILS_ROOT}/public/data/danbooru-{d,t}*`
	`rm -f #{RAILS_ROOT}/public/data/preview/danbooru-{d,t}*`

	%w(test development production).each do |e|
		`dropdb #{abcs[e]['database']}`
		`createdb #{abcs[e]['database']}`
		`psql #{abcs[e]['database']} < #{RAILS_ROOT}/db/pg.sql`
	end
end
