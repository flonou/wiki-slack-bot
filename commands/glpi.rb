require 'logging'
require 'net/http'
require 'openssl'
require 'stringio'
require 'uri'
require 'rest-client'
require 'sinatra/base'

  module Commands
    class Glpi

#	RestClient.log = 'stdout'
      @@tryingToReconnect = false
      @@logger = Logging.logger(STDOUT)
      @@logger.level = :debug
      for i in 0 ... ARGV.length
        if(ARGV[i] == "-glpiexternalurl" && i+1<ARGV.length)
	  @@externalurl = ARGV[i+1]
	end
        if(ARGV[i] == "-glpiapiurl" && i+1<ARGV.length)
	  @@apiurl = ARGV[i+1]
	end
        if(ARGV[i] == "-glpitoken" && i+1<ARGV.length)
	  @@token = ARGV[i+1]
        end
        if(ARGV[i] == "-glpiapptoken" && i+1<ARGV.length)
	  @@apptoken = ARGV[i+1]
	end
      end

      if not @@externalurl
        logger.fatal('Missing Glpi external url. use -glpiexternalurl option.')
        exit
      end
      if not @@apiurl
        logger.fatal('Missing Glpi api url. use -glpiapiurl option.')
        exit
      end
      if not @@token
        logger.fatal('Missing Glpi account api token. use -glpitoken option.')
        exit
      end
      if not @@apptoken
        logger.fatal('Missing Glpi app token. use -glpiapptoken option.')
        exit
      end


    def connect
      begin
        @@logger.debug("I will try to connect to Glpi at : " + @@apiurl)
        @@response = ::RestClient.get @@apiurl + "initSession", 
		"App-Token" => @@apptoken, 
		"Authorization" => "user_token #{@@token}",
		"Content-Type" => "application/json"
	@@parsedresponse = JSON.parse(@@response)
	@@session_token = @@parsedresponse['session_token']


#        @@response = ::RestClient.get @@apiurl + "getFullSession", 
#		"App-Token" => @@apptoken, 
#		"Session-Token" => @@session_token,
#		"Content-Type" => "application/json"
#	@@parsedresponse = JSON.parse(@@response)
#        @@logger.debug("full session init : #{@@parsedresponse}")
        
        @@tryingToReconnect = false
        @@logger.debug("Successfully connected to Glpi")
      rescue => e
        @@logger.debug("error in session init : #{e}")
      end
    end


    def search (webclient, client, channel, searchQuery, messageTs=nil)
    begin
      url=@@apiurl+"search/AllAssets?"\
        "\&criteria\[0\]\[searchtype\]\=contains"\
        "\&criteria\[0\]\[field\]\=1"\
        "\&criteria\[0\]\[value\]\=#{searchQuery}"\
        "\&&forcedisplay\[0\]\=1"
      resp = ::RestClient.get url, 
		"App-Token" => @@apptoken, 
		"Session-Token" => @@session_token, 
		"Content-Type" => "application/json"
#        @@logger.debug("after request : #{resp}")
	parsedresp = JSON.parse(resp)
        blockActions = Array.new
	if parsedresp['totalcount'] > 0 then
  	  assets = parsedresp['data']
	  message = "Assets found for *#{searchQuery}* : \n"
          for asset in assets
#           @@logger.debug("Id : #{asset["id"]} \tName : #{asset["1"]}\tType : #{asset["itemtype"]}")

             blockActions.push({
               type: "section",
               text: { 
                       type: "mrkdwn",
                       text: asset["1"]
               },
               accessory: {
                   type: "button",
                   text: { 
                       type: "plain_text",
                       text: "View",
                       emoji: true
                     },
                     action_id: "showDetails",
                     value: "#{searchQuery}\n#{asset["itemtype"]}\n#{asset["id"]}"
                }
              })
          end
        else
	  message = "No assets found for *#{searchQuery}* \n"
             blockActions.push({
               type: "section",
               text: { 
                       type: "mrkdwn",
                       text: message
               }
             })

        end
        if(messageTs.nil?)
          webclient.chat_postMessage(channel: channel, as_user: true, text: message,
             blocks: blockActions 
           )
        else
          webclient.chat_update(channel: channel, as_user: true, text: message, ts: messageTs,
             blocks: blockActions 
           )
        end
      rescue => e
        if @@tryingToReconnect then
          @@logger.debug("error in search : #{e} : #{e.class}")
        else
            @@tryingToReconnect = true
            connect()
            search webclient, client, channel, searchQuery, messageTs
        end
      end
    end

      def showDetail (webclient, client, channel, previousQuery, itemType, itemId, messageId)
      # first find the fields       
      url = @@apiurl+"listSearchOptions/"+itemType
      resp = ::RestClient.get url, 
		"App-Token" => @@apptoken, 
		"Session-Token" => @@session_token, 
		"Content-Type" => "application/json"
	parsedFieldResp = JSON.parse(resp)
