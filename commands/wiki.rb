require 'mediawiki_api'
  module Commands
    class Wiki
      @@wiki_connection = MediawikiApi::Client.new "https://wiki.inria.fr/hybrid/api.php"
      def connect(username,password)
        wiki_connection.log_in username, password
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
    end
  end
