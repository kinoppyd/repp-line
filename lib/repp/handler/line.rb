module Repp
  module Hander
    class Line
      require 'sinatra/base'
      require 'line/bot'

      class LineServer < Sinatra::Base
        set :line_client, Line::Bot::Client.new do |conf|
          conf.channel_id = ENV["LINE_CHANNEL_ID"]
          conf.channel_secret = ENV["LINE_CHANNEL_SECRET"]
          conf.channel_token = ENV["LINE_CHANNEL_TOKEN"]
        end

        post '/callback' do
          body = request.body.read

          signature = request.env['HTTP_X_LINE_SIGNATURE']
          unless settings.line_client.validate_signature(body, signature)
            error 400 do 'Bad Request' end
          end

          events = settings.line_client.parse_events_from(body)
          events.each do |event|
            case event
            when Line::Bot::Event::Message
              case event.type
              when Line::Bot::Event::MessageType::Text
                res = settings.application.call(Event::Receive.new(body: event.message['text']))
                if res.first
                  message = {
                      type: 'text',
                      text: res.first
                  }
                  settings.line_client.reply_message(event['replyToken'], message)
                end
              when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
                response = client.get_message_content(event.message['id'])
                tf = Tempfile.open("content")
                tf.write(response.body)
              end
            end
          end

          "OK"
        end
      end

      class << self
        def run(app, options = {})
          yield self if block_given?
          application = app.new

          options.merge!(application: application)
          LineServer.run!(options)
        end
      end
    end
  end
end
