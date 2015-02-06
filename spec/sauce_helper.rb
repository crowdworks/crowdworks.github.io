require "sauce"
require "sauce/capybara"
require "capybara/rspec"

Capybara.default_driver = :sauce

Sauce.config do |c|
  c[:browsers] = [
    ["Windows 8", "Internet Explorer", "10"],
    ["Windows 7", "Firefox", "20"],
    ["OS X 10.8", "Safari", "6"],
    ["Linux", "Chrome", nil]
  ]
  c[:idle_timeout] = 120
end

# @see http://qiita.com/oh_rusty_nail/items/c04ed0deba902443a9cd
require 'sauce/connect'
Sauce::Connect::TIMEOUT = 270
