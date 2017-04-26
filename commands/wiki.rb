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
        response = @@wiki_connection.action :query, list: "search", srwhat: "text", srprop: "snippet|sectiontitle", srsearch: searchQuery
        testResponse = @@wiki_connection.action :query, format: "xml", prop:"extracts", generator:"search", exsentences:"2", exlimite:"5", exintro:"1", explaintext:"1", gsrwhat:"text", gsrsearch: searchQuery
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
          if parsedSnippet.size > 0 then
            # change last character
            parsedSnippet[parsedSnippet.size-1] = "\n" 
            #parsedSnippet = parsedSnippet.gsub(/\'\'\'/, '*')
            #parsedSnippet = parsedSnippet.gsub(/===/, '*')
          end
          title = entry['sectiontitle']
          if title then
            @@logger.debug("section title is #{title}")
          end
          @@logger.debug("response2 is #{response2.data[0]}")
          @@logger.debug("response2 is #{response2.data[1]}")
          @@logger.debug("response2 is #{response2.data[2]}")
          @@logger.debug("response2 is #{response2.data[3]}")
          @@logger.debug("parsed is #{parsedSnippet}")
          answer2 = answer2 + "<"+response2.data[3][0]+"|"+entry['title']+"> : \n>"+ parsedSnippet+"\n" #+ entry['snippet']
        end


        @@logger.debug("test2")
        @@logger.debug("response is : #{testResponse}")
        @@logger.debug("response.data is : #{testResponse.data}")
        testResponse.data['pages'].each do |entry|
          @@logger.debug("entry is: #{entry}")
          entryTitle = entry[1]['title']
          @@logger.debug("entryTitle is: #{entryTitle}")
          if 
          extract = entry['extract']
          @@logger.debug("entry.data is: #{extract}")
          response2 = @@wiki_connection.action :opensearch, format: "xml", profile: "strict",search: entryTitle
        end

        #client.message channel: channel, text: "#{answer}"
        webclient.chat_postMessage(channel: channel, text: answer2, as_user: true)
      end
    end
  end