# use this to show fields in the logs
 #       @@logger.debug("after request : "+JSON.pretty_generate(parsedFieldResp))
        locationFieldId = parsedFieldResp.find{|key,value| value["name"] == "Item location"}&.first
        if locationFieldId.nil? then
          locationFieldId = parsedFieldResp.find{|key,value| value["name"] == "Location"}&.first
        end
#        @@logger.debug("location field is : " +locationFieldId)
        groupFieldId = parsedFieldResp.find{|key,value| value["name"] == "Group"}&.first
#        @@logger.debug("group field is : " +groupFieldId)
        commentsFieldId = parsedFieldResp.find{|key,value| value["name"] == "Comments"}&.first
#        @@logger.debug("comments field is : " +commentsFieldId)
        statusFieldId = parsedFieldResp.find{|key,value| value["name"] == "Status"}&.first
#        @@logger.debug("status field is : " +statusFieldId)

       url=@@apiurl+"search/"+itemType+"?"\
        "\&criteria\[0\]\[searchtype\]\=equals"\
        "\&criteria\[0\]\[field\]\=2"\
        "\&criteria\[0\]\[value\]\=#{itemId}"\
	"\&forcedisplay\[0\]\=1"\
	"\&forcedisplay\[1\]\=2"\
	"\&forcedisplay\[2\]\=#{locationFieldId}"\
	"\&forcedisplay\[3\]\=#{groupFieldId}"\
	"\&forcedisplay\[4\]\=#{commentsFieldId}"\
	"\&forcedisplay\[5\]\=#{statusFieldId}"
 #       @@logger.debug("request : #{url}")
      
      resp = ::RestClient.get url, 
		"App-Token" => @@apptoken, 
		"Session-Token" => @@session_token, 
		"Content-Type" => "application/json"
  #      @@logger.debug("after request : #{resp}")
	parsedresp = JSON.parse(resp)
        blockActions = Array.new

	if parsedresp['totalcount'] > 0 then
  	  assets = parsedresp['data']
	  message = ">Details for asset *#{itemId}* : \n"
          for asset in assets
#            @@logger.debug(asset)
            itemurl = @@externalurl
            if itemType.start_with?("PluginGenericobject") then
               itemurl = itemurl +"plugins/genericobject/front/object.form.php?itemtype="+itemType+"&id="+itemId
            else
               itemurl = itemurl +"front/"+itemType.downcase+".form.php?&id="+itemId
	    end
#           @@logger.debug(asset)
            message = ">*<#{itemurl}|#{asset["1"]}>*\n"

            if !statusFieldId.nil? then
              status = asset[statusFieldId]
              if status.nil? then
                status = "N/A"
              end
              message = message + ">Status : #{status}\n"
            end
            if !locationFieldId.nil? then
              location = asset[locationFieldId]
              if location.nil? then
                location = "N/A"
              end
              message = message + ">Location : #{location}\n"
            end
            if !groupFieldId.nil? then
              team = asset[groupFieldId]
              if team.nil? then
                team = "N/A"
              end
              message = message + ">Team : #{team}\n"
            end
            if !commentsFieldId.nil? then
                comments = asset[commentsFieldId].gsub "\n", "\n>"
                @@logger.debug(comments)
                if !comments.nil? then
                  message = message + ">#{comments}"
                end
            end
           @@logger.debug(asset)

             blockActions.push({
               type: "section",
               text: { 
                       type: "mrkdwn",
                       text: message
               },
               accessory: {
                   type: "button",
                   text: { 
                       type: "plain_text",
                       text: "Return",
                       emoji: true
                     },
                     action_id: "searchUpdate",
                     value: previousQuery
                }
              })

          end
        else
	  message = "No assets found with ID *#{itemId}* \n"
        end
        slackResp = webclient.chat_update(channel: channel, text: message, as_user: true, ts: messageId,
            blocks: blockActions
        )
#        @@logger.debug("answer : " + JSON.pretty_generate(slackResp))
      rescue => e
        if @@tryingToReconnect then
            @@logger.debug("error in showDetails : #{e}")
        else
            @@tryingToReconnect = true
            connect()
            showDetail(webclient: webclient, client: client, channel: channel, previousQuery: previousQuery, itemType: itemType, itemId: itemId, messageId: messageId)
        end
      end

    end
end
