require 'mediawiki_api'
require 'logging'
  module Commands
    class Wiki
      @@logger = Logging.logger(STDOUT)
      @@logger.level = :debug
      for i in 0 ... ARGV.length
        if(ARGV[i] == "-url" && i+1<ARGV.length)
	        @@url = ARGV[i+1]
	      end
	      if(ARGV[i] == "-username" && i+1<ARGV.length)
	        @@username = ARGV[i+1]
	      end
	      if(ARGV[i] == "-password" && i+1<ARGV.length)
	        @@password = ARGV[i+1]
	      end
      end
      if not @@url
        logger.fatal('Missing Wiki api url. use -url option.')
	      exit
      end
      if not @@username
        logger.fatal('Missing Wiki username. use -username option.')
	      exit
      end
      if not @@password
        logger.fatal('Missing Wiki account password. use -password option.')
	      exit
      end
      @@wiki_connection = MediawikiApi::Client.new @@url
      @@logger.debug("I will try to connect to the wiki as #{@@username}!")
      @@wiki_connection.log_in @@username, @@password
      if @@wiki_connection.logged_in then
        @@logger.debug("Connected successfuly")
      else
        @@logger.debug("Could not connect :(")
      end
=begin
      wiki_connection = MediawikiApi::Client.new "https://wiki.inria.fr/wikis/hybrid/api.php"
      wiki_connection.log_in "username", "password"
      match(/^!wiki search (?<terms>\w*)\s(?<contentwiki>.*)$/) do |client, data, match |
        response = wiki_connection.query titles: match[:terms]
        pageid = response.data["pageid"]
        client.say(channel: data.channel, text: "Your wiki is created http://MediaWiki-URL?curid=#{pageid}")
      end
=end

	def boldQuery(text,query)
		text.gsub(/(#{query})/i, "*\\1*")
	end

	def reformat(text)
		# remove images
		text.gsub!(/\[\[.*\]\]/,"")
		# reformat links
		text.gsub!(/\[(\S*)\s([^\]]+)\]/,"<\\1|\\2>")
		# reformat bold
		text.gsub!(/\'\'\'([^\']+)\'\'\'/,"_\\1_")
		# reformat list
		text.gsub!(/^\*\S*(.+)$/,"- \\1")
		# reformat section title
		text.gsub!(/^\S*=+\S*([^=]+)\S*=+\S*/,"\t_\\1_")
		return text
	end

	def extractData(text, searchQuery)
#		@@logger.debug("extracting #{searchQuery} from #{text}")
	
		nbLines = text.lines.count
		linesId = 0
		lastSectionLine = 0
#		@@logger.debug("got #{nbLines} lines")

		for i in 0..nbLines-1
#			@@logger.debug("looking at #{text.lines[i]}")
			if text.lines[i].match(/^[=]/)
				lastSectionLine = i
			end
			lineId = i
			break if text.lines[i].downcase.include?(searchQuery.downcase)
		end

		result = reformat(boldQuery(text.lines[lastSectionLine],searchQuery))
	
		for j in lastSectionLine+1..nbLines-1
		#if lineId + 1 < nbLines
			break if text.lines[j].match(/^[=]/)
			if text.lines[j] != "\n"
				result = result + ">" + reformat(boldQuery(text.lines[j],searchQuery))
			end
		end

		return result
	end

      def search (webclient, client, channel, searchQuery)
        #@@logger.debug("Searching for #{searchQuery}")
        response = @@wiki_connection.action :query, list: "search", srwhat: "text", srprop: "snippet|sectiontitle", srsearch: searchQuery
#        testResponse = @@wiki_connection.action :query, format: "xml", prop:"extracts", generator:"search", exsentences:"3", exlimite:"5", exintro:"1", explaintext:"1", gsrwhat:"text", gsrsearch: searchQuery
#        @@logger.debug("res is #{response.data}")
        @@logger.debug("res is #{response.data['search']}")
        #answer = "Results to *" + searchQuery + "* are : \n"
        answer2 = "Results to *" + searchQuery + "* are : \n>>>"
        
	lastResponse = ""

        response.data['search'].each do |entry|
           


          #@@logger.debug("link : #{entry['title']}")
          response2 = @@wiki_connection.action :opensearch, format: "xml", profile: "fuzzy",search: entry['title']
          
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

        	testResponse = @@wiki_connection.action :parse, prop: "wikitext", page:entry['title']
	
		@@logger.debug("test res with parse is #{testResponse.data}")
#		@@logger.debug("test res2 with parse is #{testResponse.data['text']}")
#		@@logger.debug("test res3 with parse is #{testResponse.data['text']['*']}")

		parseResult = extractData(testResponse.data['wikitext']['*'], searchQuery)

		@@logger.debug("Parsed is : #{parseResult}")

          	title = entry['sectiontitle']
          	if title then
            		@@logger.debug("section title is #{title}")
          	end
=begin
          	@@logger.debug("response2 is #{response2.data[0]}")
          	@@logger.debug("response2 is #{response2.data[1]}")
          	@@logger.debug("response2 is #{response2.data[2]}")
          	@@logger.debug("response2 is #{response2.data[3]}")
          	@@logger.debug("parsed is #{parsedSnippet}")
=end
		# ignore if we already had the same section in result
		next if parseResult == lastResponse

          	answer2 = answer2 + "<"+response2.data[3][0]+"|"+entry['title']+"> : \n"
#	  	answer2 = answer2 + parsedSnippet+"\n" 
	  	answer2 = answer2 + parseResult#+ entry['snippet']

		lastResponse = parseResult
        end

#requires TextExtracts extension :/
=begin
        @@logger.debug("test2")
        @@logger.debug("response is : #{testResponse}")
        zerfqzefzef = testResponse['query']
        
        @@logger.debug("response[query] is : #{zerfqzefzef}")
        zefqzefqzefq = zerfqzefzef['pages']
        @@logger.debug("response[query] is : #{zefqzefqzefq}")
        @@logger.debug("response.data is : #{testResponse.data}")
        testResponse.data['pages'].each do |entry|
          @@logger.debug("entry is: #{entry}")
          entryTitle = entry[1]['title']
          @@logger.debug("entryTitle is: #{entryTitle}")
          extract = entry['extract']
          @@logger.debug("entry.data is: #{extract}")
          response2 = @@wiki_connection.action :opensearch, format: "xml", profile: "strict",search: entryTitle
        end
=end
        #client.message channel: channel, text: "#{answer}"
        webclient.chat_postMessage(channel: channel, text: answer2, as_user: true)
      end
    end
  end

