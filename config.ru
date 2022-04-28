# frozen_string_literal: true

path_to_file = File.join(__dir__, './src/data.db')
File.delete(path_to_file) if File.exist?(path_to_file)

require_relative './src/app'

set :port, 4567
run Sinatra::Application
