require "test_helper"

class TagTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
  test 'Verify that the Rails app can load itself' do
    puts "HOST: #{Rails.configuration.action_mailer.default_url_options[:host]}"
    asset 1 == 0
  end
end
