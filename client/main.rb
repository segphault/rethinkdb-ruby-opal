require "opal"
require "react"
require "json"
require "browser"
require "browser/http"
require "browser/socket"

puts "Running client-side Opal code"

class TodoList
  include React::Component

  def render
    ul do
      params[:items].each do |item|
        li do
          label do
            input(type: "checkbox", checked: item["status"]).on(:click) do |e|
              self.emit :toggle, id: item["id"], status: e.current_target.checked
            end
            span { item["text"] }
          end
        end
      end
    end
  end
end

class TodoAdd
  include React::Component

  def render
    div do
      input(type: "text", placeholder: "Input task name", ref: "text")
      button {"Add"}.on(:click) do
        text = self.refs[:text].dom_node.value
        self.emit :add, text: text
      end
    end
  end
end

class App
  include React::Component

  define_state(:items) { [] }
  after_mount :setup

  def setup
    Browser::HTTP.get("/api/items").then do |res|
      self.items = res.json
      setup_websocket
    end
  end

  def setup_websocket
    @ws = Browser::Socket.new "ws://drydock.local:32792"

    @ws.on(:open) { p "Connection opened" }
    @ws.on(:close) { p "Socket closed" }

    @ws.on(:message) do |e|
      data = JSON.parse e.data
      puts "Received:", data

      # Add new item
      if data[:new_val] && !data[:old_val]
        self.items = self.items << data[:new_val]
      # Update existing item
      elsif data[:new_val] && data[:old_val]
        self.items = self.items.map do |i|
          i["id"] == data[:new_val]["id"] ? data[:new_val] : i
        end
      # Remove deleted item
      elsif !data[:new_val] && data[:old_val]
        self.items = self.items - [data[:old_val]]
      end

    end
  end

  def transmit data
    @ws.puts data.to_json
  end

  def render
    div do
      present(TodoList, items: self.items).on :toggle do |data|
        transmit command: "update", id: data["id"], status: data["status"]
      end

      present(TodoAdd).on :add do |data|
        transmit command: "add", text: data["text"]
      end
    end
  end
end

$document.ready do
  React.render(React.create_element(App), `document.body`)
end
