module Telegram
  module Bot
    class Client
      attr_reader :api, :offset, :timeout, :method
      attr_accessor :logger

      def self.run(*args, &block)
        new(*args).run(&block)
      end

      def initialize(token, h = {})
        options = default_options.merge(h)
        @api = Api.new(token)
        @offset = options[:offset]
        @timeout = options[:timeout]
        @logger = options[:logger]
				@method = options[:method]
      end

      def run
        yield self
      end

      def listen(&block)
        logger.info('Starting bot')
        running = true
        Signal.trap('INT') { running = false; exit }
        fetch_updates(&block) while running
        exit
      end

      def fetch_updates
        response = api.getUpdates(offset: offset, timeout: timeout)
        return unless response['ok']

        response['result'].each do |data|
          update = Types::Update.new(data)
          @offset = update.update_id.next
          message = extract_message(update)
          log_incoming_message(message)
          yield message
        end
      end

      private

      def default_options
        { offset: 0, timeout: 20, logger: NullLogger.new, method: :polling }
      end

      def extract_message(update)
        update.inline_query ||
          update.chosen_inline_result ||
          update.callback_query ||
          update.edited_message ||
          update.message
      end

      def log_incoming_message(message)
				if message.is_a? Telegram::Bot::Types::Message
					logger.info(
						format('Incoming message: text="%s" uid=%i gid=%i', message, message.from.id, message.chat.id)
					)
				else
					logger.info(
						format(
							"Incoming #{message.class.name} with attribs='%s' from uid=%i", 
							message.inspect, 
							message.from.id
						)
					)
				end
      end
    end
  end
end
