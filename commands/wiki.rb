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
      def search (webclient, client, channel, searchQuery)
        #@@logger.debug("Searching for #{searchQuery}")
        response = @@wiki_connection.action :query, list: "search", srwhat: "text", srsearch: searchQuery
        
        #@@logger.debug("res is #{response.data}")
        @@logger.debug("res is #{response.data['search']}")
        #answer = "Results to *" + searchQuery + "* are : \n"
        answer2 = "Results to *" + searchQuery + "* are : \n>>>"
        response.data['search'].each do |entry|
           
          #@@logger.debug("link : #{entry['title']}")
          response2 = @@wiki_connection.action :opensearch, format: "xml", profile: "strict",search: entry['title']
          
          #answer = answer + "> *"+entry['title']+"*\t"+response2.data[3][0]+"\n" #+ entry['snippet']
          
          parsedSnippet = entry['snippet'].gsub(/\<span class=\'searchmatch\'\>/, '*')
          parsedSnippet = parsedSnippet.gsub(/\<\/span\>/, '*')
          parsedSnippet = parsedSnippet.gsub(/\<[^()]*?\>/, '')
          parsedSnippet = parsedSnippet.gsub(/\n/, "\n>")
          # change last character
          parsedSnippet[parsedSnippet.size-1] = "\n" 
          #parsedSnippet = parsedSnippet.gsub(/\'\'\'/, '*')
          #parsedSnippet = parsedSnippet.gsub(/===/, '*')
          @@logger.debug("parsed is #{parsedSnippet}")
          answer2 = answer2 + "<"+response2.data[3][0]+"|"+entry['title']+"> : \n>"+ parsedSnippet+"\n" #+ entry['snippet']
        end
        #client.message channel: channel, text: "#{answer}"
        client.typing channel: data['channel']
        webclient.chat_postMessage(channel: channel, text: answer2, as_user: true)
      end
    end
  end
