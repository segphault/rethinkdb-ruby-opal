require 'bundler'
Bundler.require

require "./app"

Faye::WebSocket.load_adapter("thin")

react_path = ::React::Source.bundled_path_for("react-with-addons.js")

$opal = Opal::Server.new do |s|
  s.append_path File.dirname react_path
  s.append_path "client"
  s.main = "main"
end

map "/assets" do
  run $opal.sprockets
end

$opalinit = Opal::Processor.load_asset_code($opal.sprockets, 'main')

run App
