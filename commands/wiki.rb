require 'mediawiki_api'
require 'logging'
  module Commands
    class Wiki
      @@logger = Logging.logger(STDOUT)
      @@logger.level = :debug
      @@wiki_connection = MediawikiApi::Client.new ENV['API_URL']
      @@logger.debug("I will try to connect to the wiki as #{ENV['USERNAME']}!")
      @@wiki_connection.log_in ENV['USERNAME'], ENV['PASSWORD']
      if @@wiki_connection.logged_in then
        @@logger.debug("Connected successfuly")
      else
        @@logger.debug("Could not connect :(")
      end
=begin
      wiki_connection = MediawikiApi::Client.new "https://wiki.inria.fr/hybrid/api.php"
      wiki_connection.log_in "username", "password"
      match(/^!wiki search (?<terms>\w*)\s(?<contentwiki>.*)$/) do |client, data, match |
        response = wiki_connection.query titles: match[:terms]
        pageid = response.data["pageid"]
        client.say(channel: data.channel, text: "Your wiki is created http://MediaWiki-URL?curid=#{pageid}")
      end
=end
      def search (client, channel, searchQuery)
        @@logger.debug("Searching for #{searchQuery}")
        response = @@wiki_connection.action :query, list: "search", srwhat: "text", srsearch: searchQuery, srprop: "title|sectionsnippet"
        
        @@logger.debug("res is #{response.data}")
        @@logger.debug("res is #{response.data['search']}")
        response.data['search'].each do |entry|
          @@logger.debug("link : #{entry['title']}")
          response2 = @@wiki_connection.action :opensearch, format: "xml", profile: "strict",search: entry['title']
          @@logger.debug("res2 is #{response2.data}")
          @@logger.debug("res2 is #{response2.data[0]}")
          @@logger.debug("res2 is #{response2.data[2]}")
        end
        #client.message channel: channel, text: "#{response.data}"
      end
    end
  end
