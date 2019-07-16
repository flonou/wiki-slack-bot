require 'slack-ruby-client'
require 'logging'
require 'uri'
require 'net/http'
require 'json'
require 'sinatra/base'
require_relative 'commands/wiki'
require_relative 'commands/glpi'

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

Slack::RealTime.configure do |config|
  config.concurrency = Slack::RealTime::Concurrency::Eventmachine
end

webclient = Slack::Web::Client.new
client = Slack::RealTime::Client.new
wiki = Commands::Wiki.new
glpi = Commands::Glpi.new


# listen for hello (connection) event - https://api.slack.com/events/hello
client.on :hello do
  logger.debug("Connected '#{client.self['name']}' to '#{client.team['name']}' team at https://#{client.team['domain']}.slack.com.")
end

client.on :close do |_data|
  puts _data
  puts 'Slack Connection closing, exiting.'
  client.stop!
end

client.on :closed do |_data|
  puts 'Slack Connection has been closed.'
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

		when 'bot help', 'help', 'bot' then
     	client.message channel: data['channel'], text: help
	   	logger.debug("A call for help")

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
      logger.debug("text : #{data['text']}")
 		  values = data['text'].split(" ",2)
 		  if values.size >= 2 then
        case values[0]
      		
        when 'wiki', '/wiki' then
  	      logger.debug("Should search for : #{values[1]}")
   	      wiki.search webclient, client, data['channel'], values[1]    
          
        when 'resa', '/resa' then
   	      logger.debug("Should search for : #{values[1]}")
   	      glpi.search webclient, client, data['channel'], values[1]    
        
        end
      end
      
      values = data['text'].split(" ") 
      case values[0] 
                  
      when 'clear' then
        logger.debug("got clear")
        if (values.size != 3)
          client.message channel: data['channel'], text: "For this to work, the bot needs to have user token instead of bot token. Please use the command 'clear TOKEN NBDAYS' to remove all files that you shared and that are older than NBDAYS"
          client.message channel: data['channel'], text: "You can get your token at : https://api.slack.com/custom-integrations/legacy-tokens."
        else
	        logger.debug("Ok I will check the files I can delete, older than #{values[2]} days")
           clear_files(client, data['channel'], values[1], values[2])
        end
 		  end
    end
  end
end

def list_files(userToken, days)
  ts_to = (Time.now - days.to_i * 24 * 60 * 60).to_i
  params = {
    token: userToken,
    ts_to: ts_to,
    count: 1000
  }
  uri = URI.parse('https://slack.com/api/files.list')
  uri.query = URI.encode_www_form(params)
  response = Net::HTTP.get_response(uri)
  return JSON.parse(response.body)['files']
end

def delete_files(file_ids, userToken)
  file_ids.each do |file_id|
    params = {
      token: userToken,
      file: file_id
    }
    uri = URI.parse('https://slack.com/api/files.delete')
    uri.query = URI.encode_www_form(params)
    response = Net::HTTP.get_response(uri)
    p "#{file_id}: #{JSON.parse(response.body)['ok']}"
  end
end

def clear_files(client, channel, token, days)
  files = list_files(token,days)
  if files != nil then
    length = files.length
    client.message channel: channel, text: "I will delete #{length} files"
    file_ids = files.map { |f| f['id'] }
    delete_files(file_ids, token)
    client.message channel: channel, text: "done..."
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
      `resa <search request>` to search for an item in glpi.\n
      `clear <token> <days>` to remove your files older than the given number of days. Token can be created/found at : \n 
	 > https://api.slack.com/custom-integrations/legacy-tokens\n
      `bot hi` for a simple message.\n
      `bot attachment` to see a Slack attachment message.\n
      `@<your bot\'s name>` to demonstrate detecting a mention.\n
      `bot help` to see this again.)
end


begin

  threads = []

  class SlackSinatra < Sinatra::Base

    set :logging, true
    set :bind, '0.0.0.0'
    set :port, 10000
    set :environment, :production
    set :sessions, true
    puts "Sinatra running in thread: #{Thread.current}"  
  
    class << self
      attr_accessor :sinatra_thread
      attr_accessor :glpi
      attr_accessor :webclient
      attr_accessor :client
    end

    post "/slack/:command" do
      payload = JSON.parse(request.params['payload'])
#    puts payload
      channel = payload['channel']['id']
#    puts channel
      message = payload['container']['message_ts']
#    puts message
      action_id = payload['actions'][0]['action_id']
      values = payload['actions'][0]['value'].split("\n")
      case action_id
      
      when "showDetails"
        previousQuery = values[0]
#      puts previousQuery
        itemType = values[1]
#      puts itemType
        itemId = values[2]
#      puts itemId
        SlackSinatra.glpi.showDetail(SlackSinatra.webclient,SlackSinatra.client,channel,previousQuery,itemType,itemId,message)
      
      when "searchUpdate"
        previousQuery = values[0]
        SlackSinatra.glpi.search(SlackSinatra.webclient,SlackSinatra.client,channel,previousQuery,message)
      end
    end
  
    get "/slack/:command" do
      logger.debug("Command is #{params[:command]}")
    end

  end

  logger.debug("Will run Sinatra")
  
  sinatra_thread = Thread.new() do
    begin
      SlackSinatra.glpi = glpi
      SlackSinatra.webclient = webclient
      SlackSinatra.client = client
      SlackSinatra.glpi.connect
      SlackSinatra.run!
    rescue StandardError => e
      $stderr << e.message
      $stderr << e.backtrace.join("\n")
    end
  end

  threads << sinatra_thread
  logger.debug("Will run Slack client")
  threads << client.start_async

rescue Exception => e
  logger.error(e)
  logger.error(e.backtrace)
  raise e
end

threads.each(&:join)
