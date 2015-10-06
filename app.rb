require "sinatra"
require "tilt/haml"
require "faye/websocket"
require "rethinkdb"
require "opal"
require "json"

include RethinkDB::Shortcuts

DBHOST = ENV["RETHINKDB_PORT_28015_TCP_ADDR"]
DBPORT = ENV["RETHINKDB_PORT_28015_TCP_PORT"]

def query rql
  conn = r.connect host: DBHOST, port: DBPORT
  rql.run(conn).to_json
ensure
  conn.close
end

class App < Sinatra::Base
  def initialize
    super
    @clients = []

    EM.next_tick do
      conn = r.connect host: DBHOST, port: DBPORT
      r.table("todo").changes.em_run(conn) do |err, change|
        @clients.each {|c| c.send change.to_json }
      end
    end
  end

  def setup_websocket ws
    ws.on(:close) { @clients.delete ws }
    ws.on(:open) { @clients << ws }

    ws.on :message do |msg|
      data = JSON.parse msg.data
      case data["command"]
      when "add"
        query r.table("todo").insert text: data["text"], status: false
      when "update"
        query r.table("todo").get(data["id"]).update status: data["status"]
      when "delete"
        query r.table("todo").get(data["id"]).delete()
      end
    end
  end

  get "/" do
    if Faye::WebSocket.websocket? request.env
      ws = Faye::WebSocket.new request.env
      setup_websocket ws
      ws.rack_response
    else
      haml :index
    end
  end

  get "/api/items" do
    query r.table("todo").coerce_to("array")
  end
end
