

module Commands
  class NyaBot
    def initialize
      @@facts = File.read(File.dirname(__FILE__) + "/../resources/nyaFacts.txt").split("\n")
    end
    def randomFact(webclient, channel)
      fact = @@facts[rand(0..@@facts.size-1)]
      webclient.chat_postMessage(channel: channel, text: fact, as_user: true)
    end
  end
end
