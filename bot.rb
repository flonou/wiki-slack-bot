require 'slack-ruby-client'
require 'logging'
#require 'uri'
#require 'net/http'
#require 'json'
require_relative 'commands/wiki'

logger = Logging.logger(STDOUT)
logger.level = :debug

Slack.configure do |config|
  for i in 0 ... ARGV.length
    if (ARGV[i] == "-token" && i+1 < ARGV.length)
      config.token = ARGV[i+1]
    end
  end
  if not config.token
    logger.fatal('Missing token ! Use the -token [TOKEN] argument. Exiting program')
    exit
  end
end

webclient = Slack::Web::Client.new
client = Slack::RealTime::Client.new
wiki = Commands::Wiki.new

# listen for hello (connection) event - https://api.slack.com/events/hello
client.on :hello do
  logger.debug("Connected '#{client.self['name']}' to '#{client.team['name']}' team at https://#{client.team['domain']}.slack.com.")
end

client.on :close do |_data|
  puts 'Connection closing, exiting.'
#  client = Slack::RealTime::Client.new
#  client.restart!
#  puts 'Client started again'
  client.stop!
end

client.on :closed do |_data|
  puts 'Connection has been closed.'
  client.start!
end


client.on :goodbye do
  logger.debug("'#{client.self['name']}' will be disconnected from '#{client.team['name']}' team at https://#{client.team['domain']}.slack.com. by the server")
  client = Slack::RealTime::Client.new
  client.start!
end

# listen for channel_joined event - https://api.slack.com/events/channel_joined
client.on :channel_joined do |data|
  if joiner_is_bot?(client, data)
    client.message channel: data['channel']['id'], text: "Thanks for the invite! I don\'t do much yet, but #{help}"
    logger.debug("#{client.self['name']} joined channel #{data['channel']['id']}")
  else
    logger.debug("Someone far less important than #{client.self['name']} joined #{data['channel']['id']}")
  end
end

#webclient.chat_postMessage(channel: '#general', text: "I'm ready to get to work folks !", as_user: true)

rebecca_id = -1
users = client.web_client.users_list
users.each do |entry|
  if entry[0] == "members" then
    entry[1].each do |user|
      #logger.debug(user)
      if (user['name']=="rebecca.fribourg" || user['name']=="beckou") then
        # rebecca_id = user['id']
        logger.debug("found rebecca : " + user['id'])
        logger.debug("found rebecca : " + user['id'] + " but ignoring for now !")
      end
    end
    end
end



# listen for message event - https://api.slack.com/events/message
client.on :message do |data|

	if data['text']
		case data['text'].downcase

		when 'hi', 'bot hi' then
			client.typing channel: data['channel']
			client.message channel: data['channel'], text: "Hello <@#{data['user']}>."
			logger.debug("<@#{data['user']}> said hi")

			if direct_message?(data)
		      		client.message channel: data['channel'], text: "It\'s nice to talk to you directly."
		      		logger.debug("And it was a direct message")
		    	end

		when 'attachment', 'bot attachment' then
			    	# attachment messages require using web_client
			    	client.web_client.chat_postMessage(post_message_payload(data))
			    	logger.debug("Attachment message posted")

		when bot_mentioned(client)
			client.message channel: data['channel'], text: 'You really do care about me. :heart:'
			logger.debug("Bot mentioned in channel #{data['channel']}")


		when 'bot close' then
		    	logger.debug("Closing connection")
	                client.on( :close)
	                client.on( :closed)
#            		client.close(nil)
#			client.callback(nil, :closed)

		when 'bot help', 'help', 'bot' then
		    	client.message channel: data['channel'], text: help
		    	logger.debug("A call for help")

		when 'bot clear' then
			client.message channel: data['channel'], text: "For this to work, the bot needs to have user token instead of bot token"
			clear_files(client, data['channel'])  


	  	when /^bot / then
    			client.message channel: data['channel'], text: "Sorry <@#{data['user']}>, I don\'t understand. \n#{help}"
    			logger.debug("Unknown command")
	  	end
		
  		if rebecca_id == data['user'] then
    			possible_texts = ["va bosser <@#{data['user']}>.","<@#{data['user']}>, t'as pas un truc à faire là? genre une thèse ?","Je trouve que tu parles beaucoup pour une thésarde <@#{data['user']}>..."]
	    		randValue = rand(possible_texts.size)*5
    			if (randValue < possible_texts.size) then
      				client.typing channel: data['channel']
      				client.message channel: data['channel'], text: possible_texts[randValue]
	    		end
  		end
	  	if data['text'] != nil then
    			values = data['text'].split(" ",2)
    			if values.size >= 2 then
      			
				case values[0]
      				
				when 'wiki', '/wiki' then
        				logger.debug("Should search for : #{values[1]}")
        				wiki.search webclient, client, data['channel'], values[1]
      				end
    			end
  		end
	end
end

def list_files
  nbdays = 30*6;
  ts_to = (Time.now - nbdays * 24 * 60 * 60).to_i
  params = {
    token: Slack.configure.token,
    ts_to: ts_to,
    count: 1000
  }
  uri = URI.parse('https://slack.com/api/files.list')
  uri.query = URI.encode_www_form(params)
  response = Net::HTTP.get_response(uri)
logger = Logging.logger(STDOUT)
logger.level = :debug
  logger.debug(response.body)
  JSON.parse(response.body)['files']
end

def delete_files(file_ids)
  file_ids.each do |file_id|
    params = {
    token: Slack.configure.token,
      file: file_id
    }
    uri = URI.parse('https://slack.com/api/files.delete')
    uri.query = URI.encode_www_form(params)
    response = Net::HTTP.get_response(uri)
    p "#{file_id}: #{JSON.parse(response.body)['ok']}"
  end
end

def clear_files(client, channel)
  files = list_files
  if files != nil then
    length = files.length
    client.message channel: channel, text: "will delete #{length} files"
    file_ids = files.map { |f| f['id'] }
    delete_files(file_ids)
  end

end

def direct_message?(data)
  # direct message channles start with a 'D'
  data['channel'][0] == 'D'
end

def bot_mentioned(client)
  # match on any instances of `<@bot_id>` in the message
  /\<\@#{client.self['id']}\>+/
end

def joiner_is_bot?(client, data)
 /^\<\@#{client.self['id']}\>/.match data['channel']['latest']['text']
end

def help
  %Q(I will respond to the following messages: \n
      `wiki <search request>` to search for something in the wiki.\n
      `bot hi` for a simple message.\n
      `bot attachment` to see a Slack attachment message.\n
      `@<your bot\'s name>` to demonstrate detecting a mention.\n
      `bot help` to see this again.)
end

client.start!
