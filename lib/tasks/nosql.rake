# frozen_string_literal: true

# NoSQL Database tasks

namespace :nosql do
  desc 'Initialize the NoSQL database if it does not exist'
  task prepare_local: :environment do
    # Only allow this in the local Docker dev environment! Cloud based environments
    # should construct the NoSQL database via Infrastructure as Code and then
    # update these commands to use their version of the Nosql::Adapter class
    if Rails.env.development?
      begin
        ENV['NOSQL_TABLE'] = ENV.fetch('NOSQL_TABLE', 'dmsp-local')
        adapter= Nosql::AwsDynamodbAdapter.new
        puts "Checking if NoSQL database needs to be initialized ..."
        adapter.send(:initialize_database)
        puts "DONE"
      end
    else
      puts "This task can only be run in the local Docker development environment!"
    end
  end

  desc 'Purge all content from the NoSQL database'
  task purge_local: :environment do
    # Only allow this in the local Docker dev environment! Cloud based environments
    # should construct the NoSQL database via Infrastructure as Code
    if Rails.env.development?
      begin
        ENV['NOSQL_TABLE'] = ENV.fetch('NOSQL_TABLE', 'dmsp-local')
        adapter= Nosql::AwsDynamodbAdapter.new
        puts "Purging local NoSQL records ..."
        adapter.send(:purge_database)
        puts "DONE"
      end
    else
      puts "This task can only be run in the local Docker development environment!"
    end
  end
end
