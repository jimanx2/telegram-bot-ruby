module Telegram
  module Bot
    class Api
      ENDPOINTS = %w(
        getUpdates setWebhook getMe sendMessage forwardMessage sendPhoto
        sendAudio sendDocument sendSticker sendVideo sendVoice sendLocation
        sendVenue sendContact sendChatAction getUserProfilePhotos getFile
        kickChatMember unbanChatMember answerCallbackQuery editMessageText
        editMessageCaption editMessageReplyMarkup answerInlineQuery getChat
        leaveChat getChatAdministrators getChatMember getChatMembersCount
      ).freeze
      REPLY_MARKUP_TYPES = [
        Telegram::Bot::Types::ReplyKeyboardMarkup,
        Telegram::Bot::Types::ReplyKeyboardHide,
        Telegram::Bot::Types::ForceReply,
        Telegram::Bot::Types::InlineKeyboardMarkup
      ].freeze
      INLINE_QUERY_RESULT_TYPES = [
        Telegram::Bot::Types::InlineQueryResultArticle,
        Telegram::Bot::Types::InlineQueryResultPhoto,
        Telegram::Bot::Types::InlineQueryResultGif,
        Telegram::Bot::Types::InlineQueryResultMpeg4Gif,
        Telegram::Bot::Types::InlineQueryResultVideo,
        Telegram::Bot::Types::InlineQueryResultAudio,
        Telegram::Bot::Types::InlineQueryResultVoice,
        Telegram::Bot::Types::InlineQueryResultDocument,
        Telegram::Bot::Types::InlineQueryResultLocation,
        Telegram::Bot::Types::InlineQueryResultVenue,
        Telegram::Bot::Types::InlineQueryResultContact,
        Telegram::Bot::Types::InlineQueryResultCachedPhoto,
        Telegram::Bot::Types::InlineQueryResultCachedGif,
        Telegram::Bot::Types::InlineQueryResultCachedMpeg4Gif,
        Telegram::Bot::Types::InlineQueryResultCachedSticker,
        Telegram::Bot::Types::InlineQueryResultCachedDocument,
        Telegram::Bot::Types::InlineQueryResultCachedVideo,
        Telegram::Bot::Types::InlineQueryResultCachedVoice,
        Telegram::Bot::Types::InlineQueryResultCachedAudio
      ].freeze

      attr_reader :token

      def initialize(token)
        @token = token
      end

      def method_missing(method_name, *args, &block)
        endpoint = method_name.to_s
        endpoint = camelize(endpoint) if endpoint.include?('_')
				
        ENDPOINTS.include?(endpoint) ? call(endpoint, *args) : super
      end

      def respond_to_missing?(*args)
        method_name = args[0].to_s
        method_name = camelize(method_name) if method_name.include?('_')

        ENDPOINTS.include?(method_name) || super
      end

      def call(endpoint, raw_params = {})
        params = build_params(raw_params)
				begin
					response = conn.post("/bot#{token}/#{endpoint}", params)
				rescue Faraday::ConnectionFailed
					Lita.logger.error("Cannot connect to Telegram API server. Possibly network is down.")
					Lita.logger.info("Shutting down..")
					exit
				rescue Faraday::TimeoutError
					Lita.logger.error("Connection to Telegram API server lost.")
					Lita.logger.info("Shutting down..")
					exit
				end
        if response.status == 200
          JSON.parse(response.body)
        else
          raise Exceptions::ResponseError.new(response),
                'Telegram API has returned the error.'
        end
      end

      private

      def build_params(h)
        h.each_with_object({}) do |(key, value), params|
          params[key] = sanitize_value(value)
        end
      end

      def sanitize_value(value)
        jsonify_inline_query_results(jsonify_reply_markup(value))
      end

      def jsonify_reply_markup(value)
        return value unless REPLY_MARKUP_TYPES.include?(value.class)
        value.to_compact_hash.to_json
      end

      def jsonify_inline_query_results(value)
        return value unless value.is_a?(Array) && value.all? { |i| INLINE_QUERY_RESULT_TYPES.include?(i.class) }
        value.map { |i| i.to_compact_hash.select { |_, v| v } }.to_json
      end

      def camelize(method_name)
        words = method_name.split('_')
        words.drop(1).map(&:capitalize!)
        words.join
      end

			public
      def conn
        @conn ||= Faraday.new(url: 'https://api.telegram.org') do |faraday|
          faraday.request :multipart
          faraday.request :url_encoded
          faraday.adapter Telegram::Bot.configuration.adapter
        end
      end
    end
  end
end
